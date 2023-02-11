$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$script:BLACKLISTED_PACKAGES = Get-Content $(Join-Path $PLATFORM_DIR "blacklist.txt")
$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"

$env:PLATFORM=$PLATFORM
$env:BLACKLISTED_PACKAGES=$BLACKLISTED_PACKAGES
$env:VENV_BUILD_DIR=$VENV_BUILD_DIR
& $(Join-Path $MINICONDA_BUILD_DIR "python") $(Join-Path $PROJECT_DIR $(Join-Path "tools" "license.py"))
Write-Output "`r`n[INFO] License file ${PLATFORM_DIR}/LICENSE updated"