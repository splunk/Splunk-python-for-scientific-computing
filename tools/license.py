import json
import os
import csv
import conda.cli.python_api
from datetime import date
from collections import OrderedDict
from conda.exceptions import PackagesNotFoundError
from colorama import init, Fore, Back, Style

script_dir = os.path.dirname(os.path.realpath(__file__))

extra_conda_blacklist = ['conda', 'conda-package-handling', 'pycosat', 'ruamel_yaml'] # need to install conda to make this script work, so we need to exclude conda from end package
blacklisted_pkgs = os.environ['BLACKLISTED_PACKAGES'].split(" ") + extra_conda_blacklist
platform = os.environ['PLATFORM']

def scan_installed():
    pkgs_scanned = OrderedDict()

    pkgs_installed = json.loads(conda.cli.python_api.run_command(conda.cli.python_api.Commands.LIST, '-p', os.environ["VENV_BUILD_DIR"],  '--json')[0])

    for pkg_installed in pkgs_installed:
        # Example `pkg`:
        # {'base_url': 'https://conda.anaconda.org/conda-forge', 'build_number': 1014, 'build_string': 'h166bdaf_1014', 'channel': 'conda-forge', 'dist_name': 'zlib-1.2.11-h166bdaf_1014', 'name': 'zlib', 'platform': 'linux-64', 'version': '1.2.11'}
        try:
            res = json.loads(conda.cli.python_api.run_command(conda.cli.python_api.Commands.SEARCH, '-c', pkg_installed["channel"], '-i', '--json', f'{pkg_installed["name"]}={pkg_installed["version"]}')[0])
            builds_scanned = res[pkg_installed['name']]
            for build_scanned in builds_scanned:
                # Example `build`:
                # {'arch': None, 'build': 'h166bdaf_1014', 'build_number': 1014, 'channel': 'https://conda.anaconda.org/conda-forge/linux-64', 'constrains': [], 'depends': ['libgcc-ng >=10.3.0', 'libzlib 1.2.11 h166bdaf_1014'], 'fn': 'zlib-1.2.11-h166bdaf_1014.tar.bz2', 'license': 'Zlib', 'license_family': 'Other', 'md5': 'def3b82d1a03aa695bb38ac1dd072ff2', 'name': 'zlib', 'platform': None, 'sha256': 'ccfdb4dcceae8b191ddd4703e7be84eff2ba82b53788d6bb9298e531bae4eaf9', 'size': 89692, 'subdir': 'linux-64', 'timestamp': 1648307208744, 'url': 'https://conda.anaconda.org/conda-forge/linux-64/zlib-1.2.11-h166bdaf_1014.tar.bz2', 'version': '1.2.11'}
                if build_scanned["build"] == pkg_installed["build_string"] and build_scanned["build_number"] == pkg_installed["build_number"]:
                    del build_scanned['channel']
                    pkgs_scanned[pkg_installed['name']] = {**pkg_installed, **build_scanned}
                    break
        except PackagesNotFoundError:
            print(f"[{Fore.YELLOW}WARN{Fore.RESET}] Package [{pkg_installed['name']}] not found in conda, maybe a pip package")
            pkgs_scanned[pkg_installed['name']] = pkg_installed
    return pkgs_scanned

def read_license_csv(filepath, key_field):
    transformed = OrderedDict()
    with open(filepath, "r") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            transformed[row[key_field]]=row
    return transformed


current_license_report = read_license_csv(os.path.join(script_dir, '..', platform, 'license_report.csv'), 'name')
license_extra_info = read_license_csv(os.path.join(script_dir, 'license_extra.csv'), 'name')


def write_license_csv(filepath, pkgs, fieldnames=None):
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
        if name not in blacklisted_pkgs:
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
        # Update license_extra.csv file
        print(f"[{Fore.RED}FIX{Fore.RESET}] Please update license_extra.csv")
        write_license_csv(os.path.join(script_dir, 'license_extra.csv'), license_extra_info)


def generate_license_report(pkgs_scanned):
    pkg_report = {}
    for name, pkg in get_packages(pkgs_scanned):
        pkg_extra_info = license_extra_info.get(name)
        license = pkg.get('license')
        if license is None:
            print(f"[{Fore.YELLOW}WARN{Fore.RESET}] {name} has no license in conda package metadata")
            license = ""
        pkg_report[name] = pkg
        pkg_report[name]["license_url"] = pkg_extra_info['license_url']
        pkg_report[name]["functionality"] = pkg_extra_info['functionality']
        pkg_report[name]["notes"] = pkg_extra_info['notes']
    # Write to platform's license file
    fieldnames = ["name", "version", "license", "license_url", "functionality", "notes", "dist_name", "channel", "build", "build_number"]
    write_license_csv(os.path.join(script_dir, "..", os.environ['PLATFORM'], "license_report.csv"), pkg_report, fieldnames)
       

def generate_app_license_file(pkgs_scanned):
    license_content = ""
    with open(os.path.join(script_dir, "..", "LICENSE")) as f:
        current_year = date.today().year
        license_content = f.read().replace("@year@", str(current_year))
        license_content += "\n\n========================================================================\n"
        license_packages = "Package licenses:\n"
        for name, pkg in get_packages(pkgs_scanned):
            pkg_extra_info = license_extra_info.get(name)
            license = pkg.get('license')
            if license is None:
                license = ""
            if pkg_extra_info['license_override'] != "":
                license = pkg_extra_info['license_override']
            if pkg_extra_info is None:
                license_url = ""
            else:
                license_url = pkg_extra_info.get('license_url')
            license_packages += f"{name.ljust(30)}\t{license.ljust(36)}\t{license_url}\n"
        license_content += license_packages
    # Write to platform's license file
    with open(os.path.join(script_dir, "..", platform, "LICENSE"), "w") as f:
        f.write(license_content)

pkgs_scanned = scan_installed()
update_license_extra(pkgs_scanned)
generate_app_license_file(pkgs_scanned)
generate_license_report(pkgs_scanned)
