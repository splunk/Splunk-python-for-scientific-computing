# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")
. $(Join-Path "$SCRIPT_DIR" "micromamba_settings.ps1")

# Verify 7-Zip installation
$7zipPath = "C:\Program Files\7-Zip\7z.exe"
if (!(Test-Path $7zipPath)) {
    Write-Host "[ERROR] 7-Zip is not installed. Please install 7-Zip and retry." -ForegroundColor Red
    exit 1
}

# Micromamba download and extraction configuration
$script:MICROMAMBA_FILE = "micromamba-win-64.tar.bz2"
$script:MICROMAMBA_DOWNLOAD_PATH = Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar.bz2"
$script:MICROMAMBA_EXTRACTED_TAR = Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar"
$script:MICROMAMBA_BINARY = Join-Path $MICROMAMBA_BUILD_DIR "micromamba.exe"

# Create required directories
New-Item $MICROMAMBA_BUILD_DIR -ItemType Directory -Force
New-Item $VENV_BUILD_DIR -ItemType Directory -Force

# Download micromamba from official releases
Invoke-WebRequest -URI "https://github.com/mamba-org/micromamba-releases/releases/download/$MICROMAMBA_VERSION/$MICROMAMBA_FILE" -OutFile $(Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar.bz2")

# Extract the downloaded archive
& $7zipPath x -o"$MICROMAMBA_BUILD_DIR" $MICROMAMBA_DOWNLOAD_PATH -y
& $7zipPath x -o"$MICROMAMBA_BUILD_DIR" $MICROMAMBA_EXTRACTED_TAR -y

# Locate the extracted micromamba executable
$extractedMicromamba = Get-ChildItem -Path $MICROMAMBA_BUILD_DIR -Recurse -Filter "micromamba.exe" | Select-Object -First 1
if (-Not $extractedMicromamba) {
    Write-Host "[ERROR] micromamba.exe not found after extraction!" -ForegroundColor Red
    exit 1
}

# Verify file integrity using SHA256 checksum
$computedSHA256 = (Get-FileHash $extractedMicromamba.FullName -Algorithm SHA256).Hash.ToLower()
Write-Host "Computed SHA256: $computedSHA256"
Write-Host "Expected SHA256: $WINDOWS_X86_64_SHA256"

if ($computedSHA256 -ne $WINDOWS_X86_64_SHA256) {
    Write-Host "[ERROR] SHA256 mismatch! File may be corrupted." -ForegroundColor Red
    exit 1
}

Write-Host "SHA256 checksum verified successfully." -ForegroundColor Green

# Final extraction of the tar file
& $7zipPath x -o"$MICROMAMBA_BUILD_DIR" $(Join-Path $MICROMAMBA_BUILD_DIR "micromamba.tar") -y