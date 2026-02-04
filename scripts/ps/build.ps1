# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Validate required environment variables
if (-not $env:BUILD) {
    Write-Output "BUILD env var is required"
    Exit 1
}
if (-not $env:VERSION) {
    Write-Output "VERSION env var is required"
    Exit 1
}

Write-Output "-----------------"
Write-Output "Building PSC ${env:VERSION} build ${env:BUILD}"
Write-Output "-----------------"

# Build configuration
$script:MANIFEST_FILE = "app.manifest.windows"
$script:7Z = "C:\Program Files\7-Zip\7z.exe"
$script:PACK_TAR_FILE_PATH = Join-Path $BASE_BUILD_DIR "micromamba-repack.tar"

# Clean and prepare build directories
Remove-Item -Recurse $APP_BUILD_DIR -ErrorAction Ignore
$DIST_VERSION_BUILD_DIR = Join-Path $DIST_BUILD_DIR $env:VERSION.replace('.', '_')
#$DIST_VERSION_BUILD_DIR = $DIST_BUILD_DIR
#$DIST_BIN_BUILD_DIR = Join-Path $DIST_BUILD_DIR "bin"
New-Item $DIST_VERSION_BUILD_DIR -ItemType Directory
#New-Item $DIST_BIN_BUILD_DIR -ItemType Directory

# Extract conda-pack archive
Write-Output "[INFO] extracting conda-pack archive"
& "$7Z" x "$PACK_FILE_PATH" -o"$BASE_BUILD_DIR" -y
& "$7Z" x "$PACK_TAR_FILE_PATH" -o"$DIST_VERSION_BUILD_DIR" -y

# Clean up Python compiled files
Get-Childitem -Path "$DIST_VERSION_BUILD_DIR" -Include "*.pyc" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -Path "$_" }
Get-Childitem -Path "$DIST_VERSION_BUILD_DIR" -Include "*.pyo" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -Path "$_" }
Get-Childitem -Path "$DIST_VERSION_BUILD_DIR" -Include "*.whl" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -Path "$_" }

# Clean up Python cache directories
Get-Childitem -Directory -Path "$DIST_VERSION_BUILD_DIR" -Name "__pycache__" -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -Recurse -Path "$DIST_VERSION_BUILD_DIR\$_" -ErrorAction Ignore }

# Remove test directories (except networkx, numpy, and onnx tests)
$script:TEST_DIRS = ("test", "tests")
Get-ChildItem -Path "$DIST_VERSION_BUILD_DIR" -Directory -Recurse |
    Where-Object { $_.FullName -inotmatch 'networkx' -and $_.FullName -inotmatch 'numpy[\\/_]_core[\\/_]tests'} |
    Where-Object { "$TEST_DIRS".Contains($_.Name) } |
    ForEach-Object {
        Write-Output "Deleting $($_.FullName)"
        Remove-Item -Recurse -Path $_.FullName -ErrorAction Ignore
    }

# Remove unnecessary directories and files
$script:TO_DELETE_LIST = @(
    "$DIST_VERSION_BUILD_DIR\tcl",
    "$DIST_VERSION_BUILD_DIR\include",
    "$DIST_VERSION_BUILD_DIR\conda-meta",
    "$DIST_VERSION_BUILD_DIR\tools",
    "$DIST_VERSION_BUILD_DIR\lib\sqlite3",
    "$DIST_VERSION_BUILD_DIR\share",
    "$DIST_VERSION_BUILD_DIR\Scripts"
)

foreach ($ITEM in $TO_DELETE_LIST) {
    Write-Output "Deleting $ITEM"
    Remove-Item -Recurse -Path "$ITEM" -ErrorAction Ignore
}

# Remove pip package from distribution
Write-Output "[INFO] Removing pip package from distribution"
Get-ChildItem -Path "$DIST_VERSION_BUILD_DIR\Lib\site-packages" -Directory -Filter "pip" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -Recurse -Path $_.FullName -ErrorAction Ignore }
Get-ChildItem -Path "$DIST_VERSION_BUILD_DIR\Lib\site-packages" -Directory -Filter "pip-*.dist-info" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item -Recurse -Path $_.FullName -ErrorAction Ignore }

# Copy package files and resources
Copy-Item -Path $(Join-Path $PROJECT_DIR "package\*") -Destination $APP_BUILD_DIR -Recurse -Force
Copy-Item -Path $(Join-Path $PROJECT_DIR $(Join-Path "resources" $MANIFEST_FILE)) -Destination $(Join-Path $APP_BUILD_DIR "app.manifest") -Force

# Update configuration files with build-specific values
(Get-Content -Path "$APP_BUILD_DIR\default\app.conf" |
    ForEach-Object { $_ -replace "@app_id@", "${APP_NAME}_${PLATFORM}" }) |
    Set-Content -Path "$APP_BUILD_DIR\default\app.conf"

(Get-Content -Path "$APP_BUILD_DIR\default\app.conf" |
    ForEach-Object { $_ -replace "@version@", "$env:VERSION" }) |
    Set-Content -Path "$APP_BUILD_DIR\default\app.conf"

(Get-Content -Path "$APP_BUILD_DIR\default\app.conf" |
    ForEach-Object { $_ -replace "@build@", "$env:BUILD" }) |
    Set-Content -Path "$APP_BUILD_DIR\default\app.conf"

(Get-Content -Path "$APP_BUILD_DIR\app.manifest" |
    ForEach-Object { $_ -replace "@app_id@", "${APP_NAME}_${PLATFORM}" }) |
    Set-Content -Path "$APP_BUILD_DIR\app.manifest"

(Get-Content -Path "$APP_BUILD_DIR\app.manifest" |
    ForEach-Object { $_ -replace "@version@", "$env:VERSION" }) |
    Set-Content -Path "$APP_BUILD_DIR\app.manifest"

(Get-Content -Path "$APP_BUILD_DIR\default\inputs.conf" |
    ForEach-Object { $_ -replace "@build@", "${APP_NAME}_${PLATFORM}" }) |
    Set-Content -Path "$APP_BUILD_DIR\default\inputs.conf"


Write-Output "[INFO] building distribution manifest"

if (-not $DIST_BUILD_DIR) {
    throw "DIST_BUILD_DIR variable is not set in build.ps1"
}

# Collect relative paths (similar to `find . -type f,d,l`)
$paths = Get-ChildItem -Path $DIST_BUILD_DIR -Recurse -Force |
    ForEach-Object {
        $relative = $_.FullName.Substring($DIST_BUILD_DIR.Length).TrimStart('\','/')
        if ($relative -eq "") { "." } else { $relative }
    }

# Manifest file path
$manifestPath = Join-Path $DIST_BUILD_DIR "build.manifest"

# Create or recreate manifest (overwrite if exists)
$paths | Set-Content -Path $manifestPath -Encoding utf8


Write-Output "[INFO] Build Successful"