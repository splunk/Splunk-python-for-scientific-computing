$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")
. $(Join-Path "$SCRIPT_DIR" "miniconda_settings.ps1")

if ( $OS -eq "Windows" ) {
    $MINICONDA_PLATFORM="${OS}-$ARCH"
}

$script:MINICONDA_FILE="Miniconda3-${MINICONDA_VERSION}-${MINICONDA_PLATFORM}.exe"
$script:MINICONDA_PATH=Join-Path $BASE_BUILD_DIR $MINICONDA_FILE

New-Item $BASE_BUILD_DIR -ItemType Directory -ErrorAction Ignore

# Check if miniconda installer is already downloaded
if (-Not (Test-Path $MINICONDA_PATH)) {
    $url = "https://repo.anaconda.com/miniconda/$MINICONDA_FILE"
    Invoke-WebRequest -Uri $url -OutFile "$MINICONDA_PATH"
}

$env:PSModulePath = "${PSHOME}/Modules"
$WINDOWS_SHA256 = $(Get-FileHash $MINICONDA_PATH -Algorithm SHA256).Hash.ToLower()
if ($WINDOWS_SHA256 -ne $WINDOWS_X86_64_SHA256) {
    throw "$MINICONDA_PATH MD5 is $WINDOWS_SHA256, and does not match $WINDOWS_X86_64_SHA256"
}

Remove-Item -Recurse $MINICONDA_BUILD_DIR -ErrorAction Ignore

Write-Output "Installing $MINICONDA_PATH in $MINICONDA_BUILD_DIR"
Start-Process -FilePath "$MINICONDA_PATH" -ArgumentList "/S /InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /D=$MINICONDA_BUILD_DIR" -NoNewWindow -Wait
$env:Path += ";$($MINICONDA_PATH);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"
# initialize the conda environment to use powershell
& conda init powershell
& conda install -y -c conda-forge conda-pack conda-tree conda-build