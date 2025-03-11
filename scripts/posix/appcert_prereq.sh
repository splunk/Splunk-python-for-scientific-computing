#!/bin/bash

APP_NAME=$1
OS="$(uname)"
ARCH="$(uname -m)"
echo $APP_NAME

PLATFORM="$(echo "${OS}_$ARCH" | tr '[:upper:]' '[:lower:]')"
PROJECT_DIR=$(cd "$(dirname $(dirname $(dirname "${BASH_SOURCE[0]}")))" && pwd)
BASE_BUILD_DIR="$PROJECT_DIR/build"


echo "The project dir is $PROJECT_DIR"

BUILD_ARTIFACT_FOLDER="${BASE_BUILD_DIR}/${APP_NAME}"
BUILD_ARTIFACT_TARBALL_PATH="${BUILD_ARTIFACT_FOLDER}.tgz"
APP_CERT_ARTIFACT_PATH="${BUILD_ARTIFACT_FOLDER}-APP_CERT"

echo "The path to the build artifact folder is ${BUILD_ARTIFACT_FOLDER}"
echo "The path to the build artifact tarball is ${BUILD_ARTIFACT_TARBALL_PATH}"


mkdir "$PROJECT_DIR/app_cert/"

echo "Extracting module from tarball..."
tar -xzf "${BUILD_ARTIFACT_TARBALL_PATH}" -C "$PROJECT_DIR/app_cert/"


cd "${PROJECT_DIR}/app_cert/${APP_NAME}"

echo "Removing lib folders..."

#removing lib folders
if [[ "$APP_NAME" == "Splunk_SA_Scientific_Python_windows_x86_64" ]]; then
    echo "Windows x86_64 artifact so Removing Library and Lib folders"
    rm -rf ./bin/*/Library
    rm -rf ./bin/*/Lib
else
    echo "Not a Windows x86_64 artifact so Removing lib folder"
    rm -rf ./bin/*/*/lib
fi

#remove .DS_Store
echo "Removing .DS_Store files..."
find . -type f \( -name ".DS_Store*" \) | while read -r FILE; do
    echo "Removing file: $FILE"
    rm -f "$FILE" 
done

#remove __MACOSX directories
echo "Removing directories that start with __MACOSX"
find . -type d \( -name "__MACOSX*" \) | while read -r FOLDER; do
    echo "Removing file: $FOLDER"
    rm -rf "$FOLDER" 
done


#rename files having dot at beginning
echo "Renaming files with period at beginning of filename..."
find . -type f -name ".*" | while read -r FILE; do
    
    DIR=$(dirname "$FILE")
    BASENAME=$(basename "$FILE")
    NEW_NAME="${BASENAME:1}"
    mv "$FILE" "$DIR/$NEW_NAME"
    echo "Renaming file: $FILE -> $DIR/$NEW_NAME"
    
done

#only for windows artifact
if [[ "$APP_NAME" == "Splunk_SA_Scientific_Python_windows_x86_64" ]]; then
    chmod u+x "${PROJECT_DIR}/app_cert/${APP_NAME}"
    
    # To pass App Inspect Checks
    chmod 644 "${PROJECT_DIR}/app_cert/${APP_NAME}/default/app.conf";
    chmod 644 "${PROJECT_DIR}/app_cert/${APP_NAME}/default/authorize.conf";
    chmod 644 "${PROJECT_DIR}/app_cert/${APP_NAME}/default/commands.conf";
    chmod 644 "${PROJECT_DIR}/app_cert/${APP_NAME}/default/distsearch.conf";
    chmod 644 "${PROJECT_DIR}/app_cert/${APP_NAME}/README"
    chmod 644 "${PROJECT_DIR}/app_cert/${APP_NAME}/app.manifest"
    
    #renaming file because previous operation in the above sections were unable to rename this file
    #PATH_TO_GITHUB_FILE="./bin/windows_x86_64/etc/conda/test-files/referencing/1/suite/.github"
    mv "./bin/windows_x86_64/etc/conda/test-files/referencing/1/suite/.github" "./bin/windows_x86_64/etc/conda/test-files/referencing/1/suite/github" || echo ".github file does not exist";
    
fi 
