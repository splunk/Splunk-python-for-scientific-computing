#!/bin/bash
# Creates and configures the Python virtual environment
# Uses environment.yml file and removes blacklisted packages

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

if [ "$OS" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
  export CONDA_OVERRIDE_OSX="11"
fi

# Determine environment file to use
if [ -z "$ENVIRONMENT_FILE" ]; then
  ENVIRONMENT_FILE="$PLATFORM_DIR/environment.yml"
else
  ENVIRONMENT_FILE="$PROJECT_DIR/$ENVIRONMENT_FILE"
fi

# Load blacklisted packages (convert newlines to spaces)
BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

# Clean up existing virtual environment
echo "[INFO] Removing existing virtual environment..."
rm -rf "$MAMBA_ROOT_PREFIX"

"$MICROMAMBA" config remove channels defaults || true
"$MICROMAMBA" config set channel_priority strict

# Create new virtual environment from environment file
echo "[INFO] Creating virtual environment from $ENVIRONMENT_FILE..."
"$MICROMAMBA" create --yes --prefix "$MAMBA_VENV_PREFIX" -f "$ENVIRONMENT_FILE" -c conda-forge --override-channels

# Activate the environment
"$MICROMAMBA" activate "$MAMBA_VENV_PREFIX"

# Remove blacklisted packages (ignore errors if packages don't exist)
if [ -n "$BLACKLISTED_PACKAGES" ]; then
  echo "[INFO] Removing blacklisted packages: $BLACKLISTED_PACKAGES"
  "$MICROMAMBA" remove -p "$MAMBA_VENV_PREFIX" -y --force $BLACKLISTED_PACKAGES || true
fi

echo "[INFO] Virtual environment setup complete"