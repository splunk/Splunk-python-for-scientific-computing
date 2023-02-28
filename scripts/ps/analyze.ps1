$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"

# remove pip and certifi from final build because we don't need them
# but we need them in `windows_x86_64/environment.yml` file for fossa to work
& conda remove -p $VENV_BUILD_DIR -y --force pip certifi

& conda-tree -p $VENV_BUILD_DIR deptree