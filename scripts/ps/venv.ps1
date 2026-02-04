# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Determine environment file path
if (-not $env:ENVIRONMENT_FILE) {
    $env:ENVIRONMENT_FILE = Join-Path $PLATFORM_DIR "environment.yml"
} else {
    $env:ENVIRONMENT_FILE = Join-Path $PROJECT_DIR $env:ENVIRONMENT_FILE
}

# Clean up existing virtual environment
Remove-Item -Recurse $VENV_BUILD_DIR -Force -ErrorAction Ignore
New-Item $VENV_BUILD_DIR -ItemType Directory

# Load blacklisted packages
$script:BLACKLISTED_PACKAGES = Get-Content $(Join-Path $PLATFORM_DIR "blacklist.txt")

Write-Output "MAMBA_EXE path: $Env:MAMBA_EXE"
Write-Output "Creating PSC virtual environment in $VENV_BUILD_DIR and installing packages"

# Initialize Mamba shell environment
(& $Env:MAMBA_EXE 'shell' 'hook' -s 'powershell') | Out-String | Invoke-Expression

& $Env:MAMBA_EXE config remove channels defaults
& $Env:MAMBA_EXE config set channel_priority strict

# Create tools environment with essential packages
& $Env:MAMBA_EXE 'create' -n tools -y -c conda-forge conda-pack conda-tree --strict-channel-priority -y

# Create PSC environment from environment file
& $Env:MAMBA_EXE 'create' -f $env:ENVIRONMENT_FILE -y  -c conda-forge --override-channels

# Remove blacklisted packages from the PSC environment
& $Env:MAMBA_EXE 'remove' -n 'psc' -y --force @BLACKLISTED_PACKAGES