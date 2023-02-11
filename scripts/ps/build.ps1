$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

if (-not $env:BUILD) {
    Write-Output "BUILD env var is required"
    Exit 1
}
if (-not $env:VERSION) {
    Write-Output "VERSION env var is required"
    Exit 1
}

$script:MANIFEST_FILE="app.manifest.windows"
$script:7Z = "C:\Program Files\7-Zip\7z.exe"
$script:PACK_TAR_FILE_PATH = Join-Path $BASE_BUILD_DIR "miniconda-repack.tar"

Remove-Item -Recurse $APP_BUILD_DIR -ErrorAction Ignore
$DIST_VERSION_BUILD_DIR = Join-Path $DIST_BUILD_DIR $env:VERSION.replace('.', '_')
$DIST_BIN_BUILD_DIR= Join-Path $DIST_BUILD_DIR "bin"
New-Item $DIST_VERSION_BUILD_DIR -ItemType Directory
New-Item $DIST_BIN_BUILD_DIR -ItemType Directory
Write-Output "[INFO] extracting conda-pack archive"
& "$7z" x "$PACK_FILE_PATH" -o"$BASE_BUILD_DIR" -y
& "$7z" x "$PACK_TAR_FILE_PATH" -o"$DIST_VERSION_BUILD_DIR" -y

# Remove *.pyc/*.pyo
Get-Childitem -Path "$DIST_VERSION_BUILD_DIR" -Include "*.pyc" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path "$_" }
Get-Childitem -Path "$DIST_VERSION_BUILD_DIR" -Include "*.pyo" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path "$_" }

Get-Childitem -Path "$DIST_VERSION_BUILD_DIR" -Include "*.whl" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Path "$_" }
# Remove __pycache__
Get-Childitem -Directory -Path "$DIST_VERSION_BUILD_DIR" -Name "__pycache__" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -Recurse -Path "$DIST_VERSION_BUILD_DIR\$_" -ErrorAction Ignore}

# Remove all tests folders except networkx's tests folder
$script:TEST_DIRS = ("test", "tests")
Get-ChildItem -Path "$DIST_VERSION_BUILD_DIR" -Directory -Recurse  |
    Where-Object { $_.FullName -inotmatch 'networkx'} |
    Where-Object {"$TEST_DIRS".Contains($_.Name)} |
    ForEach-Object {Write-Output "Deleting  "$_.FullName;  Remove-Item -Recurse -Path $_.FullName -ErrorAction Ignore}

# Remove other unnecessary cruft
$script:TO_DELETE_LIST = ("$DIST_VERSION_BUILD_DIR\tcl", "$DIST_VERSION_BUILD_DIR\include", "$DIST_VERSION_BUILD_DIR\conda-meta",
"$DIST_VERSION_BUILD_DIR\tools", "$DIST_VERSION_BUILD_DIR\lib\sqlite3", "$DIST_VERSION_BUILD_DIR\share", "$DIST_VERSION_BUILD_DIR\Scripts")
foreach ($ITEM in $TO_DELETE_LIST) {
    Write-Output "Deleting $ITEM"
    Remove-Item -Recurse -Path "$ITEM" -ErrorAction Ignore
}

Copy-Item -Path $(Join-Path $PROJECT_DIR "package\*") -Destination $APP_BUILD_DIR -Recurse -Force
Copy-Item -Path $(Join-Path $PROJECT_DIR $(Join-Path $PLATFORM "LICENSE")) -Destination $(Join-Path $APP_BUILD_DIR "LICENSE") -Force
Copy-Item -Path $(Join-Path $PROJECT_DIR $(Join-Path "resources" $MANIFEST_FILE)) -Destination $(Join-Path $APP_BUILD_DIR "app.manifest") -Force
Copy-Item -Path $(Join-Path $PROJECT_DIR $(Join-Path "shims" "python.bat")) -Destination $(Join-Path $DIST_BIN_BUILD_DIR "python.bat") -Force

## Update conf files
(Get-Content -Path "$DIST_BIN_BUILD_DIR\python.bat" | ForEach-Object { $_ -replace "@app_id@", "${APP_NAME}_${PLATFORM}" }) | Set-Content -Path "$DIST_BIN_BUILD_DIR\python.bat"
(Get-Content -Path "$DIST_BIN_BUILD_DIR\python.bat" | ForEach-Object { $_ -replace "@version_dir@", $env:VERSION.replace('.', '_') }) | Set-Content -Path "$DIST_BIN_BUILD_DIR\python.bat"
(Get-Content -Path "$APP_BUILD_DIR\default\app.conf" | ForEach-Object { $_ -replace "@app_id@", "${APP_NAME}_${PLATFORM}" }) | Set-Content -Path "$APP_BUILD_DIR\default\app.conf"
(Get-Content -Path "$APP_BUILD_DIR\default\app.conf" | ForEach-Object { $_ -replace "@version@", "$env:VERSION" }) | Set-Content -Path "$APP_BUILD_DIR\default\app.conf"
(Get-Content -Path "$APP_BUILD_DIR\default\app.conf" | ForEach-Object { $_ -replace "@build@", "$env:BUILD" }) | Set-Content -Path "$APP_BUILD_DIR\default\app.conf"
(Get-Content -Path "$APP_BUILD_DIR\app.manifest" | ForEach-Object { $_ -replace "@app_id@", "${APP_NAME}_${PLATFORM}" }) | Set-Content -Path "$APP_BUILD_DIR\app.manifest"
(Get-Content -Path "$APP_BUILD_DIR\app.manifest" | ForEach-Object { $_ -replace "@version@", "$env:VERSION" }) | Set-Content -Path "$APP_BUILD_DIR\app.manifest"

Write-Output "[INFO] Build Successful"