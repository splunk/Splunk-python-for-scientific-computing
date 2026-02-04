#!/bin/bash
# Cleans up all build artifacts and resets the build environment
# Removes the entire build directory and recreates an empty one

# Import common variables and functions from prerequisites
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

echo "[INFO] Removing build directory: $BASE_BUILD_DIR"

# Remove entire build directory and all contents
# This clears all previous builds, downloaded packages, and virtual environments
rm -rf "$BASE_BUILD_DIR"

echo "[INFO] Creating clean build directory"

# Recreate empty build directory for future builds
mkdir -p "$BASE_BUILD_DIR"

echo "[INFO] Build environment cleaned successfully"