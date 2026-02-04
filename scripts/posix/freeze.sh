#!/bin/bash
# Exports the current environment to environment.yml file
# Creates a reproducible package list for the platform

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

OUTPUT_PACKAGE_LIST_FILE="$PLATFORM_DIR/environment.yml"

echo "[INFO] Exporting environment to $OUTPUT_PACKAGE_LIST_FILE..."

# Export current environment configuration
"$MICROMAMBA" env export -p "$MAMBA_VENV_PREFIX" > "$OUTPUT_PACKAGE_LIST_FILE"

# Remove the last line (contains build-system specific information)
if [ "$OS" = "Darwin" ]; then
  sed -i '' -e '$ d' "$OUTPUT_PACKAGE_LIST_FILE"
else
  sed -i '$ d' "$OUTPUT_PACKAGE_LIST_FILE"
fi

# Clean up build directory paths from the exported file
if [ "$OS" = "Darwin" ]; then
  sed -i '' -e "s/${PROJECT_DIR//\//\\/}\///" "$OUTPUT_PACKAGE_LIST_FILE"
else
  sed -i "s/${PROJECT_DIR//\//\\/}\///" "$OUTPUT_PACKAGE_LIST_FILE"
fi

# Show differences if file already existed
echo "[INFO] Environment file generated. Showing changes:"
git diff "$OUTPUT_PACKAGE_LIST_FILE"