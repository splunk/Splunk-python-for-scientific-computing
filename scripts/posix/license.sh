SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

PLATFORM="$PLATFORM" BLACKLISTED_PACKAGES="$BLACKLISTED_PACKAGES" VENV_BUILD_DIR="$VENV_BUILD_DIR" "$MINICONDA_BUILD_DIR/bin/python" "$PROJECT_DIR/tools/license.py"
echo -e "\n[INFO] Notice file $PLATFORM_DIR/NOTICE updated"
