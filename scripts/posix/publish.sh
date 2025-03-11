SUB_FOLDER_NAME=$1
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"
echo "The SUB_FOLDER_NAME variable is ${SUB_FOLDER_NAME}"
set -o xtrace

is_set BUILD
is_set VERSION

if [[ -z "$CI" ]]; then
  eval "$(okta-artifactory-login -t generic --eval)"
else
  is_set ARTIFACTORY_AUTHORIZATION
fi

REPO=${REPO:-"generic-test"}
REPO_URL="${ARTIFACTORY_BASE_URL}/${REPO}"
TARGET_FOLDER_PREFIX="apps/app-sasp"
BUILD_HASH=$(git rev-parse --short HEAD)
if [[ -z "$CI" ]]; then
    # LOCAL
    TARGET_FOLDER="user-${USER}/${TARGET_FOLDER_PREFIX}/${BUILD_HASH}"
else
  if [[ -n "$CI_COMMIT_TAG" ]]; then
    # RELEASE TAG
    if [[ "$SUB_FOLDER_NAME" ==  "releases" ]]; then
      TARGET_FOLDER="${TARGET_FOLDER_PREFIX}/releases/${VERSION%.*}.x/$VERSION"
    else
      TARGET_FOLDER="${TARGET_FOLDER_PREFIX}/release"
    fi  
  elif [[ "$CI_PIPELINE_SOURCE" == "merge_request_event" ]]; then
    # MERGE REQUEST
    if [[ -z "$CI_MERGE_REQUEST_IID" || "$CI_MERGE_REQUEST_IID" == " " ]]; then
      echo "Merge Request ID is empty : $CI_MERGE_REQUEST_IID"
      echo "[ERROR] Publish only master branch, merge_requests and tags, tag needs to match build script version too"
      exit 1
    fi
    TARGET_FOLDER="${TARGET_FOLDER_PREFIX}/builds/merge_requests/MR$CI_MERGE_REQUEST_IID"
  elif [[ "$CI_COMMIT_BRANCH" == "$CI_DEFAULT_BRANCH" ]] || [[ "$CI_COMMIT_REF_PROTECTED" == "true" ]]; then
    # MASTER BRANCH
    TARGET_FOLDER="${TARGET_FOLDER_PREFIX}/builds"
  else
    echo "No publishing condition met, exiting"
    exit 1
  fi
fi

for PLATFORM in "linux_x86_64" "darwin_x86_64" "darwin_arm64" "windows_x86_64"
do
  APP_PLATFORM="${APP_NAME}_${PLATFORM}"
  if [ -f "$BASE_BUILD_DIR/${APP_PLATFORM}.tgz" ]; then
    echo "publishing ${APP_PLATFORM} to ${REPO_URL}/${TARGET_FOLDER}"
    curl -u ${ARTIFACTORY_AUTHORIZATION} -X PUT "${REPO_URL}/${TARGET_FOLDER}/${APP_PLATFORM}.tgz" -T "$BASE_BUILD_DIR/${APP_PLATFORM}.tgz"
  else
    echo "${APP_PLATFORM} build not found"
  fi
done
