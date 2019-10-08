# Stop on any error
$ErrorActionPreference = "Stop"

$script:VERSION = 2.0.0
$script:GIT_HASH = & git rev-parse --short HEAD
$script:APPBUILD = "$GIT_HASH.$($env:BUILD_NUMBER)"
$script:BUILD_NUMBER = ${BUILD_NUMBER:-testing}
$script:SCRIPT_DIR = $PWD.Path
$script:BUILD_PATH = Join-Path $SCRIPT_DIR "build"
$script:APPDIR = "Splunk_SA_Scientific_Python"
$script:TARGET= Join-Path "$BUILD_PATH" "$($APPDIR)_windows_x86_64"
$script:7Z = "C:\Program Files\7-Zip\7z.exe"

if (-Not (Test-Path "$BUILD_PATH")) {
    Write-Error "No Build directory found. Run 'repack.ps1' artifacts first and put them in $SCRIPTDIR\build"
    Exit 1
}

$script:PLATFORM = "windows_x86_64"
$script:minicondaPkgName= "miniconda-repack-${PLATFORM}"
$script:minicondaPkg = "$minicondaPkgName.tar.gz"
$script:tarBallPkg = Join-Path "$BUILD_PATH" "$minicondaPkg"
if (-Not (Test-Path -Path $tarBallPkg)) {
    Write-Error "Tarball: $tarBallPkg does not exist"
    exit 1
}

Remove-Item -Path $BUILD_PATH -Recurse -Exclude "*.tar.gz" -Force

Copy-Item -Path $(Join-Path "$SCRIPT_DIR" "package") -Destination $TARGET -Recurse

## Update conf files
(Get-Content -Path "$TARGET\default\app.conf" |% { $_ -replace "@build@", "$APPBUILD" }) | Set-Content -Path "$TARGET\default\app.conf"
(Get-Content -Path "$TARGET\default\app.conf" |% { $_ -replace "@version@", "$VERSION" }) | Set-Content -Path "$TARGET\default\app.conf"
(Get-Content -Path "$TARGET\default\app.conf" |% { $_ -replace "@platform@", "windows_x86_64" }) | Set-Content -Path "$TARGET\default\app.conf"

# Untar the miniconda file
Write-Output "Unpacking the $minicondaPkgName package"
& "$7z" x $tarBallPkg -o"$BUILD_PATH" -y
& "$7z" x "$BUILD_PATH\$minicondaPkgName.tar" -o"$TARGET\bin\windows_x86_64" -y

# Tarball the entire package
$script:PACKAGE_NAME = "$($APPDIR)_windows_x86_64"
Write-Output "Tarballing the $PACKAGE_NAME"

$script:buildPath =
& "$7Z" a "$BUILD_PATH\$PACKAGE_NAME.tar" "$BUILD_PATH\$PACKAGE_NAME\*" -y
& "$7Z" a "$SCRIPT_DIR\$PACKAGE_NAME.tgz" "$BUILD_PATH\$PACKAGE_NAME.tar" -y