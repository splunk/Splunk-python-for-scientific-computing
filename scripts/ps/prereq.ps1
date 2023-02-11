$ErrorActionPreference = "Stop"

$APP_NAME = "Splunk_SA_Scientific_Python"
$PROJECT_DIR = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$OS = "Windows"
$ARCH = "x86_64"
$PLATFORM = "${OS}_${ARCH}".ToLower()
$PLATFORM_DIR = Join-Path $PROJECT_DIR $PLATFORM
$BASE_BUILD_DIR = Join-Path $PROJECT_DIR "build"
$MINICONDA_BUILD_DIR = Join-Path $BASE_BUILD_DIR "miniconda"
$VENV_BUILD_DIR = Join-Path $BASE_BUILD_DIR "venv"
$APP_BUILD_DIR = Join-Path $BASE_BUILD_DIR "${APP_NAME}_${PLATFORM}"
$DIST_BUILD_DIR = Join-Path $APP_BUILD_DIR (Join-Path "bin" $PLATFORM)
$PACK_FILE_PATH = Join-Path $BASE_BUILD_DIR "miniconda-repack.tar.gz"
$CONDA = Join-Path $MINICONDA_BUILD_DIR "bin\conda"