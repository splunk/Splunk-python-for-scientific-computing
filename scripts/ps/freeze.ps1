# Set script directory and load prerequisites
$script:SCRIPT_DIR = $PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

# Output file for environment specification
$script:OUTPUT_PACKAGE_LIST_FILE = Join-Path $PLATFORM_DIR "environment.yml"

# Add Library\bin to PATH for proper binary access
$env:Path += ";$(Join-Path $BASE_BUILD_DIR "Library\bin")"

# Export current environment configuration
& $Env:MAMBA_EXE env export -n psc | Out-File -FilePath $OUTPUT_PACKAGE_LIST_FILE -Encoding ASCII

# Clean up the exported file by removing project-specific paths
$pkg_list_content = Get-Content $OUTPUT_PACKAGE_LIST_FILE
$trimmed_content = $pkg_list_content[0..($pkg_list_content.count - 2)]
Set-Content -Path $OUTPUT_PACKAGE_LIST_FILE -Value $trimmed_content.Replace("${PROJECT_DIR}\", '')

# Show differences in the environment file
git diff -- $OUTPUT_PACKAGE_LIST_FILE