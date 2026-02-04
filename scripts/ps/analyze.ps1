# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. (Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Initialize Mamba shell environment
(& $Env:MAMBA_EXE 'shell' 'hook' -s 'powershell') | Out-String | Invoke-Expression

# Generate dependency tree for the PSC environment
& $Env:MAMBA_EXE run -n tools conda-tree -p "$VENV_BUILD_DIR\envs\psc" deptree