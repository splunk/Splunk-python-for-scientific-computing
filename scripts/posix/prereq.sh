APP_NAME="Splunk_SA_Scientific_Python"
PROJECT_DIR=$(cd "$(dirname $(dirname $(dirname "${BASH_SOURCE[0]}")))" && pwd)
OS="$(uname)"
ARCH="$(uname -m)"
PLATFORM="$(echo "${OS}_$ARCH" | tr '[:upper:]' '[:lower:]')"
PLATFORM_DIR="$PROJECT_DIR/$PLATFORM"
BASE_BUILD_DIR="$PROJECT_DIR/build"
MINICONDA_BUILD_DIR="$BASE_BUILD_DIR/miniconda"
VENV_BUILD_DIR="$BASE_BUILD_DIR/venv"
APP_BUILD_DIR="$BASE_BUILD_DIR/${APP_NAME}_$PLATFORM"
DIST_BUILD_DIR="$APP_BUILD_DIR/bin/$PLATFORM"
PACK_FILE_PATH="$BASE_BUILD_DIR/miniconda-repack.tar.gz"
CONDA="$MINICONDA_BUILD_DIR/bin/conda"

# Platform detection
if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
  : # pass
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
  : # pass
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ]; then
  : # pass
else
  echo "[ERROR] This script does not support platform \"`uname`\", aborting."
  exit 1
fi

is_set() {
  if [ -z "${!1}" ]; then
    echo "env var $1 is required"
    exit 1
  fi
}
