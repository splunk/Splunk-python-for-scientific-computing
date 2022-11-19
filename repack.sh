#!/bin/bash
set -e

APPDIR="Splunk_SA_Scientific_Python"
VERSION="4.0.0"
APPBUILD="`git rev-parse --short HEAD`${BUILD_NUMBER:+.$BUILD_NUMBER}"
BUILD_NUMBER=${APPBUILD:-testing}

usage() { echo "Usage: $0 {analyze|build|build-dev|freeze|license|publish}" 1>&2; exit 1; }

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
    build-dev)
      echo "[INFO] Creating Build and Dev env for PSC"
      MODE=4
      ;;
    publish)
      echo "[INFO] Publishing builds"
      MODE=5
      ;;
    *)
        usage
        ;;
esac

# ---------------------- ENVIRONMENT DEFINITION --------------

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_BASE_DIR="$SCRIPT_DIR/build"
# See the list from https://repo.anaconda.com/miniconda/
MINICONDA_VERSION="py38_4.9.2"
LINUX_MD5="122c8c9beb51e124ab32a0fa6426c656"
OSX_MD5="cb40e2c1a32dccd6cdd8d5e49977a635"

# Platform detection
XARGS="xargs -r"
if [ "`uname`" = "Linux" ]; then
    if [ "`uname -m`" = "x86_64" ]; then
        MINICONDA_PLATFORM="Linux"
        PLATFORM="linux_x86_64"
        MANIFEST_FILE="app.manifest.linux"
    else
        echo "[ERROR] Unsupported platform \"`uname`\", aborting."
        exit 1
    fi
elif [ "`uname`" = "Darwin" ]; then
    MINICONDA_PLATFORM="MacOSX"
    PLATFORM="darwin_x86_64"
    MANIFEST_FILE="app.manifest.osx"
    export COPYFILE_DISABLE=true
    XARGS="xargs"
else
    echo "[ERROR] This script does not support platform \"`uname`\", aborting."
    exit 1
fi

rm -rf "$PACK_TARGET/*"
rm -rf "$BUILD_CONDA_DIR"

PLATFORM_DIR="$SCRIPT_DIR/$PLATFORM"
BUILD_DIR="$BUILD_BASE_DIR/$PLATFORM"

if [[ $MODE -lt 5 ]]; then
    # ----------------------- MINICONDA ----------------------------
    # Check if miniconda installer is already downloaded
    PACKAGE_LIST_FILE_PATH="$PLATFORM_DIR/environment.yml"
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
        MINICONDA_MD5=$(md5sum < $MINICONDA_PATH | awk '{print $1}')
        if [ "$MINICONDA_MD5" != "$LINUX_MD5" ]; then
            echo "[ERROR] checksum of $MINICONDA_PATH is $MINICONDA_MD5, does not match $LINUX_MD5, please check file integrity"
            exit 1
        fi
    elif [ "`uname`" = "Darwin" ]; then
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

    if [[ $MODE -eq 0 || $MODE -eq 4 ]]; then
        # Step 2: install conda-pack to intemidiate conda env
        "$CONDA" install -y -c conda-forge conda-pack

        "$CONDA" config --set ssl_verify no
        # Step 3: create a virtualenv and install PSC packages from the platform specific dir's packages.txt
        "$CONDA" env create --prefix "$PACK_TARGET" -f "$PACKAGE_LIST_FILE_PATH"

        # Step 4: clean up the virtualenv and conda cache
        "$CONDA" remove -p "$PACK_TARGET" -y --force $BLACKLISTED_PACKAGES || true
        "$CONDA" clean -tiy

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
        find "$PACK_TARGET" -xtype l -print0 | $XARGS -0 rm
        # remove all tests folders except networkx's tests folder
        PKG_INCLUDE_TESTS="$PACK_TARGET/*networkx*"
        find "$PACK_TARGET" -type d -iname tests -not -path "$PKG_INCLUDE_TESTS" -print0 | $XARGS -0 rm -rf

        # Remove other unnecessary cruft
        rm -f "$PACK_TARGET"/bin/{sqlite3,tclsh8.5,wish8.5,xmlcatalog,xmllint,xsltproc,smtpd.py,xml2-config,xslt-config,c_rehash}
        if [[ $MODE -eq 0 ]]; then
          rm -rf "$PACK_TARGET"/lib/{Tk.icns,Tk.tiff,tcl8,tcl8.5,tk8.5} \
          "$PACK_TARGET"/conda-meta \
          "$PACK_TARGET"/etc \
          "$PACK_TARGET"/include \
          "$PACK_TARGET"/lib/pkgconfig \
          "$PACK_TARGET"/lib/python3.8/site-packages/scipy/weave \
          "$PACK_TARGET"/lib/xml2Conf.sh \
          "$PACK_TARGET"/lib/xsltConf.sh \
          "$PACK_TARGET"/lib/terminfo \
          "$PACK_TARGET"/share \
          "$PACK_TARGET"/bin/.scikit-learn-post-link.sh
        fi

        # Convert symlinks to copies.
        SYMLINK_SUBDIRS="bin lib"
        for subdir in $SYMLINK_SUBDIRS; do
            while read i; do
                j=`readlink "$i"`
                d=`dirname "$i"`
                b=`basename "$i"`
                bash -c "cd \"$d\"; rm -v \"$b\"; cp -r -v \"$j\" \"$b\""
            done < <(find "$PACK_TARGET/${subdir}" -type l)
        done
        if [[ $MODE -eq 0 ]]; then
          rm -rf "$PACK_TARGET"/conda-meta
          rm -rf "$PACK_TARGET"/pkgs
          rm -rf "$PACK_TARGET"/envs
        fi

        TARGET="$BUILD_BASE_DIR/${APPDIR}_${PLATFORM}"

        rm -rf "$TARGET"
        rsync -xva "$SCRIPT_DIR/package/" "$TARGET"
        rsync -xva "$SCRIPT_DIR/${PLATFORM}/LICENSE" "$TARGET/LICENSE"
        rsync -xva "$SCRIPT_DIR/resources/${MANIFEST_FILE}" "${TARGET}/app.manifest"

        ## Update conf files
        sed -i.bak -e "s/@build@/$APPBUILD/" "$TARGET/default/app.conf"
        sed -i.bak -e "s/@version@/$VERSION/" "$TARGET/default/app.conf"
        sed -i.bak -e "s/@platform@/$PLATFORM/" "$TARGET/default/app.conf"
        sed -i.bak -e "s/@version@/$VERSION/" "$TARGET/app.manifest"
        rm -f "$TARGET/default/app.conf.bak"
        rm -f "$TARGET/app.manifest.bak"

        mkdir -p "$TARGET/bin"
        mv "$PACK_TARGET" "$TARGET/bin/$PLATFORM"
        rm -rf "$BUILD_DIR"
        tar czf "${TARGET}.tgz" -C "$BUILD_BASE_DIR" "${APPDIR}_${PLATFORM}"
        echo "[INFO] Build Success"
    elif [[ $MODE -eq 1 ]]; then
        "$CONDA" env create --prefix "$PACK_TARGET" -f "$SCRIPT_DIR/environment.nix.yml"
        "$CONDA" remove -p "$PACK_TARGET" -y --force $BLACKLISTED_PACKAGES || true
        # "$CONDA" list -p "$PACK_TARGET" -e > "$PLATFORM_DIR/requirements.txt" || true # we don't need this anymore
        "$CONDA" env export -p "$PACK_TARGET" > "$PACKAGE_LIST_FILE_PATH"
        #sed -i '' -e '$ d' "$PACKAGE_LIST_FILE_PATH"
        git diff "$PACKAGE_LIST_FILE_PATH"
    elif [[ $MODE -eq 2 ]]; then
        "$CONDA" update -y conda
        # Install conda-tree to inspect package dependencies
        "$CONDA" install -c conda-forge -y conda-tree conda
        "$CONDA" env create --prefix "$PACK_TARGET" -f "$SCRIPT_DIR/environment.nix.yml"
        "$BUILD_CONDA_DIR/bin/conda-tree" -p "$PACK_TARGET" deptree
        "$CONDA" remove -p "$PACK_TARGET" -y --force $BLACKLISTED_PACKAGES || true
        # FOSSA analyze
        source "$BUILD_CONDA_DIR/etc/profile.d/conda.sh"
        conda activate "$PACK_TARGET"
        if ! command -v fossa &> /dev/null
        then
          curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/fossas/fossa-cli/master/install-latest.sh | bash
        fi
        fossa analyze -c fossa/.fossa.yml --team "FOSSA Sandbox"
    elif [[ $MODE -eq 3 ]]; then
        "$CONDA" env create --prefix "$PACK_TARGET" -f "$PACKAGE_LIST_FILE_PATH"
        "$CONDA" install --prefix "$PACK_TARGET" -c conda-forge -y conda
        PLATFORM="$PLATFORM" BLACKLISTED_PACKAGES="$BLACKLISTED_PACKAGES" PACK_TARGET="$PACK_TARGET" "$PACK_TARGET/bin/python" "$SCRIPT_DIR/tools/license.py"
        echo -e "\n[INFO] License file $SCRIPT_DIR/$PLATFORM/LICENSE updated"
    fi
elif [[ $MODE -eq 5 ]]; then
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
            if [[ -z "$CI_MERGE_REQUEST_IID" || "$CI_MERGE_REQUEST_IID" == " " ]]; then
              echo "Merge Request ID is empty : $CI_MERGE_REQUEST_IID"
              echo "[ERROR] Publish only master branch, merge_requests and tags, tag needs to match build script version too"
            else
              TARGET_FOLDER="${ARTIFACTORY_TARGET}/builds/merge_requests/MR${CI_MERGE_REQUEST_IID}"
              jfrog rt u "build/*.tgz" "${TARGET_FOLDER}/" --sync-deletes="${TARGET_FOLDER}/Splunk_SA_Scientific_Python_*.tgz" --quiet --fail-no-op
              echo "Builds are available at:"
              echo "${ARTIFACTORY_URL}/${TARGET_FOLDER}"
            fi
        fi
    fi
fi
