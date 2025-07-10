import json
import os
import logging
import time
import sys
import re
from datetime import datetime
import splunk.rest
import splunk.auth
import splunk.search as search

from splunk import setupSplunkLogger
from splunk.clilib.bundle_paths import make_splunkhome_path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from splunklib.modularinput import *

import os
import argparse
import json
import sys

import platform

SUPPORTED_SYSTEMS = {
    ('Linux', 'x86_64'): 'linux_x86_64',
    ('Darwin', 'x86_64'): 'darwin_x86_64',
    ('Darwin', 'arm64'): 'darwin_arm64',
    ('Windows', 'AMD64'): 'windows_x86_64',
}
PSC_PATH_PREFIX = 'Splunk_SA_Scientific_Python_'

# Define rename rules with type (prefix/suffix) and symbol
RENAME_RULES = {
    "scipy": {
        "type": "prefix",   # can be "prefix" or "suffix"
        "symbol": "_",
        "paths": [
            "sparse/linalg/isolve",
            "sparse/linalg/dsolve",
            "sparse/linalg/eigen",
            "io/harwell_boeing"
        ]
    }
}

ALLOWED_VERSIONS = {"3.2.1", "3.2.2", "3.2.3", "3.2.4",
                    "4.2.1", "4.2.2", "4.2.3", "4.2.4"}

def get_system_paths():
    if platform.system() == "Darwin" and "ARM64" in platform.version():
        system = (platform.system(), "arm64")
    else:
        system = (platform.system(), platform.machine())
    if system not in SUPPORTED_SYSTEMS:
        raise Exception(f'Unsupported platform: {system}')

    psc = f"{PSC_PATH_PREFIX}{SUPPORTED_SYSTEMS[system]}"

    return psc, system

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

def validate_app_version():
    manifest_path = make_splunkhome_path(["etc",
        "apps",
        psc_folder,
        "app.manifest"])

    if not os.path.isfile(manifest_path):
        logger.info(f"[ERROR] app.manifest file not found: {manifest_path}, Please check the SPLUNK_HOME path")
        sys.exit(1)

    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_data = json.load(f)
        version = manifest_data["info"]["id"]["version"]
    except Exception as e:
        logger.info(f"[ERROR] Failed to read or parse app.manifest: {e}")
        sys.exit(1)

    if version not in ALLOWED_VERSIONS:
        logger.info(f"[ERROR] App version '{version}' is not supported.")
        logger.info(f"[INFO] Supported versions: {', '.join(sorted(ALLOWED_VERSIONS))}")
        sys.exit(1)

    logger.info(f"[INFO] App version '{version}' is valid for renaming folders.")

def rename_folders(rename_map):
    base_path = make_splunkhome_path(["etc",
        "apps",
        psc_folder,
        "bin",
        SUPPORTED_SYSTEMS[system],
        "Lib",
        "site-packages"])

    renamed_summary = {}

    for library, config in rename_map.items():
        marker_type = config.get("type", "prefix")
        symbol = config.get("symbol", "_")
        rel_paths = config.get("paths", [])

        logger.info("#" * 50)
        logger.info(f"[INFO] Processing for '{library}' package using {marker_type} '{symbol}'")

        for rel_path in rel_paths:
            full_original_path = os.path.join(base_path, library, *rel_path.split("/"))
            parent_dir = os.path.dirname(full_original_path)
            base_name = os.path.basename(full_original_path)

            if marker_type == "prefix":
                upgraded_name = symbol + base_name
            elif marker_type == "suffix":
                upgraded_name = base_name + symbol
            else:
                logger.info(f"[ERROR] Unknown type '{marker_type}' — must be 'prefix' or 'suffix'. Skipping.")
                continue

            upgraded_path = os.path.join(parent_dir, upgraded_name)
            renamed_path = full_original_path + "_old"

            if not os.path.exists(full_original_path):
                logger.info(f"[INFO] Skipping '{base_name}': original path not found.")
                continue

            if not os.path.exists(upgraded_path):
                logger.info(f"[INFO] Skipping '{base_name}': upgraded version '{upgraded_name}' not found.")
                continue

            if os.path.exists(renamed_path):
                logger.info(f"[WARNING] Skipping '{base_name}': '{base_name}_old' already exists.")
                continue

            try:
                os.rename(full_original_path, renamed_path)
                logger.info(f"[SUCCESS] Renamed '{base_name}' → '{base_name}_old'")
                renamed_summary.setdefault(library, []).append(
                    f"{rel_path} -> {renamed_path}"
                )
            except Exception as e:
                logger.info(f"[ERROR] Failed to rename '{base_name}': {e}")

    if renamed_summary:
        logger.info("\n" + "=" * 60)
        logger.info("Renamed Folders Summary:")
        logger.info("{")
        for lib, changes in renamed_summary.items():
            logger.info(f'    "{lib}": [')
            for item in changes:
                logger.info(f'        "{item}",')
            logger.info("    ],")
        logger.info("}")
    else:
        logger.info("\n[INFO] No folders were renamed.")

def main():
    # args = parse_args()
    validate_app_version()
    rename_folders(RENAME_RULES)

if __name__ == "__main__":
    logger.info("#" * 100)
    logger.info("psc_cleanup_job Job started at %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    try:
        if system[0] == 'Windows':
            main()
        else:
            logger.info("No Need to run psc_cleanup_job on non-Windows systems.")
        logger.info("psc_cleanup_job Job ended at %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        logger.info("#" * 100)
        sys.exit(1)
    except Exception as e:
        sys.exit(1)