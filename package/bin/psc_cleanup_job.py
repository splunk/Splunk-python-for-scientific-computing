import os
import json
import logging
import time
import sys
import platform
import subprocess
import traceback
import re
from datetime import datetime

from splunk import setupSplunkLogger
from splunk.clilib.bundle_paths import make_splunkhome_path

script_dir = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(script_dir, "..", "lib"))
from splunklib.modularinput import *

SUPPORTED_SYSTEMS = {
    ('Linux', 'x86_64'): 'linux_x86_64',
    ('Darwin', 'x86_64'): 'darwin_x86_64',
    ('Darwin', 'arm64'): 'darwin_arm64',
    ('Windows', 'AMD64'): 'windows_x86_64',
}
PSC_PATH_PREFIX = 'Splunk_SA_Scientific_Python_'


def get_system_paths():
    system = ((platform.system(), "arm64") if platform.system() == "Darwin" and "ARM64" in platform.version()
              else (platform.system(), platform.machine()))
              
    if system not in SUPPORTED_SYSTEMS:
        raise Exception(f'Unsupported platform: {system}')

    return f"{PSC_PATH_PREFIX}{SUPPORTED_SYSTEMS[system]}", system

psc_folder, system = get_system_paths()


def setup_logging(log_name, logger_name, logger=None, level=logging.INFO, is_console_header=False,
                  log_format='%(asctime)s %(levelname)s [%(name)s] [%(module)s] [%(funcName)s] %(message)s',
                  is_propagate=False):
    """Setup logging

    @param log_name: log file name
    @param logger_name: logger name (if logger specified then we ignore this argument)
    @param logger: logger object
    @param level: logging level
    @param is_console_header: set to true if console logging is required
    @param log_format: log message format
    @param is_propagate: set to true if you want to propagate log to higher level
    @return: logger
    """
    if log_name is None or logger_name is None:
        raise ValueError("log_name or logger_name is not specified")

    if logger is None:
        # Logger is singleton so if logger is already defined it will return old handler
        logger = logging.getLogger(logger_name)

    logger.propagate = is_propagate  # Prevent the log messages from being duplicated in the python.log file
    logger.setLevel(level)

    if len(logger.handlers) == 0:
        file_handler = logging.handlers.RotatingFileHandler(
            make_splunkhome_path(['var', 'log', 'splunk', log_name]),
            maxBytes=25000000, backupCount=0)
        formatter = logging.Formatter(log_format)
        file_handler.setFormatter(formatter)
        logger.handlers = []
        logger.addHandler(file_handler)

        # Console stream handler
        if is_console_header:
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(logging.Formatter(log_format))
            logger.addHandler(console_handler)

    # Read logging level information from log.cfg, so it will overwrite log
    # Note if logger level is specified on that file then it will overwrite log level
    LOGGING_DEFAULT_CONFIG_FILE = make_splunkhome_path(['etc', 'log.cfg'])
    LOGGING_LOCAL_CONFIG_FILE = make_splunkhome_path(['etc', 'log-local.cfg'])
    LOGGING_STANZA_NAME = 'python'
    setupSplunkLogger(
        logger,
        LOGGING_DEFAULT_CONFIG_FILE,
        LOGGING_LOCAL_CONFIG_FILE,
        LOGGING_STANZA_NAME,
        verbose=False
    )

    return logger

logger = setup_logging('psc_cleanup_job.log',
                       'psc_cleanup_job_status',
                       level=logging.DEBUG)

def get_app_version():
    """Get the version of the Splunk app from the app.manifest file."""
    manifest_path = make_splunkhome_path(["etc", "apps", psc_folder, "app.manifest"])
    
    if not os.path.isfile(manifest_path):
        logger.info(f"[ERROR] app.manifest file not found: {manifest_path}, Please check the SPLUNK_HOME path")
        return None
        
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_data = json.load(f)
        return manifest_data["info"]["id"]["version"]
    except Exception as e:
        logger.info(f"[ERROR] Failed to read or parse app.manifest: {e}")
        return None

def count_scientific_python_processes():
    # include_str = "Scientific_Python".lower()
    include_str = psc_folder.lower()
    # Combine all exclusion patterns into a single tuple for efficiency
    app_version = get_app_version()
    version_pattern = app_version.replace(".", "_").lower() if app_version else ""
    exclude_patterns = (
        version_pattern,
        "splunk/bin/python",
        "splunk/bin/python.exe"
    )
    new_p_count = 0
    old_p_count = 0

    try:
        if system[0] == "Windows":
            # Use wmic to get full command line paths
            output = subprocess.check_output([
                "wmic", "process", "get", "ProcessId,CommandLine", "/format:csv"
            ], shell=True, text=True)
        else:
            output = subprocess.check_output(["ps", "-ef"], text=True)
    except subprocess.CalledProcessError:
        return old_p_count, new_p_count

    for line in output.splitlines():
        # Normalize line for case-insensitive and path separator matching
        line_norm = line.lower().replace("\\", "/")

        if include_str in line_norm:
            # Extract PID and full command line path for logging
            pid, process_path = ("?", "?")  # Default values
            
            if system[0] == "Windows":
                # Parse wmic CSV format: Node,CommandLine,ProcessId
                if ',' in line and not line.startswith('Node'):
                    parts = line.split(',')
                    if len(parts) >= 3:
                        pid = parts[-1].strip()
                        process_path = ','.join(parts[1:-1]).strip('"')
            else:
                # Parse POSIX ps output
                parts = line.split(None, 7)
                if len(parts) > 1:
                    pid = parts[1]
                    process_path = parts[-1] if len(parts) > 7 else "?"

            # Extract Python executable path from command line
            python_exe_path = "?"
            logger.info(f"Process Path: {process_path}")
            if process_path != "?":
                is_windows = system[0] == "Windows"
                
                if is_windows:
                    # Windows: Handle malformed CSV where opening quote might be missing
                    # Pattern 1: Normal quoted path
                    match = re.search(r'"([^"]*python\d*(?:\.\d+)*\.exe)"', process_path, re.IGNORECASE)
                    if match:
                        python_exe_path = match.group(1)
                    else:
                        # Pattern 2: Missing opening quote but has closing quote (malformed CSV)
                        match = re.search(r'^([^"]*python\d*(?:\.\d+)*\.exe)"', process_path, re.IGNORECASE)
                        if match:
                            python_exe_path = match.group(1)
                        else:
                            # Pattern 3: Completely unquoted path
                            match = re.search(r'^([^\s]*python\d*(?:\.\d+)*\.exe)', process_path, re.IGNORECASE)
                            if match:
                                python_exe_path = match.group(1)
                else:
                    # POSIX: Handle both quoted and unquoted paths
                    # Note: Spaces in POSIX executable paths are extremely rare
                    if process_path.startswith('"'):
                        # Handle quoted paths: "path with spaces/python3.9" args
                        match = re.search(r'"([^"]*python\d*(?:\.\d+)*)"', process_path, re.IGNORECASE)
                        if match:
                            python_exe_path = match.group(1)
                    else:
                        # Handle unquoted paths (99.9% of cases)
                        cmd_parts = process_path.split()
                        if cmd_parts and re.search(r'python\d*(\.\d+)*$', cmd_parts[0], re.IGNORECASE):
                            python_exe_path = cmd_parts[0]

            # Determine process classification - single optimized check
            is_new_process = any(pattern in line_norm for pattern in exclude_patterns)
            process_type = "NEW" if is_new_process else "OLD"
            
            # Only count processes where we can extract Python executable path
            if python_exe_path != "?":
                logger.info(f"Process Details:")
                logger.info("-" * 80)
                logger.info(f"  PID: {pid}")
                logger.info(f"  Type: {process_type}")
                logger.info(f"  Python Executable: {python_exe_path}")
                logger.info(f"  Raw Line: {line.strip()}")
                logger.info("-" * 80)

                # Count based on process classification
                if is_new_process:
                    new_p_count += 1
                else:
                    old_p_count += 1

    return old_p_count, new_p_count

def prefix_strip(line, prefix):
    # strip beginning of the line with prefix
    # does not strip if prefix doesn't exist
    result = line
    if line.startswith(prefix):
        result = line[len(prefix):]
    return result.strip()

def get_dir_content(target):
    prefix = os.path.normpath(target) + os.sep  # normalize with OS separator
    dirs_tmp = []
    files_tmp = []
    for root, dirs, files in os.walk(target, followlinks=False):
        for name in dirs:
            path = os.path.normpath(os.path.join(root, name))
            dirs_tmp.append(prefix_strip(path, prefix))
        for name in files:
            if name != 'build.manifest':
                path = os.path.normpath(os.path.join(root, name))
                files_tmp.append(prefix_strip(path, prefix))
    dirs_tmp.reverse()
    dir_content = files_tmp + dirs_tmp
    return dir_content

# def get_dir_content(target):
#     prefix=target+'/'
#     dirs_tmp = []
#     files_tmp = []
#     for root, dirs, files in os.walk(target, followlinks=False):
#         for name in dirs:
#             dirs_tmp.append(prefix_strip(os.path.join(root, name), prefix))
#         for name in files:
#             if name != 'build.manifest':
#                 files_tmp.append(prefix_strip(os.path.join(root, name), prefix))
#     dirs_tmp.reverse()
#     dir_content = files_tmp + dirs_tmp
#     return dir_content

def delete_old_psc_folders():
    build_dir = make_splunkhome_path(["etc", "apps", psc_folder, "bin", SUPPORTED_SYSTEMS[system]])
    manifest_file = os.path.join(build_dir, 'build.manifest')
    
    if not os.path.isfile(manifest_file):
        logger.info(f"Manifest file {manifest_file} does not exist. No cleanup needed.")
        return []
        
    deleted_files = []
    with open(manifest_file) as f:
        files_in_manifest = [line.strip() for line in f.readlines()]
        files_in_build = get_dir_content(build_dir)
        
        # Remove '.' from manifest if present
        files_in_manifest = [f for f in files_in_manifest if f != '.']
        
        for file_in_build in files_in_build:
            if file_in_build not in files_in_manifest:
                file_path = os.path.join(build_dir, file_in_build)
                try:
                    # Optimized file removal using match-like logic
                    removal_actions = {
                        os.path.isfile: os.remove,
                        os.path.islink: os.unlink, 
                        os.path.isdir: os.rmdir
                    }
                    
                    removed = False
                    for check_func, remove_func in removal_actions.items():
                        if check_func(file_path):
                            remove_func(file_path)
                            removed = True
                            break
                    
                    if not removed:
                        logger.info(f"unhandled file {file_path}")
                        
                    deleted_files.append({
                        '_time': time.time(), 
                        'filename': file_in_build, 
                        'removed': 'true', 
                        'reason': ''
                    })
                except Exception as e:
                    deleted_files.append({
                        '_time': time.time(), 
                        'filename': file_in_build, 
                        'removed': 'false', 
                        'reason': str(e)
                    })
            else:
                files_in_manifest.remove(file_in_build)
                
    return deleted_files

if __name__ == "__main__":
    logger.info("#" * 100)
    logger.info("psc_cleanup_job Job started at %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    old_p_count, new_p_count = count_scientific_python_processes()
    logger.info(f"Found old_p_count: {old_p_count}, new_p_count: {new_p_count} processes")
    if old_p_count == 0:
        try:
            deleted_files = delete_old_psc_folders()
            headers = deleted_files[0].keys() if deleted_files else []
            if deleted_files:
                # Print header
                logger.info(" | ".join(headers))
                logger.info("-" * (len(headers) * 15))
                # Print rows
                for row in deleted_files:
                    if row['removed'] == 'true':
                        logger.info(" | ".join(str(row[h]) for h in headers))
            else:
                logger.info("No files deleted.")
            sys.exit(1)
        except Exception as e:
            logger.error(f"Error during cleanup: {traceback.format_exc()}")
            sys.exit(1)
    logger.info("psc_cleanup_job Job ended at %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    logger.info("#" * 100)
