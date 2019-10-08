#!/bin/bash

#### NOTE:
# This script helps with adding new version-pinned dependencies to packages.txt in each platform
# directory. For example, say we want to add new dependencies "pandas" and "scikit-learn". We create a new file
# with "scikit-learn" and "pandas" on each line (no "s) and feed the file to this script
# bash create_package_list.sh  <dependencies file>
# The output will contain the pinned-version of the package and the associated dependencies.

set -ex

source ./common.sh

set_base_variables

rm -rf "$BUILD_DIR"

package_list=$1

if [ "$PLATFORM" != "windows_x86_64" ]; then
    bash "$MINICONDA_PATH" -b -p "$CONDA_DIR"
    CONDA="$CONDA_DIR/bin/conda"
    "$CONDA" install -y --file "$package_list"
    "$CONDA" list --explicit
else
    INSTALL_PATH=`cygpath --absolute --windows "$BUILD_DIR"`
    chmod +x "$MINICONDA_PATH"
    "$MINICONDA_PATH" /S /InstallationType=JustMe /AddToPath=0 /RegisterPython=0 "/D=${TMP_PATH}" # ??? How to specify package file?
    CONDA="$BUILD_DIR/Scripts/conda.exe"
fi


