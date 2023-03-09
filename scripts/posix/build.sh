SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

is_set BUILD
is_set VERSION

echo "-----------------"
echo "Building PSC $VERSION build $BUILD"
echo "-----------------"

if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
  XARGS="xargs -r"
  MANIFEST_FILE="app.manifest.linux"
elif [ "$OS" = "Darwin" ]; then
  XARGS="xargs"
  MANIFEST_FILE="app.manifest.osx"
  export COPYFILE_DISABLE=true
else
  echo "[ERROR] This script does not support platform \"`uname`\", aborting."
  exit 1
fi

rm -rf "$APP_BUILD_DIR"
DIST_VERSION_BUILD_DIR="$DIST_BUILD_DIR/${VERSION//./_}"
DIST_BIN_BUILD_DIR="$DIST_BUILD_DIR/bin"
mkdir -p "$DIST_VERSION_BUILD_DIR"
mkdir -p "$DIST_BIN_BUILD_DIR"
echo "[INFO] extracting conda-pack archive"
tar zxf "$PACK_FILE_PATH" -C "$DIST_VERSION_BUILD_DIR"

echo "[INFO] cleaning extracted archive"
# Remove *.pyc/*.pyo
find "$DIST_VERSION_BUILD_DIR" -iname "__pycache__" -print0 | $XARGS -0 rm -r
find "$DIST_VERSION_BUILD_DIR" -iname "*.pyc" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -iname "*.pyo" -print0 | $XARGS -0 rm

find "$DIST_VERSION_BUILD_DIR" -iname "*.a" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -iname "*.la" -print0 | $XARGS -0 rm

# Remove whl files
find "$DIST_VERSION_BUILD_DIR" -iname "*.whl" -print0 | $XARGS -0 rm
find "$DIST_VERSION_BUILD_DIR" -xtype l -print0 | $XARGS -0 rm
# remove all tests folders except networkx's tests folder
PKG_INCLUDE_TESTS="$DIST_VERSION_BUILD_DIR/*networkx*"
find "$DIST_VERSION_BUILD_DIR" -type d -iname tests -not -path "$PKG_INCLUDE_TESTS" -print0 | $XARGS -0 rm -rf

# Remove other unnecessary cruft
rm -f "$DIST_VERSION_BUILD_DIR"/bin/{sqlite3,tclsh8.5,wish8.5,xmlcatalog,xmllint,xsltproc,smtpd.py,xml2-config,xslt-config,c_rehash}
if [[ $MODE -eq 0 ]]; then
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

echo "[INFO] converting symlinks to copies"
# Convert symlinks to copies.
SYMLINK_SUBDIRS="bin lib"
for subdir in $SYMLINK_SUBDIRS; do
    while read i; do
        j=`readlink "$i"`
        d=`dirname "$i"`
        b=`basename "$i"`
        #echo "cd \"$d\"; rm -v \"$b\"; cp -r -v \"$j\" \"$b\""
        bash -c "cd \"$d\"; rm \"$b\"; cp -r \"$j\" \"$b\""
    done < <(find "$DIST_VERSION_BUILD_DIR/${subdir}" -type l)
done

echo "[INFO] removing unnecessary metadata"
if [[ $MODE -eq 0 ]]; then
  rm -rf "$DIST_VERSION_BUILD_DIR"/conda-meta
  rm -rf "$DIST_VERSION_BUILD_DIR"/pkgs
  rm -rf "$DIST_VERSION_BUILD_DIR"/envs
fi

echo "[INFO] building app configs"
cp -a "$PROJECT_DIR/package/." "$APP_BUILD_DIR/"
cp "$PROJECT_DIR/shims/python" "$DIST_BIN_BUILD_DIR/python"
cp -r "$PLATFORM_DIR/LICENSE" "$APP_BUILD_DIR/LICENSE"
cp "$PROJECT_DIR/resources/$MANIFEST_FILE" "$APP_BUILD_DIR/app.manifest"

# Update conf files
sed -i.bak -e "s/@app_id@/${APP_NAME}_${PLATFORM}/" "$DIST_BIN_BUILD_DIR/python"
sed -i.bak -e "s/@version_dir@/${VERSION//./_}/" "$DIST_BIN_BUILD_DIR/python"
sed -i.bak -e "s/@app_id@/${APP_NAME}_${PLATFORM}/" "$APP_BUILD_DIR/default/app.conf"
sed -i.bak -e "s/@version@/$VERSION/" "$APP_BUILD_DIR/default/app.conf"
sed -i.bak -e "s/@build@/$BUILD/" "$APP_BUILD_DIR/default/app.conf"
sed -i.bak -e "s/@app_id@/${APP_NAME}_${PLATFORM}/" "$APP_BUILD_DIR/app.manifest"
sed -i.bak -e "s/@version@/$VERSION/" "$APP_BUILD_DIR/app.manifest"
rm -f "$APP_BUILD_DIR/default/app.conf.bak"
rm -f "$APP_BUILD_DIR/app.manifest.bak"
rm -f "$DIST_BIN_BUILD_DIR/python.bak"

echo "[INFO] building distribution manifest"
(cd "$DIST_BUILD_DIR" && find . -type f,d,l | sed 's/^\.\///g' > "$DIST_BUILD_DIR/build.manifest")

echo "[INFO] Build Success"
