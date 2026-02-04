import json
import os
import csv
import subprocess
import time
from collections import OrderedDict
import concurrent.futures

script_dir = os.path.dirname(os.path.realpath(__file__))

def get_env_var(name, default=None, required=True):
    value = os.environ.get(name, default)
    if required and value is None:
        raise EnvironmentError(f"Required environment variable '{name}' is missing.")
    return value

extra_mamba_blacklist = ['micromamba', 'conda-package-handling', 'pycosat', 'ruamel_yaml']
blacklisted_pkgs = get_env_var('BLACKLISTED_PACKAGES', '').split(" ") + extra_mamba_blacklist
platform = get_env_var('PLATFORM')
micromamba_path = get_env_var('MICROMAMBA')
venv_path = get_env_var('VENV_BUILD_DIR')

class Fore:
    YELLOW = "\033[33m"
    WHITE  = "\033[37m"
    RED    = "\033[31m"
    RESET  = "\033[0m"

def run_micromamba_with_retry(args, max_retries=5, delay=1):
    for attempt in range(max_retries):
        try:
            result = subprocess.run([micromamba_path] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if result.returncode == 0:
                return result.stdout
            else:
                print(f"[{Fore.YELLOW}WARN{Fore.RESET}] micromamba attempt {attempt + 1} failed: {result.stderr}")
                if attempt < max_retries - 1:
                    time.sleep(delay)
        except Exception as e:
            print(f"[{Fore.YELLOW}WARN{Fore.RESET}] micromamba attempt {attempt + 1} failed with exception: {e}")
            if attempt < max_retries - 1:
                time.sleep(delay)
    raise RuntimeError(f"micromamba error after {max_retries} attempts")

def fetch_package_info(pkg_installed, venv_path):
    try:
        search_output = run_micromamba_with_retry([
            'search', '-c', pkg_installed.get("channel", "conda-forge"), '-p', venv_path, '--json',
            f'{pkg_installed["name"]}={pkg_installed["version"]}'
        ])
        res = json.loads(search_output)
        if "result" in res and "pkgs" in res["result"] and len(res["result"]["pkgs"]) > 0:
            license_details = res["result"]["pkgs"][0]
            print(f"{license_details['name']}=={license_details['version']}==>{license_details.get('license', '')}")
            if license_details.get("build") == pkg_installed.get("build_string") and license_details.get("build_number") == pkg_installed.get("build_number"):
                license_details.pop('channel', None)
            return pkg_installed['name'], {**pkg_installed, **license_details}
    except Exception as e:
        print(f"[{Fore.YELLOW}WARN{Fore.RESET}] Package [{pkg_installed['name']}] not found in micromamba after retries: {e}")

    # pkg_installed.setdefault('license', "")
    if 'build' not in pkg_installed and 'build_string' in pkg_installed:
        pkg_installed['build'] = pkg_installed['build_string']
    return pkg_installed['name'], pkg_installed

def scan_installed_parallel():
    pkgs_scanned = OrderedDict()
    output = run_micromamba_with_retry(['list', '-p', venv_path, '--json'])
    pkgs_installed = json.loads(output)
    seen_packages = set()
    required_fields = ['name', 'version', 'license', 'build']
    valid_channels = ['conda-forge', 'pytorch']
    # valid_licenses = ['MIT', 'Apache-2.0', 'GPL-3.0', 'BSD-3-Clause']
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(fetch_package_info, pkg, venv_path) for pkg in pkgs_installed]
        for future in concurrent.futures.as_completed(futures):
            name, pkg_info = future.result()
            if 'license' not in pkg_info or pkg_info['license'] is None:
                pkg_info['license'] = ""
            # Mandatory fields check
            for field in required_fields:
                if field not in pkg_info or not pkg_info[field]:
                    print(f"[{Fore.RED}ERROR{Fore.RESET}] Missing or empty field '{field}' for package {name}")
            # Field type validation
            if not isinstance(pkg_info.get('version', ''), str):
                print(f"[{Fore.RED}ERROR{Fore.RESET}] Invalid type for 'version' in package {name}")
            # License format validation
            # if pkg_info.get('license', '').strip() and pkg_info.get('license', '') not in valid_licenses:
            #     print(f"[{Fore.YELLOW}WARN{Fore.RESET}] Unknown license '{pkg_info.get('license', '')}' for package {name}")
            # Channel validation
            if pkg_info.get('channel', '') and pkg_info.get('channel', '') not in valid_channels:
                print(f"[{Fore.YELLOW}WARN{Fore.RESET}] Unexpected channel '{pkg_info.get('channel', '')}' for package {name}")
            # Duplicate package check
            if name in seen_packages:
                print(f"[{Fore.RED}ERROR{Fore.RESET}] Duplicate package detected: {name}")
            seen_packages.add(name)
            # Build number check
            if not isinstance(pkg_info.get('build_number', -1), int) or pkg_info['build_number'] < 0:
                print(f"[{Fore.RED}ERROR{Fore.RESET}] Invalid build number for package {name}")
            pkgs_scanned[name] = pkg_info
    return pkgs_scanned

def read_license_csv(filepath, key_field):
    transformed = OrderedDict()
    if not os.path.exists(filepath):
        print(f"[{Fore.YELLOW}WARN{Fore.RESET}] File not found: {filepath}")
        return transformed
    with open(filepath, "r") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            transformed[row[key_field]] = row
    return transformed

current_license_report = read_license_csv(os.path.join(script_dir, '..', platform, 'license_report.csv'), 'name')
license_extra_info = read_license_csv(os.path.join(script_dir, 'license_extra.csv'), 'name')

def write_license_csv(filepath, pkgs, fieldnames=None):
    if not pkgs:
        print(f"[{Fore.YELLOW}WARN{Fore.RESET}] No packages to write to {filepath}")
        return
    with open(filepath, "w", newline='') as csvfile:
        if fieldnames is None:
            fieldnames = list(pkgs.values())[0].keys()
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        output = OrderedDict(sorted(pkgs.items()))
        for _, item in output.items():
            writer.writerow(item)

def get_packages(pkgs_scanned):
    for name, pkg in pkgs_scanned.items():
        if name and name not in blacklisted_pkgs:
            yield (name, pkg)

def update_license_extra(pkgs_scanned):
    license_extra_updated = False
    for name, pkg in get_packages(pkgs_scanned):
        pkg_extra_info = license_extra_info.get(name)
        if pkg_extra_info is None:
            license_extra_info[name] = { "name": name, "license_override": "", "license_url": "", "functionality": "", "notes": ""}
            license_extra_updated = True
            print(f"[{Fore.WHITE}INFO{Fore.RESET}] New package: {name}")
    if license_extra_updated:
        print(f"[{Fore.RED}FIX{Fore.RESET}] Please update license_extra.csv")
        write_license_csv(os.path.join(script_dir, 'license_extra.csv'), license_extra_info)

def generate_license_report(pkgs_scanned):
    pkg_report = {}
    for name, pkg in get_packages(pkgs_scanned):
        pkg_extra_info = license_extra_info.get(name, {})
        license = pkg.get('license', "")
        if not license or not license.strip():
            print(f"[{Fore.YELLOW}WARN{Fore.RESET}] {name} has no license in micromamba package metadata")
        pkg_report[name] = pkg
        pkg_report[name]["license_url"] = pkg_extra_info.get('license_url', "")
        pkg_report[name]["functionality"] = pkg_extra_info.get('functionality', "")
        pkg_report[name]["notes"] = pkg_extra_info.get('notes', "")
    fieldnames = ["name", "version", "license", "license_url", "functionality", "notes", "dist_name", "channel", "build", "build_number"]
    write_license_csv(os.path.join(script_dir, "..", platform, "license_report.csv"), pkg_report, fieldnames)

def generate_app_license_file(pkgs_scanned):
    license_content = ""
    license_file_path = os.path.join(script_dir, "..", "LICENSE")
    if not os.path.exists(license_file_path):
        print(f"[{Fore.YELLOW}WARN{Fore.RESET}] LICENSE file not found: {license_file_path}")
        return
    with open(license_file_path) as f:
        license_packages = "Package licenses:\n"
        for name, pkg in get_packages(pkgs_scanned):
            pkg_extra_info = license_extra_info.get(name, {})
            license = pkg.get('license', "")
            if pkg_extra_info.get('license_override'):
                license = pkg_extra_info['license_override']
            license_url = pkg_extra_info.get('license_url', "")
            license_packages += f"{name.ljust(30)}\t{license.ljust(36)}\t{license_url}\n"
        license_content += license_packages
    with open(os.path.join(script_dir, "..", platform, "NOTICE"), "w") as f:
        f.write(license_content)

if __name__ == "__main__":
    pkgs_scanned = scan_installed_parallel()
    update_license_extra(pkgs_scanned)
    generate_app_license_file(pkgs_scanned)
    generate_license_report(pkgs_scanned)