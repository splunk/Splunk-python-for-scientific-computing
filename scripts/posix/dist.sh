#!/bin/bash
# Creates the final distribution tarball from the built application

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

echo "[INFO] Creating build tarball..."

# Create compressed tarball of the entire application build
tar czf "$APP_BUILD_DIR.tgz" -C "$BASE_BUILD_DIR" "${APP_NAME}_${PLATFORM}"

echo "[INFO] Build tarball created: $APP_BUILD_DIR.tgz"