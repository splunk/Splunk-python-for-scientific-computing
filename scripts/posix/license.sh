#!/bin/bash
# Generates license information and NOTICE file for the distribution
# Uses Python script to analyze packages and create license documentation

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

# Load blacklisted packages list
BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

# Run license analysis tool with environment variables
# This passes all necessary context to the Python license tool
PLATFORM="$PLATFORM" \
MICROMAMBA="$MICROMAMBA" \
BLACKLISTED_PACKAGES="$BLACKLISTED_PACKAGES" \
VENV_BUILD_DIR="$MAMBA_VENV_PREFIX" \
"$MICROMAMBA_BUILD_DIR/bin/python" "$PROJECT_DIR/tools/license_mamba.py"

echo "[INFO] License analysis complete - NOTICE file updated at $PLATFORM_DIR/NOTICE"