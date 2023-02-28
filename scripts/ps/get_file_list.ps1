Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DIR_NAME
)

$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

(Get-ChildItem -File -Recurse $DIR_NAME).FullName.Replace("${PROJECT_DIR}\",'')