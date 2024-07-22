SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"
ARM64="arm64"
AMD64="x86_64"

is_set ARCH
is_set FOSSA_API_KEY

# FOSSA analyze
echo $CONDA
eval "$($CONDA shell.bash hook)"
conda activate "$VENV_BUILD_DIR"
if ! command -v fossa &> /dev/null
then
  curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/fossas/fossa-cli/master/install-latest.sh | bash
fi

echo "ARCH=$ARCH, ARM64=$ARM64, PLATFORM=$PLATFORM"

if [ -z "$CI" ]; then
  if [ "$ARCH" == "$ARM64" ]; then
    echo "Found ${ARCH} build, Running fossa using Rosseta"
    arch "-$ARM64" fossa analyze --only-target "conda" --only-path $PLATFORM --team "FOSSA Sandbox" --title "PSC Test"
  else
    fossa analyze --only-target "conda" --only-path $PLATFORM --team "FOSSA Sandbox" --title "PSC Test"
  fi
  
else
  echo -e "machine cd.splunkdev.com\nlogin gitlab-ci-token\npassword ${CI_JOB_TOKEN}" > ~/.netrc
  PROJECT_TITLE="Python for Scientific Computing $PLATFORM"
  PROJECT_NAME="$CI_PROJECT_URL/-/tree/$CI_COMMIT_REF_NAME/$PLATFORM"
  if [ "$ARCH" == "$ARM64" ]; then
    echo "Found ${ARCH} build, Running fossa using Rosseta"
    arch "-$AMD64" fossa analyze --only-target "conda" --only-path $PLATFORM -p "$PROJECT_NAME" -b "${CI_COMMIT_REF_NAME}" --title "$PROJECT_TITLE" --team "$CI_PROJECT_URL"
  else
    fossa analyze --only-target "conda" --only-path $PLATFORM -p "$PROJECT_NAME" -b "${CI_COMMIT_REF_NAME}" --title "$PROJECT_TITLE" --team "$CI_PROJECT_URL"
  fi
fi
