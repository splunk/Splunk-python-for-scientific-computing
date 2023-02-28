SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

rm -rf "$BASE_BUILD_DIR"
mkdir -p "$BASE_BUILD_DIR"
