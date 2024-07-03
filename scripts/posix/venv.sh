set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Treat unset variables and parameters as an error.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

if [ -z "$ENVIRONMENT_FILE" ]; then
  ENVIRONMENT_FILE="$PLATFORM_DIR/environment.yml"
else
  ENVIRONMENT_FILE="$PROJECT_DIR/$ENVIRONMENT_FILE"
fi

BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

# Print the paths
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "ENVIRONMENT_FILE: $ENVIRONMENT_FILE"
echo "VENV_BUILD_DIR: $VENV_BUILD_DIR"
echo "CONDA: $CONDA"

# Check if the environment directory exists before removing
if [ -d "$VENV_BUILD_DIR" ]; then
  rm -r "$VENV_BUILD_DIR"
fi

# Create the environment
echo "Creating conda environment from $ENVIRONMENT_FILE"
"$CONDA" env create --prefix "$VENV_BUILD_DIR" -f "$ENVIRONMENT_FILE"

# Print the created environment path
echo "Created environment at: $VENV_BUILD_DIR"

# Check if the environment was created successfully
if [ $? -ne 0 ]; then
  echo "Failed to create the conda environment"
  exit 1
fi

# Activate the environment
eval "$($CONDA shell.bash hook)"
conda activate "$VENV_BUILD_DIR"

# Clean conda cache
conda clean -tipy

# Remove blacklisted packages
if [ -n "$BLACKLISTED_PACKAGES" ]; then
  echo "Removing blacklisted packages: $BLACKLISTED_PACKAGES"
  "$CONDA" remove -p "$VENV_BUILD_DIR" -y --force $BLACKLISTED_PACKAGES || true
fi

echo "Conda environment setup complete."