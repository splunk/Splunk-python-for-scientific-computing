$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$script:OUTPUT_PACKAGE_LIST_FILE = Join-Path $PLATFORM_DIR "environment.yml"
$env:Path += ";$($MINICONDA_BUILD_DIR);$(Join-Path $MINICONDA_BUILD_DIR "Scripts");$(Join-Path $MINICONDA_BUILD_DIR "Library\bin")"

& conda env export -p $VENV_BUILD_DIR | Out-File -FilePath $OUTPUT_PACKAGE_LIST_FILE -Encoding ASCII
$pkg_list_content = Get-Content $OUTPUT_PACKAGE_LIST_FILE
$trimmed_content = $pkg_list_content[0..($pkg_list_content.count - 2)]
Set-Content -Path $OUTPUT_PACKAGE_LIST_FILE -Value $trimmed_content.Replace("${PROJECT_DIR}\", '')
git diff -- $OUTPUT_PACKAGE_LIST_FILE