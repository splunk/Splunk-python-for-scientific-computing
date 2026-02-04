#!/bin/bash

# Get the script directory and source prerequisites
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

# Check required environment variables
is_set BUILD
is_set VERSION

#VERSION="4.2.4"


echo "-----------------"
echo "Building PSC $VERSION build $BUILD"
echo "-----------------"

# Set platform-specific variables
if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
  XARGS="xargs -r"
  MANIFEST_FILE="app.manifest.linux"
elif [ "$OS" = "Darwin" ]; then
  XARGS="xargs"
  MANIFEST_FILE="app.manifest.osx"
  export COPYFILE_DISABLE=true
else
  echo "[ERROR] This script does not support platform \"$(uname)\", aborting."
  exit 1
fi

# Prepare build directories
rm -rf "$APP_BUILD_DIR"
DIST_VERSION_BUILD_DIR="$DIST_BUILD_DIR/${VERSION//./_}"
echo "[INFO] Distribution build directory: $DIST_VERSION_BUILD_DIR"
DIST_BIN_BUILD_DIR="$DIST_BUILD_DIR/bin"
mkdir -p "$DIST_VERSION_BUILD_DIR"
mkdir -p "$DIST_BIN_BUILD_DIR"

# Extract conda-pack archive
echo "[INFO] Extracting conda-pack archive to $DIST_VERSION_BUILD_DIR"
tar jxf "$MAMBA_PACK_FILE_PATH" -C "$DIST_VERSION_BUILD_DIR"

# Clean up extracted archive
echo "[INFO] Cleaning extracted archive"
# Remove Python cache files
find "$DIST_VERSION_BUILD_DIR" -iname "__pycache__" -print0 | $XARGS -0 rm -r
find "$DIST_VERSION_BUILD_DIR" -iname "*.pyc" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -iname "*.pyo" -print0 | $XARGS -0 rm

# Remove static libraries and libtool files
find "$DIST_VERSION_BUILD_DIR" -iname "*.a" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -iname "*.la" -print0 | $XARGS -0 rm

# Remove data files
find "$DIST_VERSION_BUILD_DIR" -iname "*.csv" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -iname "*.csv.gz" -print0 | $XARGS -0 rm

# Remove build files
find "$DIST_VERSION_BUILD_DIR" -iname "Makefile" -print0 | $XARGS -0 rm

# Remove wheel files and broken symlinks
find "$DIST_VERSION_BUILD_DIR" -iname "*.whl" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -xtype l -print0 | $XARGS -0 rm

# Remove all test folders except networkx's tests folder
PKG_INCLUDE_TESTS="$DIST_VERSION_BUILD_DIR/*networkx*"

# Do not remove numpy core test files
PKG_INCLUDE_NUMPY="$DIST_VERSION_BUILD_DIR/*numpy*"
PKG_INCLUDE_NUMPY_CORE="$DIST_VERSION_BUILD_DIR/*numpy*/_core/test*"

find "$DIST_VERSION_BUILD_DIR" -type d \( -iname tests -o -iname test \) -not -path "$PKG_INCLUDE_TESTS" -not -path "$PKG_INCLUDE_NUMPY_CORE" -not -path "$PKG_INCLUDE_NUMPY/tests" -print0 | $XARGS -0 rm -rf

# Remove ONNX test data files
find "$DIST_VERSION_BUILD_DIR" -type f -iwholename "*onnx/backend/test/*" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -type d -iwholename "*onnx/backend/test" -print0 | $XARGS -0 rm -rf

# Remove other unnecessary files if not in production mode
if [[ $MODE -eq 0 ]]; then
  echo "[INFO] Removing development and build artifacts"
  rm -rf "$DIST_VERSION_BUILD_DIR"/lib/{Tk.icns,Tk.tiff,tcl8,tcl8.5,tk8.5} \
    "$DIST_VERSION_BUILD_DIR"/conda-meta \
    "$DIST_VERSION_BUILD_DIR"/etc \
    "$DIST_VERSION_BUILD_DIR"/include \
    "$DIST_VERSION_BUILD_DIR"/lib/pkgconfig \
    "$DIST_VERSION_BUILD_DIR"/lib/python3.8/site-packages/scipy/weave \
    "$DIST_VERSION_BUILD_DIR"/lib/xml2Conf.sh \
    "$DIST_VERSION_BUILD_DIR"/lib/xsltConf.sh \
    "$DIST_VERSION_BUILD_DIR"/lib/terminfo \
    "$DIST_VERSION_BUILD_DIR"/share \
    "$DIST_VERSION_BUILD_DIR"/bin/.scikit-learn-post-link.sh
fi

# Convert symlinks to actual copies for portability
echo "[INFO] Converting symlinks to copies"
SYMLINK_SUBDIRS="bin lib"
for subdir in $SYMLINK_SUBDIRS; do
  while read i; do
    j=$(readlink "$i")
    d=$(dirname "$i")
    b=$(basename "$i")
    bash -c "cd \"$d\"; rm \"$b\"; cp -r \"$j\" \"$b\""
  done < <(find "$DIST_VERSION_BUILD_DIR/${subdir}" -type l)
done

# Rename versioned binaries to expected names if present
echo "[INFO] Renaming versioned binaries if present"
cd "$DIST_VERSION_BUILD_DIR/bin/"
for f in python3.*; do
  [ -f "$f" ] && mv "$f" python && break
done
for f in python3.*-config; do
  [ -f "$f" ] && mv "$f" python3-config && break
done
for f in protoc-*; do
  [ -f "$f" ] && mv "$f" protoc && break
done
cd -

# Keep only essential binaries in bin/
echo "[INFO] Removing non-essential binaries from bin/"
find "$DIST_VERSION_BUILD_DIR/bin/" -type f,l ! '(' -name 'python' -o -name 'openssl' -o -name 'python3-config' -o -name 'protoc' ')' -print0 | $XARGS -0 rm

# List final directory structure
ls -ld "$DIST_VERSION_BUILD_DIR"

# Set appropriate permissions
echo "[INFO] Setting permissions"
chmod -x+X -R "$DIST_VERSION_BUILD_DIR/"
chmod g-w -R "$DIST_VERSION_BUILD_DIR/"
find "$DIST_VERSION_BUILD_DIR/bin/" -type f -print0 | $XARGS -0 chmod ug+x

# Remove unnecessary metadata if not in production mode
echo "[INFO] Removing unnecessary metadata"
if [[ $MODE -eq 0 ]]; then
  rm -rf "$DIST_VERSION_BUILD_DIR"/conda-meta
  rm -rf "$DIST_VERSION_BUILD_DIR"/pkgs
  rm -rf "$DIST_VERSION_BUILD_DIR"/envs
fi

# Build application configs
echo "[INFO] Building app configs"
cp -a "$PROJECT_DIR/package/." "$APP_BUILD_DIR/"
cp "$PROJECT_DIR/shims/python" "$DIST_BIN_BUILD_DIR/python"
cp "$PROJECT_DIR/resources/$MANIFEST_FILE" "$APP_BUILD_DIR/app.manifest"

# Update configuration files with build variables
sed -i.bak -e "s/@app_id@/${APP_NAME}_${PLATFORM}/" "$DIST_BIN_BUILD_DIR/python"
sed -i.bak -e "s/@version_dir@/${VERSION//./_}/" "$DIST_BIN_BUILD_DIR/python"
sed -i.bak -e "s/@app_id@/${APP_NAME}_${PLATFORM}/" "$APP_BUILD_DIR/default/app.conf"
sed -i.bak -e "s/@version@/$VERSION/" "$APP_BUILD_DIR/default/app.conf"
sed -i.bak -e "s/@build@/$BUILD/" "$APP_BUILD_DIR/default/app.conf"
sed -i.bak -e "s/@app_id@/${APP_NAME}_${PLATFORM}/" "$APP_BUILD_DIR/app.manifest"
sed -i.bak -e "s/@version@/$VERSION/" "$APP_BUILD_DIR/app.manifest"
sed -i.bak -e "s/@build@/${APP_NAME}_${PLATFORM}/" -e 's|\\|/|g' "$APP_BUILD_DIR/default/inputs.conf"

# Clean up backup files created by sed
rm -f "$APP_BUILD_DIR/default/app.conf.bak"
rm -f "$APP_BUILD_DIR/app.manifest.bak"
rm -f "$APP_BUILD_DIR/default/inputs.conf.bak"
rm -f "$DIST_BIN_BUILD_DIR/python.bak"

# Build distribution manifest
echo "[INFO] Building distribution manifest"
(cd "$DIST_BUILD_DIR" && find . -type f,d,l | sed 's/^\.\///g' > "$DIST_BUILD_DIR/build.manifest")

echo "[INFO] Build Success"