import sys
import pandas as pd
from loguru import logger
import os
import re

PLATFORM_DIRS = ["darwin_x86_64", "linux_x86_64", "windows_x86_64"]
PLATFORM_FILE_NAME = "license_report.csv"
CHANNEL_COLUMN = "channel"
LIBRARY_COLUMN = "name"


class CommercialChannelException(Exception):
    def __init__(self, message, problems):
        super().__init__(message)
        self.problems = problems


def is_commercial_channel(channel_name):
    if re.match(r"^pkgs[\\/]", channel_name):
        return True
    return False


def check_license_reports_presence(platform_dirs, platform_file_name):
    root_path = os.path.dirname(os.path.realpath(__name__))
    logger.info(f"Root path determined as: {root_path}")
    license_report_paths = []
    for platform in platform_dirs:
        if not os.path.exists(os.path.join(root_path, platform)):
            raise RuntimeError(f"Platform directory {platform} does not exist.")
        else:
            platform_path = os.path.join(root_path, platform)
        file_path = os.path.join(platform_path, platform_file_name)

        if not os.path.exists(file_path):
            raise RuntimeError(
                f"License report file does not exist for platform {platform}."
            )
        else:
            license_report_paths.append(file_path)

    logger.info("All license report files are present.")

    return license_report_paths


def perform_sanity(license_report_paths, channel_column, library_column):
    problems = {}

    for report_path in license_report_paths:
        try:
            df = pd.read_csv(report_path)
        except Exception as e:
            logger.error(f"Failed to read {report_path}: {e}")
            continue

        if channel_column not in df.columns:
            logger.error(f"Column '{channel_column}' not found in {report_path}.")
            continue

        if library_column not in df.columns:
            logger.error(f"Column '{library_column}' not found in {report_path}.")
            continue

        library_to_channel_dict = dict(zip(df[library_column], df[channel_column]))

        try:
            anaconda_commercial_libraries = dict(
                filter(
                    lambda library_info: is_commercial_channel(library_info[1]),
                    library_to_channel_dict.items(),
                )
            )
        except Exception as e:
            logger.error(
                f"Error while filtering commercial libraries in {report_path}: {e}"
            )
            continue

        try:
            if len(anaconda_commercial_libraries) > 0:
                logger.info(
                    f"Commercial libraries found in {report_path}: {anaconda_commercial_libraries}"
                )

                platform = os.path.basename(os.path.dirname(report_path))

                problems[platform] = anaconda_commercial_libraries
            else:
                logger.info(f"No commercial libraries found in {report_path}.")
        except Exception as e:
            logger.error(
                f"Error while processing commercial libraries in {report_path}: {e}"
            )
            continue

    if len(problems) > 0:
        raise CommercialChannelException("Commercial libraries detected in license reports.", problems=problems)


def check_if_commercial_libs_present(
        platform_dirs, platform_file_name, channel_column, library_column
):
    try:
        license_report_paths = check_license_reports_presence(
            platform_dirs=platform_dirs, platform_file_name=platform_file_name
        )

        perform_sanity(
            license_report_paths=license_report_paths,
            channel_column=channel_column,
            library_column=library_column,
        )
        logger.info("Sanity check passed: No commercial libraries found.")
    except CommercialChannelException as e:
        logger.error(f"Sanity check failed: {e}")
        for platform, libs in e.problems.items():
            logger.error(f"Platform: {platform}, Commercial Libraries: {libs}")
        sys.exit(1)


if __name__ == "__main__":

    command_line_args = sys.argv[1:]

    logger.debug(f"Command line arguments: {command_line_args}")

    if len(command_line_args) == 0:
        logger.info("No command line arguments provided. Using default configuration of 4.x")
    else:
        psc_version = command_line_args[0]
        if "." not in psc_version:
            logger.error("Invalid PSC version format. Please provide a version in the format 'X.Y.Z' (e.g., '4.2.2').")
            sys.exit(1)
        else:
            major_version = psc_version.split(".")[0]

            if len(major_version) == 0 or not major_version.isdigit():
                logger.error("Invalid PSC version format. Major version should be a number.")
                sys.exit(1)
            else:
                major_version = int(major_version)
                if major_version == 4:
                    PLATFORM_DIRS.append("darwin_arm64")
                elif major_version != 3:
                    logger.error("Unsupported PSC major version. Only versions 3.x and 4.x are supported.")
                    sys.exit(1)

    logger.info(f"PLATFORM_DIRS: {PLATFORM_DIRS}")

    check_if_commercial_libs_present(
        platform_dirs=PLATFORM_DIRS,
        platform_file_name=PLATFORM_FILE_NAME,
        channel_column=CHANNEL_COLUMN,
        library_column=LIBRARY_COLUMN,
    )