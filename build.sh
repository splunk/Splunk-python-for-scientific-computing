#!/bin/bash

VERSION=2.0.0
APPBUILD="`git rev-parse --short HEAD`${BUILD_NUMBER:+.$BUILD_NUMBER}"
BUILD_NUMBER=${BUILD_NUMBER:-testing}

set -ex

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
    echo "No usage text yet. Here's the source code; you figure it out!"
    echo
    cat $0
    exit -1
}

run() {
    if [ "$VERBOSE" -o "$DRYRUN" ]; then echo "@ $*"; fi
    if [ ! "$DRYRUN" ]; then "$@"; fi
}

while getopts 'b:v:nh' OPTION; do
    case $OPTION in
        v) VERSION="$OPTARG" ;;
        b) BUILD_NUMBER="$OPTARG" ;;
        n) DRYRUN=1 ;;
        ?) usage ;;
    esac
done
shift $[OPTIND - 1]

if [ ! -d "$SCRIPTDIR/build" ]; then
    echo "No build directory. Run repack.sh or collect repack.sh artifacts first and put them in $SCRIPTDIR/build."
    exit 1
fi

APPDIR="Splunk_SA_Scientific_Python"
TARGETBASE="$SCRIPTDIR/build/$APPDIR"

PLATFORMS="linux_x86_64 darwin_x86_64 windows_x86_64"

for platform in $PLATFORMS; do
    TARBALL="$SCRIPTDIR/build/miniconda-repack-${platform}.tar.gz"
    if [ ! -f "$TARBALL" ]; then
        echo "$TARBALL not found, skipping $platform..."
        continue
    fi
    FOUND=1

    TARGET="$SCRIPTDIR/build/${APPDIR}_${platform}"

    run rm -rf "$TARGET"
    run rsync -xva "$SCRIPTDIR/package/" "$TARGET"

    ## Update conf files
    run sed -i.bak -e "s/@build@/$APPBUILD/" "$TARGET/default/app.conf"
    run sed -i.bak -e "s/@version@/$VERSION/" "$TARGET/default/app.conf"
    run sed -i.bak -e "s/@platform@/$platform/" "$TARGET/default/app.conf"
    run rm -f "$TARGET/default/app.conf.bak"

    run mkdir -p "$TARGET/bin/$platform"
    run tar zxf "$TARBALL" -C "$TARGET/bin/$platform" || true
    run tar czf "$SCRIPTDIR/build/${APPDIR}_${platform}.tgz" -C "$SCRIPTDIR/build" "${APPDIR}_${platform}"
done

if [ "$FOUND" != "1" ]; then
    echo "No build.sh artifacts found. Run build.sh first."
    exit 1
fi
