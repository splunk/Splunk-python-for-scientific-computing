$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

New-Item $MICROMAMBA_BUILD_DIR -ItemType Directory
New-Item $VENV_BUILD_DIR -ItemType Directory

Invoke-Webrequest -URI https://micro.mamba.pm/api/micromamba/win-64/latest -OutFile $(Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar.bz2")
7z x -o"$MICROMAMBA_BUILD_DIR" $(Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar.bz2")
7z x -o"$MICROMAMBA_BUILD_DIR" $(Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar")
