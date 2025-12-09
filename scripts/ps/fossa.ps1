$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/fossas/fossa-cli/master/install-latest.ps1'))
if (-Not $env:CI) {
    & fossa analyze --only-target "conda" --only-path $PLATFORM --debug --team "FOSSA Sandbox" --title "PSC Test"
} else {
    $script:PROJECT_TITLE = "Python for Scientific Computing ${PLATFORM}"
    $script:PROJECT_NAME = "${env:CI_PROJECT_URL}/-/tree/${env:CI_COMMIT_REF_NAME}/${PLATFORM}"
    Write-Output "Setting SecurityProtocol to Tls12"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Write-Output "Running FOSSA Analyze"
    Invoke-WebRequest https://app.fossa.com/ -UseBasicParsing
    & fossa analyze --only-target "conda" --only-path $PLATFORM -p $PROJECT_NAME -b ${env:CI_COMMIT_REF_NAME} --title $PROJECT_TITLE --team "${env:CI_PROJECT_URL}"
}
