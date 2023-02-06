SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

tar czf "${APP_BUILD_DIR}.tgz" -C "$BASE_BUILD_DIR" "$PLATFORM"
