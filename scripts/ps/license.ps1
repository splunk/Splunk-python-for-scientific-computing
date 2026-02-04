# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Set MICROMAMBA variable from MAMBA_EXE environment variable
$MICROMAMBA = $Env:MAMBA_EXE

# Verify MICROMAMBA is set and executable exists
if ([string]::IsNullOrEmpty($MICROMAMBA)) {
    Write-Error "MICROMAMBA variable is not set"
    exit 1
}

if (-not (Test-Path $MICROMAMBA)) {
    Write-Error "MICROMAMBA executable not found at: $MICROMAMBA"
    exit 1
}

# Verify Python executable exists
$PYTHON_EXE = Join-Path $VENV_BUILD_DIR "envs\psc\python.exe"
if (-not (Test-Path $PYTHON_EXE)) {
    Write-Error "Python executable not found at: $PYTHON_EXE"
    exit 1
}

# Verify blacklist file exists
$BLACKLIST_FILE = Join-Path $PLATFORM_DIR "blacklist.txt"

# Load blacklisted packages from file and convert to space-separated string
$script:BLACKLISTED_PACKAGES = (Get-Content $BLACKLIST_FILE) -join " "

# Set environment variables for license generation script
$env:PLATFORM = $PLATFORM
$env:MICROMAMBA = $MICROMAMBA
$env:BLACKLISTED_PACKAGES = $BLACKLISTED_PACKAGES
$env:VENV_BUILD_DIR = Join-Path $VENV_BUILD_DIR "envs\psc"

# Display paths for verification
Write-Output "MICROMAMBA: $MICROMAMBA"
Write-Output "Python Path: $PYTHON_EXE"
Write-Output "Venv Build Dir: $($env:VENV_BUILD_DIR)"

# Run the license generation Python script
$LICENSE_SCRIPT = Join-Path $PROJECT_DIR "tools\license_mamba.py"
& $PYTHON_EXE $LICENSE_SCRIPT

Write-Output "`r`n[INFO] License file ${PLATFORM_DIR}/LICENSE updated"