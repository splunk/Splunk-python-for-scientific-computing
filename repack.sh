#!/bin/bash
set -e

APPDIR="Splunk_SA_Scientific_Python"
VERSION="2.0.1"
APPBUILD="`git rev-parse --short HEAD`${BUILD_NUMBER:+.$BUILD_NUMBER}"
BUILD_NUMBER=${APPBUILD:-testing}

usage() { echo "Usage: $0 {analyze|build|freeze|license|publish}" 1>&2; exit 1; }

case "$1" in
    analyze)
        echo "[INFO] Analyzing package tree"
        MODE=2
        ;;
    build)
        echo "[INFO] Building Python for Scientific Computing"
        MODE=0
        ;;
    freeze)
        echo "[INFO] Creating a locked package list"
        MODE=1
        ;;
    license)
        echo "[INFO] Generating license information"
        MODE=3
        ;;
    publish)
        echo "[INFO] Publishing builds"
        MODE=4
        ;;
    *)
        usage
        ;;
esac

# ---------------------- ENVIRONMENT DEFINITION --------------

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_BASE_DIR="$SCRIPT_DIR/build"
# See the list from https://repo.anaconda.com/miniconda/
MINICONDA_VERSION="4.7.12.1"

# Platform detection
XARGS="xargs -r"
if [ "`uname`" = "Linux" ]; then
    if [ "`uname -m`" = "x86_64" ]; then
        MINICONDA_PLATFORM="Linux"
        PLATFORM="linux_x86_64"
    else
        echo "[ERROR] Unsupported platform \"`uname`\", aborting."
        exit 1
    fi
elif [ "`uname`" = "Darwin" ]; then
    MINICONDA_PLATFORM="MacOSX"
    PLATFORM="darwin_x86_64"
    export COPYFILE_DISABLE=true
    XARGS="xargs"
else
    echo "[ERROR] This script does not support platform \"`uname`\", aborting."
    exit 1
fi

PLATFORM_DIR="$SCRIPT_DIR/$PLATFORM"
BUILD_DIR="$BUILD_BASE_DIR/$PLATFORM"

if [[ $MODE -lt 4 ]]; then
    # ----------------------- MINICONDA ----------------------------

    # Check if miniconda installer is already downloaded
    PACKAGE_LIST_FILE_PATH="$PLATFORM_DIR/packages.txt"
    MINICONDA_FILE="Miniconda3-${MINICONDA_VERSION}-${MINICONDA_PLATFORM}-x86_64.sh"
    MINICONDA_PATH="$PLATFORM_DIR/$MINICONDA_FILE"
    if ! test -f "$MINICONDA_PATH"; then
        if command -v curl; then
            curl -o "$MINICONDA_PATH" "https://repo.anaconda.com/miniconda/$MINICONDA_FILE"
        else
            echo "[ERROR] cURL not installed, can not find miniconda installation file"
            exit 1
        fi
    fi
    if [ "`uname`" = "Linux" ]; then
        LINUX_MD5="81c773ff87af5cfac79ab862942ab6b3"
        MINICONDA_MD5=$(md5sum < $MINICONDA_PATH | awk '{print $1}')
        if [ "$MINICONDA_MD5" != "$LINUX_MD5" ]; then
            echo "[ERROR] checksum of $MINICONDA_PATH is $MINICONDA_MD5, does not match $LINUX_MD5, please check file integrity"
            exit 1
        fi
    elif [ "`uname`" = "Darwin" ]; then
        OSX_MD5="621daddf9de519014c6c38e8923583b8"
        MINICONDA_MD5=$(md5 -q $MINICONDA_PATH)
        if [ "$MINICONDA_MD5" != "$OSX_MD5" ]; then
            echo "[ERROR] checksum of $MINICONDA_PATH is $MINICONDA_MD5, does not match $OSX_MD5, please check file integrity"
            exit 1
        fi
    fi
    test -f "$PACKAGE_LIST_FILE_PATH"

    # Clean up build dir
    rm -rf "$BUILD_BASE_DIR"
    mkdir -p "$BUILD_BASE_DIR"

    # Setup intermediate environment
    BUILD_CONDA_DIR="$BUILD_DIR/conda"
    CONDA="$BUILD_CONDA_DIR/bin/conda"
    PACK_TARGET="$BUILD_DIR/env"
    BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

    # Step 1: install miniconda to BUILD_CONDA_DIR
    bash "$MINICONDA_PATH" -b -p "$BUILD_CONDA_DIR"

    if [[ $MODE -eq 0 ]]; then
        # Step 2: install conda-pack to intemidiate conda env
        "$CONDA" install -y -c conda-forge conda-pack

        # Step 3: create a virtualenv and install PSC packages from the platform specific dir's packages.txt
        "$CONDA" create -p "$PACK_TARGET" -y --file "$PACKAGE_LIST_FILE_PATH"

        # Step 4: clean up the virtualenv and conda cache
        "$CONDA" remove -p "$PACK_TARGET" -y --force $BLACKLISTED_PACKAGES || true
        "$CONDA" clean -tisy

        # ----------------------- CREATE CONDA-PACK PACKAGE --------------

        # conda-repack only generates a tar file, so we untar the resulted archive
        # in place of the environment the tar was created from
        PACK_FILE_PATH="$BUILD_BASE_DIR/miniconda-repack-${PLATFORM}.tar.gz"
        "$CONDA" pack -p "$PACK_TARGET" -o "$PACK_FILE_PATH"
        rm -rf "$PACK_TARGET/*"
        rm -rf "$BUILD_CONDA_DIR"
        tar zxf "$PACK_FILE_PATH" -C "$PACK_TARGET"
        rm -f "$PACK_FILE_PATH"

        # Remove *.pyc/*.pyo
        echo "Remove *.pyc/*.pyo"
        find "$PACK_TARGET" -iname "*.pyc" -print0 | $XARGS -0 rm
        find "$PACK_TARGET" -iname "*.pyo" -print0 | $XARGS -0 rm

        find "$PACK_TARGET" -iname "*.a" -print0 | $XARGS -0 rm
        find "$PACK_TARGET" -iname "*.la" -print0 | $XARGS -0 rm

        # Remove whl files
        find "$PACK_TARGET" -iname "*.whl" -print0 | $XARGS -0 rm
        # remove all tests folders except networkx's tests folder
        PKG_INCLUDE_TESTS="$PACK_TARGET/*networkx*"
        find "$PACK_TARGET" -type d -iname tests -not -path "$PKG_INCLUDE_TESTS" -print0 | $XARGS -0 rm -rf

        # Remove other unnecessary cruft
        rm -f "$PACK_TARGET"/bin/{sqlite3,tclsh8.5,wish8.5,xmlcatalog,xmllint,xsltproc,smtpd.py,xml2-config,xslt-config,c_rehash}
        rm -f "$PACK_TARGET"/bin/{.openssl-libcrypto-fix,.openssl-post-link.sh}
        rm -rf "$PACK_TARGET"/lib/{Tk.icns,Tk.tiff,tcl8,tcl8.5,tk8.5} \
        "$PACK_TARGET"/conda-meta \
        "$PACK_TARGET"/etc \
        "$PACK_TARGET"/include \
        "$PACK_TARGET"/lib/pkgconfig \
        "$PACK_TARGET"/lib/python3.7/site-packages/scipy/weave \
        "$PACK_TARGET"/lib/xml2Conf.sh \
        "$PACK_TARGET"/lib/xsltConf.sh \
        "$PACK_TARGET"/lib/terminfo \
        "$PACK_TARGET"/share

        # Convert symlinks to copies.
        SYMLINK_SUBDIRS="bin lib"
        for subdir in $SYMLINK_SUBDIRS; do
            while read i; do
                j=`readlink "$i"`
                d=`dirname "$i"`
                b=`basename "$i"`
                bash -c "cd \"$d\"; rm -v \"$b\"; cp -v \"$j\" \"$b\""
            done < <(find "$PACK_TARGET/${subdir}" -type l)
        done

        rm -rf "$PACK_TARGET"/conda-meta
        rm -rf "$PACK_TARGET"/pkgs
        rm -rf "$PACK_TARGET"/envs

        # Mangle SSL
        if [ ! "$NO_MANGLE_SSL" ]; then
            find "$PACK_TARGET" -type f -iname "*crypto*" -print0 | $XARGS -0 rm -rfv
            find "$PACK_TARGET" -type f -iname "*ssl*" -print0 | $XARGS -0 rm -rfv
            rm -rfv "$PACK_TARGET"/lib/engines
            rm -rfv "$PACK_TARGET"/ssl
            rm -rfv "$PACK_TARGET/lib/python3.7/site-packages/Crypto"
        fi

        TARGET="$BUILD_BASE_DIR/${APPDIR}_${PLATFORM}"

        rm -rf "$TARGET"
        rsync -xva "$SCRIPT_DIR/package/" "$TARGET"
        rsync -xva "$SCRIPT_DIR/${PLATFORM}/LICENSE" "$TARGET/LICENSE"

        ## Update conf files
        sed -i.bak -e "s/@build@/$APPBUILD/" "$TARGET/default/app.conf"
        sed -i.bak -e "s/@version@/$VERSION/" "$TARGET/default/app.conf"
        sed -i.bak -e "s/@platform@/$PLATFORM/" "$TARGET/default/app.conf"
        rm -f "$TARGET/default/app.conf.bak"

        mkdir -p "$TARGET/bin"
        mv "$PACK_TARGET" "$TARGET/bin/$PLATFORM"
        rm -rf "$BUILD_DIR"
        tar czf "${TARGET}.tgz" -C "$BUILD_BASE_DIR" "${APPDIR}_${PLATFORM}"
        echo "[INFO] Build Success"
    elif [[ $MODE -eq 1 ]]; then
        "$CONDA" create -p "$PACK_TARGET" -y --file "$SCRIPT_DIR/packages.txt"
        "$CONDA" remove -p "$PACK_TARGET" -y --force $BLACKLISTED_PACKAGES || true
        "$CONDA" list -p "$PACK_TARGET" -e > "$PACKAGE_LIST_FILE_PATH"
        git diff "$PACKAGE_LIST_FILE_PATH"
    elif [[ $MODE -eq 2 ]]; then
        # Install conda-tree to inspect package dependencies
        "$CONDA" install -c conda-forge -y conda-tree
        "$CONDA" create -p "$PACK_TARGET" -y --file "$SCRIPT_DIR/packages.txt"
        "$BUILD_CONDA_DIR/bin/conda-tree" -p "$PACK_TARGET" deptree
    elif [[ $MODE -eq 3 ]]; then
        "$CONDA" create -p "$PACK_TARGET" -y --file "$PACKAGE_LIST_FILE_PATH"
        "$CONDA" remove -p "$PACK_TARGET" -y --force $BLACKLISTED_PACKAGES
        LICENSE_DB="$(tail -n +2 "$SCRIPT_DIR/license_db.csv")"
        LICENSE_PKG_NAMES=()
        LICENSE_TYPES=()
        LICENSE_URLS=()
        while IFS=',' read -r -a line; do
            if [[ ${line:0:1} != "#" ]]; then
                LICENSE_PKG_NAMES+=("${line[0]}")
                LICENSE_TYPES+=("${line[1]}")
                LICENSE_URLS+=("${line[2]}")
            fi
        done < <(cat "$SCRIPT_DIR/license_db.csv")
        PKG_INSTALLED=()
        while IFS="\n" read -r line
        do
            if [[ ${line:0:1} != "#" ]]; then
                PKG_NAME=$(echo $line | cut -f1 -d " ")
                PKG_INSTALLED+=($PKG_NAME)
                if [[ ! " ${LICENSE_PKG_NAMES[@]} " =~ " ${PKG_NAME} " ]]; then
                    echo "$PKG_NAME does not have a record in license_db.csv, please update license_db.csv"
                    exit 1
                fi
            fi
        done < <("$CONDA" list -p "$PACK_TARGET")

        cp "$SCRIPT_DIR/LICENSE" "$SCRIPT_DIR/$PLATFORM/LICENSE"
        echo -e "\n\n========================================================================\n" >> "$SCRIPT_DIR/$PLATFORM/LICENSE"
        echo -e "Package licenses:\n" >> "$SCRIPT_DIR/$PLATFORM/LICENSE"
        echo -e "\nPackage licenses:\n"
        for j in "${PKG_INSTALLED[@]}"
        do
            for i in "${!LICENSE_PKG_NAMES[@]}"; do
                if [[ "$j" == "${LICENSE_PKG_NAMES[$i]}" ]]; then
                    LINE_OUTPUT="$(printf "%-16s %-36s %s\n" "${LICENSE_PKG_NAMES[$i]}" "${LICENSE_TYPES[$i]}" "${LICENSE_URLS[$i]}")"
                    echo "$LINE_OUTPUT" >> "$SCRIPT_DIR/$PLATFORM/LICENSE"
                    echo "$LINE_OUTPUT"
                fi
            done
        done
        echo -e "\n[INFO] License file $SCRIPT_DIR/$PLATFORM/LICENSE updated"
    fi
elif [[ $MODE -eq 4 ]]; then
    if [[ -z "${CI}" ]]; then
        echo "[WARNING] Tsk tsk tsk, not on CI, you're on your own"
    else
        if [[ -z "${ARTIFACTORY_TARGET}" ]]; then
            echo "Please set ARTIFACTORY_TARGET"
            exit 1
        fi
        if [[ "${CI_COMMIT_REF_NAME}" == "master" ]]; then
            # publish master
            TARGET_FOLDER="${ARTIFACTORY_TARGET}/builds/master"
            jfrog rt u "build/*.tgz" "${TARGET_FOLDER}/${BUILD_NUMBER}/" --build-name "PSC_master" --build-number ${CI_PIPELINE_IID} --fail-no-op
            jfrog rt u "build/*.tgz" "${TARGET_FOLDER}/latest/" --sync-deletes="${TARGET_FOLDER}/latest/" --quiet --fail-no-op
            jfrog rt bdi "PSC_master" --max-builds=10
            echo "Builds are available at:"
            echo "${ARTIFACTORY_URL}/${TARGET_FOLDER}/${BUILD_NUMBER}"
            echo "${ARTIFACTORY_URL}/${TARGET_FOLDER}/latest"
        elif [[ "${CI_COMMIT_REF_NAME}" == "v${VERSION}" || "${CI_COMMIT_REF_NAME}" == "release/${VERSION}" ]]; then
            # publish the tag
            ver=${VERSION}
            TARGET_FOLDER="${ARTIFACTORY_TARGET}/releases/${ver%.*}.x/${VERSION}"
            jfrog rt u "build/*.tgz" "${TARGET_FOLDER}/" --sync-deletes="${TARGET_FOLDER}/Splunk_SA_Scientific_Python_*.tgz" --quiet --fail-no-op
            jfrog rt u "build/*.tgz" "${TARGET_FOLDER}/${BUILD_NUMBER}/" --fail-no-op
            echo "Builds are available at:"
            echo "${ARTIFACTORY_URL}/${TARGET_FOLDER}"
        else
            echo "[ERROR] Publish only master branch and tags, tag needs to match build script version too"
        fi
    fi
fi
