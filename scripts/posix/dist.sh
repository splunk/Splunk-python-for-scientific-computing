SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

echo "[INFO] creating build tarball"
tar czf "$APP_BUILD_DIR.tgz" -C "$BASE_BUILD_DIR" "${APP_NAME}_${PLATFORM}"
echo "[INFO] build tarball created"