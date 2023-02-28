$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

Remove-Item $PACK_FILE_PATH -ErrorAction Ignore
Write-Output "Packing PSC conda environment: $VENV_BUILD_DIR and saving as: $PACK_FILE_PATH"
# Pack PSC directory into a conda pack and then untar it in place of the PSC directory
& conda pack -p "$VENV_BUILD_DIR" -o "$PACK_FILE_PATH"