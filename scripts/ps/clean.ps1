# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Clean up build directory and recreate it
Remove-Item -Recurse $BASE_BUILD_DIR -Force -ErrorAction Ignore
New-Item $BASE_BUILD_DIR -ItemType Directory