#!/bin/bash

set -ex


source ./common.sh

set_base_variables

ENV_DIR="$BUILD_DIR/env"
PACKAGE_LIST_FILE_PATH="$PLATFORM_DIR/packages.txt"

PACK_FILE_PATH="$SCRIPT_DIR/build/miniconda-repack-${PLATFORM}.tar.gz"
test -f "$PACKAGE_LIST_FILE_PATH"

rm -rf "$BUILD_DIR"
rm -f $PACK_FILE_PATH
mkdir -p "$SCRIPT_DIR/build"

if [ "$PLATFORM" != "windows_x86_64" ]; then
    bash "$MINICONDA_PATH" -b -p "$CONDA_DIR"
    CONDA="$CONDA_DIR/bin/conda"
    "$CONDA" install -y -c conda-forge conda-pack
    "$CONDA" create -v -p "$ENV_DIR" --file "$PACKAGE_LIST_FILE_PATH"
else
    INSTALL_PATH=`cygpath --absolute --windows "$BUILD_DIR"`
    chmod +x "$MINICONDA_PATH"
    "$MINICONDA_PATH" /S /InstallationType=JustMe /AddToPath=0 /RegisterPython=0 "/D=${TMP_PATH}" # ??? How to specify package file?
    CONDA="$BUILD_DIR/Scripts/conda.exe"
fi

# On Windows, create Microsoft.VC90.CRT.manifest file
if [ "$PLATFORM" = "windows_x86_64" ]; then
    cp -v "$PLATFORM_DIR"/Microsoft.VC90.CRT.manifest "$ENV_DIR"
    tar xjvf msvc_runtime-1.0.1-vc10_0.tar.bz2.skip -C "$ENV_DIR" --wildcards "*.dll"
    chmod +x "$ENV_DIR"/msvc*100.dll "$ENV_DIR"/Library/bin/msvc*100.dll
fi

$CONDA uninstall -y --force -p "$ENV_DIR" readline tk sqlite || true

if [ "$PLATFORM" = "windows_x86_64" ]; then
    $CONDA uninstall -y menuinst
fi

"$CONDA" clean -tisy

# conda-repack only generates a tar file, so we untar the resulted archive
# in place of the environment the tar was created from
"$CONDA" pack -p "$ENV_DIR" -o "$PACK_FILE_PATH"
rm -rf "$ENV_DIR/*"
tar zxf "$PACK_FILE_PATH" -C "$ENV_DIR" || true

# On non-Windows, convert symlinks to copies.
if [ "$PLATFORM" != "windows_x86_64" ]; then
    while read i; do
	j=`readlink "$i"`
        d=`dirname "$i"`
        b=`basename "$i"`
        bash -c "cd \"$d\"; rm -v \"$b\"; cp -v \"$j\" \"$b\""
    done < <(find "$ENV_DIR/bin" -type l)

fi

# Remove *.pyc/*.pyo
echo "Remove *.pyc/*.pyo"
find "$ENV_DIR" -iname "*.pyc" -print0 | $XARGS -0 rm
find "$ENV_DIR" -iname "*.pyo" -print0 | $XARGS -0 rm

find "$ENV_DIR" -iname "*.a" -print0 | $XARGS -0 rm
find "$ENV_DIR" -iname "*.la" -print0 | $XARGS -0 rm

# remove all tests folders except networkx's tests folder
PKG_INCLUDE_TESTS="$ENV_DIR/*networkx*"
find "$ENV_DIR" -type d -iname tests -not -path "$PKG_INCLUDE_TESTS" -print0 | $XARGS -0 rm -rf
rm -rf "$ENV_DIR"/include

 # Remove unnecessary cruft
#if [ "$PLATFORM" != "windows_x86_64" ]; then
    #rm -f "$ENV_DIR"/bin/{sqlite3,tclsh8.5,wish8.5,xmlcatalog,xmllint,xsltproc,smtpd.py,xml2-config,xslt-config,c_rehash}
    #rm -f "$ENV_DIR"/bin/{.openssl-libcrypto-fix,.openssl-post-link.sh}
    #rm -rf "$ENV_DIR"/lib/{Tk.icns,Tk.tiff,tcl8,tcl8.5,tk8.5} \
        #"$ENV_DIR"/lib/*.la \
        #"$ENV_DIR"/lib/*.a \
        #"$ENV_DIR"/lib/xml2Conf.sh \
        #"$ENV_DIR"/lib/xsltConf.sh \
        #"$ENV_DIR"/share/doc \
        #"$ENV_DIR"/share/gtk-doc \
        #"$ENV_DIR"/lib/pkgconfig \
        #"$ENV_DIR"/lib/python3.7/site-packages/scipy/weave
#fi

#if [ "$PLATFORM" = "linux_x86_64" ]; then
    #rm -f "$ENV_DIR"/lib/libcrypto.so \
        #"$ENV_DIR"/lib/libexslt.so \
        #"$ENV_DIR"/lib/libexslt.so.0.8.17 \
        #"$ENV_DIR"/lib/libffi.so \
        #"$ENV_DIR"/lib/libffi.so.6.0.1 \
        #"$ENV_DIR"/lib/libgfortran.so.3.0.0 \
        #"$ENV_DIR"/lib/libopenblas_nehalemp-r0.2.19.so \
        #"$ENV_DIR"/lib/libopenblas.so \
        #"$ENV_DIR"/lib/libpython2.7.so \
        #"$ENV_DIR"/lib/libssl.so \
        #"$ENV_DIR"/lib/libxml2.so \
        #"$ENV_DIR"/lib/libxml2.so.2.9.2 \
        #"$ENV_DIR"/lib/libxslt.so \
        #"$ENV_DIR"/lib/libxslt.so.1.1.28 \
        #"$ENV_DIR"/lib/libyaml-0.so.2.0.4 \
        #"$ENV_DIR"/lib/libyaml.so \
        #"$ENV_DIR"/lib/libz.so \
        #"$ENV_DIR"/lib/libz.so.1.2.8 \
        #"$ENV_DIR"/lib/python3.7/config/libpython2.7.a \
        #"$ENV_DIR"/lib/python3.7/site-packages/numpy/core/lib/libnpymath.a
#fi

# Apply patches
if [ "$PLATFORM" = "windows_x86_64" ]; then
    D="Lib"
else
    D="lib/python3.7"
fi

patch -d "$ENV_DIR/$D" -p2 < "$SCRIPT_DIR"/Python-win-2.7.9-disable-ssl-by-default.patch


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
