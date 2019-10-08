# Stop on any error
$ErrorActionPreference = "Stop"

$script:MINICONDA_VERSION = "Miniconda3-4.5.12"

$script:SCRIPT_DIR = $PWD.Path
$script:PLATFORM = "windows_x86_64"
$script:MINICONDA_FILE = "$MINICONDA_VERSION-Windows-x86_64.exe"
$script:PLATFORM_DIR = Join-Path $SCRIPT_DIR $PLATFORM
$script:MINICONDA_PATH = Join-Path $PLATFORM_DIR $MINICONDA_FILE
$script:PACKAGE_LIST_FILE_PATH = Join-Path "$PLATFORM_DIR" "packages.txt"
$script:BUILD_DIR = Join-Path "$SCRIPT_DIR" "build"
$script:CONDA_ENV_PATH = Join-Path "$BUILD_DIR" "conda_env"
$script:PSC_ENV_PATH = Join-Path "$BUILD_DIR" "psc_env"
$script:PACK_TAR_FILE_PATH= Join-Path "$BUILD_DIR" "miniconda-repack-${PLATFORM}.tar"
$script:PACK_FILE_PATH= Join-Path "$BUILD_DIR" "miniconda-repack-${PLATFORM}.tar.gz"
$script:7Z = "C:\Program Files\7-Zip\7z.exe"

if(-Not (Test-Path $MINICONDA_PATH)) {
    throw "$MINICONDA_PATH path not found"
}

if (Test-Path -Path "$BUILD_DIR") {
    Write-Output "Cleaning build directory"
    # Work around long file names/paths
    Cmd /C "rmdir /S /Q $BUILD_DIR"
}
New-Item -Path "$BUILD_DIR" -ItemType "Directory"

Write-Output "Installing $MINICONDA_PATH in $CONDA_ENV_PATH"
Start-Process -FilePath "$MINICONDA_PATH" -ArgumentList "/S /InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /D=$CONDA_ENV_PATH" -NoNewWindow -Wait

Write-Output "Adding Python to path"
$env:Path += ";$($CONDA_ENV_PATH);$(Join-Path $CONDA_ENV_PATH "Scripts");$(Join-Path $CONDA_ENV_PATH "Library\bin")"

$script:CONDA = Join-Path "$CONDA_ENV_PATH" "Scripts\conda.exe"
& "$CONDA" install -y -c conda-forge conda-pack

Write-Output "Creating PSC conda environment in $PSC_ENV_PATH and installing packages"
& "$CONDA" create -y -v -p "$PSC_ENV_PATH" --file "$PACKAGE_LIST_FILE_PATH"

Write-Output "Packing PSC conda environment: $PSC_ENV_PATH and saving as: $PACK_FILE_PATH"
# # Pack PSC directory into a conda pack and then untar it in place of the PSC directory
& "$CONDA" pack -p "$PSC_ENV_PATH" -o "$PACK_FILE_PATH"

# Creating the tarball of miniconda packages
& "$7Z" a "$PACK_TAR_FILE_PATH" "$PSC_ENV_PATH/*"-y
& "$7Z" a "$PACK_FILE_PATH" "$PACK_TAR_FILE_PATH"-y
Remove-Item -Path "$PACK_TAR_FILE_PATH" -Force
Write-Output "Finishing"