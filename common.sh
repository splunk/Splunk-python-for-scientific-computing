# Common utility code

set_base_variables() {

#https://repo.anaconda.com/miniconda/
MINICONDA_VERSION="Miniconda3-4.7.10"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ "`uname`" = "Linux" ]; then
    if [ "`uname -m`" = "x86_64" ]; then
        MINICONDA_FILE="${MINICONDA_VERSION}-Linux-x86_64.sh"
        PLATFORM="linux_x86_64"
    else
        echo "Unknown platform \"`uname`\", aborting."
        exit 1
    fi
elif [ "`uname`" = "Darwin" ]; then
    MINICONDA_FILE="${MINICONDA_VERSION}-MacOSX-x86_64.sh"
    PLATFORM="darwin_x86_64"
    export COPYFILE_DISABLE=true
elif [[ "`uname`" == "CYGWIN"* ]]; then
    MINICONDA_FILE="${MINICONDA_VERSION}-Windows-x86_64.exe"
    PLATFORM="windows_x86_64"
else
    echo "Unknown platform \"`uname`\", aborting."
    exit 1
fi

BUILD_BASE_DIR="$SCRIPT_DIR/build"
PLATFORM_DIR="$SCRIPT_DIR/$PLATFORM"
MINICONDA_PATH="$PLATFORM_DIR/$MINICONDA_FILE"
BUILD_DIR="$BUILD_BASE_DIR/$PLATFORM"
CONDA_DIR="$BUILD_DIR/conda"

test -f "$MINICONDA_PATH"

# Helpers
XARGS="xargs -r"
if [ "$PLATFORM" = "darwin_x86_64" ]; then
    XARGS="xargs"
fi

}
