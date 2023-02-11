$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"

& conda-tree -p $VENV_BUILD_DIR deptree