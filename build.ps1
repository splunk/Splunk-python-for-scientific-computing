# Stop on any error
$ErrorActionPreference = "Stop"

$script:PSC_VERSION = "2.0.0"
$script:GIT_HASH = & git rev-parse --short HEAD
$script:APPBUILD = "$GIT_HASH.$($env:BUILD_NUMBER)"
$script:BUILD_NUMBER = ${BUILD_NUMBER:-testing}
$script:SCRIPT_DIR = $PWD.Path
$script:BUILD_DIR = Join-Path $SCRIPT_DIR "build"
$script:APPDIR = "Splunk_SA_Scientific_Python"
$script:TARGET= Join-Path "$BUILD_DIR" "$($APPDIR)_windows_x86_64"
$script:PSC_ENV_PATH = Join-Path "$BUILD_DIR" "psc_env"
$script:7Z = "C:\Program Files\7-Zip\7z.exe"

if (-Not (Test-Path "$BUILD_DIR")) {
    Write-Error "No Build directory found. Run 'repack.ps1' artifacts first and put them in $SCRIPTDIR\build"
    Exit 1
}

$script:PLATFORM = "windows_x86_64"

Copy-Item -Path $(Join-Path "$SCRIPT_DIR" "package") -Destination "$TARGET" -Recurse
Copy-Item -Path $(Join-Path "$SCRIPT_DIR" "windows_x86_64\LICENSE") -Destination "$TARGET\LICENSE" -Recurse -Force

## Update conf files
(Get-Content -Path "$script:TARGET\default\app.conf" |% { $_ -replace "@build@", "$script:APPBUILD" }) | Set-Content -Path "$script:TARGET\default\app.conf"
(Get-Content -Path "$script:TARGET\default\app.conf" |% { $_ -replace "@version@", "$script:PSC_VERSION" }) | Set-Content -Path "$script:TARGET\default\app.conf"
(Get-Content -Path "$script:TARGET\default\app.conf" |% { $_ -replace "@platform@", "windows_x86_64" }) | Set-Content -Path "$script:TARGET\default\app.conf"

Copy-Item -Path "$PSC_ENV_PATH" -Destination "$TARGET\bin\windows_x86_64" -Recurse
#& "$7z" x "$BUILD_DIR\$minicondaPkgName.tar" -o"$script:TARGET\bin\windows_x86_64" -y

# Tarball the entire package
$script:PACKAGE_NAME = "$($APPDIR)_windows_x86_64"
Write-Output "Tarballing the $PACKAGE_NAME"

& "$7Z" a "$BUILD_DIR\$PACKAGE_NAME.tar" "$BUILD_DIR\$PACKAGE_NAME" -y
& "$7Z" a "$BUILD_DIR\$PACKAGE_NAME.tgz" "$BUILD_DIR\$PACKAGE_NAME.tar" -y
