$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

Remove-Item -Recurse $BASE_BUILD_DIR
New-Item $BASE_BUILD_DIR -ItemType Directory