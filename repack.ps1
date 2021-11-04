Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SCRIPT_MODE
)

$ErrorActionPreference = "Stop"

$script:APPDIR = "Splunk_SA_Scientific_Python"
$script:VERSION = "3.0.1"
$script:GIT_HASH = & git rev-parse --short HEAD
$script:APPBUILD = "$GIT_HASH.$($env:BUILD_NUMBER)"
$script:BUILD_NUMBER = ${APPBUILD:-testing}

if ($SCRIPT_MODE -eq "analyze") {
    Write-Output "[INFO] Analyzing package tree"
    $script:MODE = 2
} elseif ($SCRIPT_MODE -eq "build") {
    Write-Output "[INFO] Building Python for Scientific Computing"
    $script:MODE = 0
} elseif ($SCRIPT_MODE -eq "freeze") {
    Write-Output "[INFO] Creating a locked package list"
    $script:MODE = 1
} elseif ($SCRIPT_MODE -eq "license") {
    Write-Output "[INFO] Generating license information"
    $script:MODE = 3
} else {
    Write-Output "Usage: repack.p1 {analyze|build|freeze|license}"
    Exit 1
}

# ------------------------ ENVIRONMENT DEFINITION ---------------------------

$script:SCRIPT_DIR = $PWD.Path
$script:BUILD_BASE_DIR = Join-Path "$SCRIPT_DIR" "build"
# See the list from https://repo.anaconda.com/miniconda/
$script:MINICONDA_VERSION = "py38_4.9.2"
$script:PLATFORM = "windows_x86_64"
$script:PLATFORM_DIR = Join-Path $SCRIPT_DIR $PLATFORM
$script:BUILD_DIR = Join-Path $BUILD_BASE_DIR $PLATFORM

# ------------------------ MINICONDA ----------------------------------------

$script:PACKAGE_LIST_FILE_PATH = Join-Path "$PLATFORM_DIR" "packages.txt"
$script:MINICONDA_FILE = "Miniconda3-$MINICONDA_VERSION-Windows-x86_64.exe"
$script:MINICONDA_PATH = Join-Path $PLATFORM_DIR $MINICONDA_FILE

# Check if miniconda installer is already downloaded
if (-Not (Test-Path $MINICONDA_PATH)) {
    $url = "https://repo.anaconda.com/miniconda/$MINICONDA_FILE"
    Invoke-WebRequest -Uri $url -OutFile "$MINICONDA_PATH"
}

$MINICONDA_MD5 = "6f7e4c725a07b128da25df68ffd32003"
$WINDOWS_MD5 = (Get-FileHash $MINICONDA_PATH -Algorithm MD5).Hash.ToLower()
if ($WINDOWS_MD5 -ne $MINICONDA_MD5) {
    throw "$MINICONDA_PATH MD5 is $WINDOWS_MD5, and does not match $MINICONDA_MD5"
}

if (-Not (Test-Path $PACKAGE_LIST_FILE_PATH)) {
    throw "$PACKAGE_LIST_FILE_PATH path not found"
}

# Clean up build dir
if (Test-Path -Path "$BUILD_BASE_DIR") {
    Write-Output "Cleaning build directory"
    # Work around long file names/paths
    Cmd /C "rmdir /S /Q $BUILD_BASE_DIR"
}
New-Item -Path "$BUILD_BASE_DIR" -ItemType "Directory"

# Setup intermediate environment
$script:CONDA_ENV_PATH = Join-Path "$BUILD_DIR" "conda"
$script:PACK_TARGET = Join-Path "$BUILD_DIR" "env"
$script:PACK_TAR_FILE_PATH = Join-Path "$BUILD_DIR" "miniconda-repack-${PLATFORM}.tar"
$script:BLACKLISTED_PACKAGES = Get-Content $(Join-Path $PLATFORM_DIR "blacklist.txt")
$script:PACK_FILE_PATH = "$PACK_TAR_FILE_PATH.gz"
$script:7Z = "C:\Program Files\7-Zip\7z.exe"

Write-Output "Installing $MINICONDA_PATH in $CONDA_ENV_PATH"
Start-Process -FilePath "$MINICONDA_PATH" -ArgumentList "/S /InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /D=$CONDA_ENV_PATH" -NoNewWindow -Wait

$env:Path += ";$($CONDA_ENV_PATH);$(Join-Path $CONDA_ENV_PATH "Scripts");$(Join-Path $CONDA_ENV_PATH "Library\bin")"
# initialize the conda environment to use powershell
& conda init powershell
& conda update -y -n base -c defaults conda
if ($MODE -eq 0) {
    & conda install -y -c conda-forge conda-pack conda-build

    Write-Output "Creating PSC conda environment in $PACK_TARGET and installing packages"
    & conda create -y -v -p $PACK_TARGET --file $PACKAGE_LIST_FILE_PATH

    & conda remove -p $PACK_TARGET -y --force @BLACKLISTED_PACKAGES
	& conda build purge-all

    # ------------------------- CREATE CONDA-PACK PACKAGE -------------------------------
    Write-Output "Packing PSC conda environment: $PACK_TARGET and saving as: $PACK_FILE_PATH"
    # Pack PSC directory into a conda pack and then untar it in place of the PSC directory
    & conda pack -p "$PACK_TARGET" -o "$PACK_FILE_PATH"

    # Replace PSC env directory with untarred contenct of the pack file
    Cmd /C "rmdir /S /Q $PACK_TARGET"
    Write-Output "Unpacking the $PACK_FILE_PATH package"
    & "$7z" x "$PACK_FILE_PATH" -o"$BUILD_DIR" -y
    & "$7z" x "$PACK_TAR_FILE_PATH" -o"$PACK_TARGET" -y

    # Remove *.pyc/*.pyo
    Get-Childitem -Path "$PACK_TARGET" -Include "*.pyc" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path "$_" }
    Get-Childitem -Path "$PACK_TARGET" -Include "*.pyo" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path "$_" }

    Get-Childitem -Path "$PACK_TARGET" -Include "*.whl" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path "$_" }
     # Remove __pycache__
    Get-Childitem -Directory -Path "$PACK_TARGET" -Name "__pycache__" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Recurse -Path "$PACK_TARGET\$_" -ErrorAction Ignore}

    # Remove all tests folders except networkx's tests folder
    $script:TEST_DIRS = ("test", "tests")
    Get-ChildItem -Path "$PACK_TARGET" -Directory -Recurse  |
        Where-Object { $_.FullName -inotmatch 'networkx'} |
        Where-Object {"$TEST_DIRS".Contains($_.Name)} |
        ForEach-Object {Write-Output "Deleting  "$_.FullName;  Remove-Item -Recurse -Path $_.FullName -ErrorAction Ignore}

    # Remove other unnecessary cruft
    $script:TO_DELETE_LIST = ("$PACK_TARGET\tcl", "$PACK_TARGET\include", "$PACK_TARGET\conda-meta",
    "$PACK_TARGET\tools", "$PACK_TARGET\lib\sqlite3", "$PACK_TARGET\share", "$PACK_TARGET\Scripts")
    foreach ($ITEM in $TO_DELETE_LIST) {
        Write-Output "Deleting $ITEM"
        Remove-Item -Recurse -Path "$ITEM" -ErrorAction Ignore
    }

    $script:TARGET = Join-Path "$BUILD_BASE_DIR" "${APPDIR}_${PLATFORM}"

    if (-Not (Test-Path "$BUILD_DIR")) {
        Write-Error "No Build directory found. Run 'repack.ps1' artifacts first and put them in $SCRIPTDIR\build"
        Exit 1
    }

    Copy-Item -Path $(Join-Path "$SCRIPT_DIR" "package") -Destination "$TARGET" -Recurse
    Copy-Item -Path $(Join-Path "$SCRIPT_DIR" $(Join-Path "$PLATFORM" "LICENSE")) -Destination $(Join-Path "$TARGET" "LICENSE") -Recurse -Force

    ## Update conf files
    (Get-Content -Path "$TARGET\default\app.conf" | ForEach-Object { $_ -replace "@build@", "$APPBUILD" }) | Set-Content -Path "$TARGET\default\app.conf"
    (Get-Content -Path "$TARGET\default\app.conf" | ForEach-Object { $_ -replace "@version@", "$VERSION" }) | Set-Content -Path "$TARGET\default\app.conf"
    (Get-Content -Path "$TARGET\default\app.conf" | ForEach-Object { $_ -replace "@platform@", "$PLATFORM" }) | Set-Content -Path "$TARGET\default\app.conf"

    Copy-Item -Path "$PACK_TARGET" -Destination "$TARGET\bin\$PLATFORM" -Recurse

    # Tarball the entire package
    $script:PACKAGE_NAME = "$($APPDIR)_$($PLATFORM)"
    Write-Output "Tarballing the $PACKAGE_NAME"

    Copy-Item -Path $(Join-Path "$SCRIPT_DIR" $(Join-Path "resources" "app.manifest.windows")) -Destination $(Join-Path "$TARGET" "app.manifest") -Recurse -Force

    & "$7Z" a "$BUILD_DIR\$PACKAGE_NAME.tar" "$TARGET" -y
    & "$7Z" a "$BUILD_BASE_DIR\$PACKAGE_NAME.tgz" "$BUILD_DIR\$PACKAGE_NAME.tar" -y
    Remove-Item -Recurse -Path "$BUILD_DIR" 
    Write-Output "[INFO] Build Successful"
} elseif ($MODE -eq 1) {
    & conda create -p $PACK_TARGET -y --file $(Join-Path $SCRIPT_DIR "requirements.txt")
    & conda remove -p $PACK_TARGET -y --force @BLACKLISTED_PACKAGES
    & conda list -p $PACK_TARGET -e | Out-File -FilePath $PACKAGE_LIST_FILE_PATH -Encoding ASCII
    Write-Output "$PACKAGE_LIST_FILE_PATH"
    git diff -- $PACKAGE_LIST_FILE_PATH
} elseif ($MODE -eq 2) {
    & conda install -c conda-forge -y conda-tree
    & conda create -p $PACK_TARGET -y --file $(Join-Path $SCRIPT_DIR "requirements.txt")
    & conda-tree -p $PACK_TARGET deptree
} elseif ($MODE -eq 3) {
    & conda create -p $PACK_TARGET -y --file $(Join-Path $SCRIPT_DIR "requirements.txt")
    & conda remove -p $PACK_TARGET -y --force @BLACKLISTED_PACKAGES
    $script:LICENSE_FILE = $(Join-Path "$SCRIPT_DIR" $(Join-Path "$PLATFORM" "LICENSE"))
    Copy-Item -Path $(Join-Path "$SCRIPT_DIR" "LICENSE") -Destination $LICENSE_FILE -Recurse -Force
    Add-Content "$LICENSE_FILE" "`r`n`r`n========================================================================`r`n"
    Add-Content "$LICENSE_FILE" "Package licenses:`r`n"
    Write-Output "`r`nPackage licenses:`r`n"
    $script:LICENSE_DB = Import-Csv -Path $(Join-Path "$SCRIPT_DIR" "license_db.csv")
    & conda list -p $PACK_TARGET | ForEach-Object {
        $script:line = $_
        if (-Not $line.StartsWith("#")) {
            $script:PKG_NAME = $line.split(" ")[0]
            $script:OUTPUT_LINE = ""
            $script:LICENSE_DB | ForEach-Object {
                if ($_.NAME -eq $PKG_NAME) {
                    $script:OUTPUT_LINE = "{0,-16}{1,-36}{2}" -f $_.NAME, $_.LICENSE, $_.URL
                }
            }
            if ($script:OUTPUT_LINE -eq "") {
                Write-Output "$PKG_NAME does not have a record in license_db.csv, please update license_db.csv"
                Exit 1
            }
            Add-Content "$LICENSE_FILE" "$OUTPUT_LINE"
            Write-Output $OUTPUT_LINE
        }
    }
    Write-Output "`r`n[INFO] License file $LICENSE_FILE updated"
}
