# Stop on any error
$ErrorActionPreference = "Stop"

$script:MINICONDA_VERSION = "Miniconda3-4.7.10"

$script:SCRIPT_DIR = $PWD.Path
$script:PLATFORM = "windows_x86_64"
$script:MINICONDA_FILE = "$MINICONDA_VERSION-Windows-x86_64.exe"
$script:PLATFORM_DIR = Join-Path $SCRIPT_DIR $PLATFORM
$script:MINICONDA_PATH = Join-Path $PLATFORM_DIR $MINICONDA_FILE
$script:PACKAGE_LIST_FILE_PATH = Join-Path "$PLATFORM_DIR" "packages.txt"
$script:BUILD_DIR = Join-Path "$SCRIPT_DIR" "build"
$script:CONDA_ENV_PATH = Join-Path "$BUILD_DIR" "conda_env"
$script:PSC_ENV_PATH = Join-Path "$BUILD_DIR" "psc_env"
$script:PACK_TAR_FILE_PATH = Join-Path "$BUILD_DIR" "miniconda-repack-${PLATFORM}.tar"
$script:PACK_FILE_PATH = "$PACK_TAR_FILE_PATH.gz"
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

# initialize the conda environment to use powershell
& conda init powershell
& conda install -y -c conda-forge conda-pack

Write-Output "Creating PSC conda environment in $PSC_ENV_PATH and installing packages"
& conda create -y -v -p $PSC_ENV_PATH --file $PACKAGE_LIST_FILE_PATH

Write-Output "Packing PSC conda environment: $PSC_ENV_PATH and saving as: $PACK_FILE_PATH"
# Pack PSC directory into a conda pack and then untar it in place of the PSC directory
& conda pack -p "$PSC_ENV_PATH" -o "$PACK_FILE_PATH"

# Replace PSC env directory with untarred contenct of the pack file
Cmd /C "rmdir /S /Q $PSC_ENV_PATH"
Write-Output "Unpacking the $PACK_FILE_PATH package"
& "$7z" x "$PACK_FILE_PATH" -o"$BUILD_DIR" -y
& "$7z" x "$PACK_TAR_FILE_PATH" -o"$PSC_ENV_PATH" -y

# Remove *.pyc/*.pyo
Get-Childitem -Path "$PSC_ENV_PATH" -Include *pyc -Recurse -ErrorAction SilentlyContinue | % { Remove-Item -Path "$_" }
Get-Childitem -Path "$PSC_ENV_PATH" -Include *pyo -Recurse -ErrorAction SilentlyContinue | % { Remove-Item -Path "$_" }

 # Remove __pycache__
Get-Childitem -Directory -Path "$PSC_ENV_PATH" -Name "__pycache__" -Recurse -ErrorAction SilentlyContinue | % { Remove-Item -Recurse -Path "$PSC_ENV_PATH\$_" -ErrorAction Ignore}

# Remove all tests folders except networkx's tests folder
$script:TEST_DIRS = ("test", "tests")
Get-ChildItem -Path "$PSC_ENV_PATH" -Directory -Recurse  | 
    ? { $_.FullName -inotmatch 'networkx'} |
    ? {"$TEST_DIRS".Contains($_.Name)} | 
    % {Write-Output "Deleting  "$_.FullName;  Remove-Item -Recurse -Path $_.FullName -ErrorAction Ignore}
          
# Remove other unnecessary cruft
$script:TO_DELETE_LIST = ("$PSC_ENV_PATH\tcl", "$PSC_ENV_PATH\include", "$PSC_ENV_PATH\conda-meta", 
"$PSC_ENV_PATH\tools", "$PSC_ENV_PATH\lib\sqlite3", "$PSC_ENV_PATH\share", "$PSC_ENV_PATH\Scripts")
foreach ($ITEM in $TO_DELETE_LIST) {
    Write-Output "Deleting $ITEM"
    Remove-Item -Recurse -Path "$ITEM"
}

# Apply Patches
Push-Location $(Join-Path "$PSC_ENV_PATH" "Lib")
(Get-Content -Path ".\ssl.py" |% { $_ -replace "_create_default_https_context = create_default_context", "_create_default_https_context = _create_unverified_context" }) | Set-Content -Path ".\ssl.py"
Pop-Location

Write-Output "Finishing"
