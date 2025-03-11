$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

if ( -not $env:ENVIRONMENT_FILE ) {
    $env:ENVIRONMENT_FILE = Join-Path $PLATFORM_DIR "environment.yml"
    $SOLVER="libmamba"
} else {
    $env:ENVIRONMENT_FILE = Join-Path $PROJECT_DIR $env:ENVIRONMENT_FILE
    $SOLVER="classic"
}

Remove-Item -Recurse $VENV_BUILD_DIR -Force -ErrorAction Ignore

$script:BLACKLISTED_PACKAGES = Get-Content $(Join-Path $PLATFORM_DIR "blacklist.txt")
$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"

Write-Output "Creating PSC conda environment in $VENV_BUILD_DIR and installing packages"
& conda install --prefix $VENV_BUILD_DIR -n base conda-libmamba-solver
#& conda config --prefix $VENV_BUILD_DIR --set solver libmamba
& conda env create --prefix $VENV_BUILD_DIR -f $env:ENVIRONMENT_FILE "--solver=$SOLVER"
& conda remove -p $VENV_BUILD_DIR -y --force @BLACKLISTED_PACKAGES
& conda build purge-all
