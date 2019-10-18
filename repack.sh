#!/bin/bash

set -ex

source ./common.sh

set_base_variables

ENV_DIR="$BUILD_DIR/env"
PACKAGE_LIST_FILE_PATH="$PLATFORM_DIR/packages.txt"

PACK_FILE_PATH="$SCRIPT_DIR/build/miniconda-repack-${PLATFORM}.tar.gz"
test -f "$PACKAGE_LIST_FILE_PATH"

rm -rf "$BUILD_BASE_DIR"
rm -f $PACK_FILE_PATH
mkdir -p "$SCRIPT_DIR/build"

bash "$MINICONDA_PATH" -b -p "$CONDA_DIR"
CONDA="$CONDA_DIR/bin/conda"
"$CONDA" install -y -c conda-forge conda-pack
"$CONDA" create -y -v -p "$ENV_DIR" --file "$PACKAGE_LIST_FILE_PATH"

"$CONDA" uninstall -y --force -p "$ENV_DIR" readline tk sqlite || true
"$CONDA" clean -tisy

# conda-repack only generates a tar file, so we untar the resulted archive
# in place of the environment the tar was created from
"$CONDA" pack -p "$ENV_DIR" -o "$PACK_FILE_PATH"
rm -rf "$ENV_DIR/*"
tar zxf "$PACK_FILE_PATH" -C "$ENV_DIR" || true

# Remove *.pyc/*.pyo
echo "Remove *.pyc/*.pyo"
find "$ENV_DIR" -iname "*.pyc" -print0 | $XARGS -0 rm
find "$ENV_DIR" -iname "*.pyo" -print0 | $XARGS -0 rm

find "$ENV_DIR" -iname "*.a" -print0 | $XARGS -0 rm
find "$ENV_DIR" -iname "*.la" -print0 | $XARGS -0 rm

# remove all tests folders except networkx's tests folder
PKG_INCLUDE_TESTS="$ENV_DIR/*networkx*"
find "$ENV_DIR" -type d -iname tests -not -path "$PKG_INCLUDE_TESTS" -print0 | $XARGS -0 rm -rf

# Remove other unnecessary cruft
rm -f "$ENV_DIR"/bin/{sqlite3,tclsh8.5,wish8.5,xmlcatalog,xmllint,xsltproc,smtpd.py,xml2-config,xslt-config,c_rehash}
rm -f "$ENV_DIR"/bin/{.openssl-libcrypto-fix,.openssl-post-link.sh}
rm -rf "$ENV_DIR"/lib/{Tk.icns,Tk.tiff,tcl8,tcl8.5,tk8.5} \
"$ENV_DIR"/conda-meta \
"$ENV_DIR"/etc \
"$ENV_DIR"/include \
"$ENV_DIR"/lib/pkgconfig \
"$ENV_DIR"/lib/python3.7/site-packages/scipy/weave \
"$ENV_DIR"/lib/xml2Conf.sh \
"$ENV_DIR"/lib/xsltConf.sh \
"$ENV_DIR"/lib/terminfo \
"$ENV_DIR"/share

# Convert symlinks to copies.
SYMLINK_SUBDIRS="bin lib"
for subdir in $SYMLINK_SUBDIRS; do
    while read i; do
        j=`readlink "$i"`
        d=`dirname "$i"`
        b=`basename "$i"`
        bash -c "cd \"$d\"; rm -v \"$b\"; cp -v \"$j\" \"$b\""
    done < <(find "$ENV_DIR/${subdir}" -type l)
done

# Apply patches
if [ "$PLATFORM" = "windows_x86_64" ]; then
    D="Lib"
else
    D="lib/python3.7"
fi

rm -rf "$ENV_DIR"/conda-meta
rm -rf "$ENV_DIR"/pkgs
rm -rf "$ENV_DIR"/envs

# Mangle SSL
if [ ! "$NO_MANGLE_SSL" ]; then
    find "$ENV_DIR" -type f -iname "*crypto*" -print0 | $XARGS -0 rm -rfv
    find "$ENV_DIR" -type f -iname "*ssl*" -print0 | $XARGS -0 rm -rfv
    rm -rfv "$ENV_DIR"/lib/engines
    rm -rfv "$ENV_DIR"/ssl
    rm -rfv "$ENV_DIR/$D/site-packages/Crypto"
fi

tar czf "$SCRIPT_DIR/build/miniconda-repack-${PLATFORM}.tar.gz" -C "$ENV_DIR" .
echo "$SCRIPT_DIR/build/miniconda-repack-${PLATFORM}.tar.gz"
