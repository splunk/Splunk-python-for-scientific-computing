$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

if ( -not $env:ENVIRONMENT_FILE ) {
    $env:ENVIRONMENT_FILE = Join-Path $PLATFORM_DIR "environment.yml"
} else {
    $env:ENVIRONMENT_FILE = Join-Path $PROJECT_DIR $env:ENVIRONMENT_FILE
}

Remove-Item -Recurse $VENV_BUILD_DIR -Force -ErrorAction Ignore
New-Item $VENV_BUILD_DIR -ItemType Directory

$script:BLACKLISTED_PACKAGES = Get-Content $(Join-Path $PLATFORM_DIR "blacklist.txt")

Write-Output "Creating PSC virtual environment in $VENV_BUILD_DIR and installing packages"
(& $Env:MAMBA_EXE 'shell' 'hook' -s 'powershell' -p $Env:MAMBA_ROOT_PREFIX) | Out-String | Invoke-Expression
& $Env:MAMBA_EXE 'create' -n tools -y -c conda-forge conda-pack conda-tree
& $Env:MAMBA_EXE 'create' -f $env:ENVIRONMENT_FILE -y
& $Env:MAMBA_EXE 'remove' -n 'psc' -y --force @BLACKLISTED_PACKAGES
