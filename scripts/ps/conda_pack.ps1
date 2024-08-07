$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

Remove-Item $PACK_FILE_PATH -ErrorAction Ignore
Write-Output "Packing PSC conda environment: $VENV_BUILD_DIR and saving as: $PACK_FILE_PATH"
# Pack PSC directory into a conda pack and then untar it in place of the PSC directory

(& $Env:MAMBA_EXE 'shell' 'hook' -s 'powershell' -p $Env:MAMBA_ROOT_PREFIX) | Out-String | Invoke-Expression
& $Env:MAMBA_EXE run -n tools conda-pack -p "$VENV_BUILD_DIR\envs\psc" -o "$PACK_FILE_PATH"