SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

set -o xtrace

if [[ -z "$CI" ]]; then
  eval "$(okta-artifactory-login -t generic --eval)"
else
  is_set ARTIFACTORY_AUTHORIZATION
fi

REPO=${REPO:-"generic-test"}
REPO_URL="${ARTIFACTORY_BASE_URL}/${REPO}"
TARGET_FOLDER_PREFIX="apps/app-sasp"

# TBD: To be removed after copying succeeds
echo "Copying over the artifacts from old repo to new one: For PSC and MLTK."
PSC_LINUX_ES="https://repo.splunk.com/artifactory/Solutions/Machine-Learning/app-sasp/releases/3.1.x/3.1.0/Splunk_SA_Scientific_Python_linux_x86_64.tgz"
PSC_WIN64_ES="https://repo.splunk.com/artifactory/Solutions/Machine-Learning/app-sasp/releases/3.1.x/3.1.0/Splunk_SA_Scientific_Python_windows_x86_64.tgz"
curl $PSC_LINUX_ES --create-dirs -o "$CI_PROJECT_DIR/dist/psc_linux/Splunk_SA_Scientific_Python_linux_x86_64.tgz"
curl $PSC_WIN64_ES --create-dirs -o "$CI_PROJECT_DIR/dist/psc_win64/Splunk_SA_Scientific_Python_windows_x86_64.tgz"

echo "Uploading $PSC_WIN64_ES $ARTIFACTORY_BASE_URL/$REPO/apps/app-sasp/releases/3.1.x/3.1.0/Splunk_SA_Scientific_Python_windows_x86_64.tgz"
STATUS=$(curl -u "$ARTIFACTORY_AUTHORIZATION" -X PUT --verbose "$ARTIFACTORY_BASE_URL/$REPO/apps/app-sasp/releases/3.1.x/3.1.0/Splunk_SA_Scientific_Python_windows_x86_64.tgz" -T "$CI_PROJECT_DIR/dist/psc_win64/Splunk_SA_Scientific_Python_windows_x86_64.tgz")
ERROR=$(echo "$STATUS"| { grep -b -o "error" || true; } )
if [[ ! -z "$ERROR" && "$ERROR" != " " ]]; then
  echo "Publish Failed. Errors found while making curl request: $ERROR"
  exit $PUBLISH_FAILURE_EXIT_CODE
fi

echo "Uploading $PSC_LINUX_ES to path --> $ARTIFACTORY_BASE_URL/$REPO/apps/app-sasp/releases/3.1.x/3.1.0/Splunk_SA_Scientific_Python_linux_x86_64.tgz"
STATUS=$(curl -u "$ARTIFACTORY_AUTHORIZATION" -X PUT --verbose "$ARTIFACTORY_BASE_URL/$REPO/releases/3.1.x/3.1.0/Splunk_SA_Scientific_Python_linux_x86_64.tgz" -T "$CI_PROJECT_DIR/dist/psc_linux/Splunk_SA_Scientific_Python_linux_x86_64.tgz")
ERROR=$(echo "$STATUS"| { grep -b -o "error" || true; } )
if [[ ! -z "$ERROR" && "$ERROR" != " " ]]; then
  echo "Publish Failed. Errors found while making curl request: $ERROR"
  exit $PUBLISH_FAILURE_EXIT_CODE
fi