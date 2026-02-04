# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Path to 7-Zip executable
$script:7Z = "C:\Program Files\7-Zip\7z.exe"

# Create compressed distribution archive
Write-Output "[INFO] creating build tarball"
& "$7Z" a "$APP_BUILD_DIR.tar" "$APP_BUILD_DIR" -y
& "$7Z" a "$APP_BUILD_DIR.tgz" "$APP_BUILD_DIR.tar" -y
Write-Output "[INFO] build tarball created"