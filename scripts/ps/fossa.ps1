$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"

if (-Not $env:CI) {
    & fossa analyze --only-target "conda" --only-path $PLATFORM --debug --team "FOSSA Sandbox" --title "PSC Test"
} else {
    $script:PROJECT_TITLE = "Python for Scientific Computing ${PLATFORM}"
    $script:PROJECT_NAME = "${env:CI_PROJECT_URL}/-/tree/${env:CI_COMMIT_REF_NAME}/${PLATFORM}"
    & fossa analyze --only-target "conda" --only-path $PLATFORM -p $PROJECT_NAME -b ${env:CI_COMMIT_REF_NAME} --title $PROJECT_TITLE --team "${env:CI_PROJECT_URL}"
}
