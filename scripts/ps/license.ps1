$script:SCRIPT_DIR=$PSScriptRoot
. $(Join-Path "$SCRIPT_DIR" "prereq.ps1")

$script:BLACKLISTED_PACKAGES = Get-Content $(Join-Path $PLATFORM_DIR "blacklist.txt")

$env:PLATFORM=$PLATFORM
$env:BLACKLISTED_PACKAGES=$BLACKLISTED_PACKAGES
$env:VENV_BUILD_DIR="$VENV_BUILD_DIR\envs\psc"

(& $Env:MAMBA_EXE 'shell' 'hook' -s 'powershell') | Out-String | Invoke-Expression
#& $Env:MAMBA_EXE run -n tools python $(Join-Path $PROJECT_DIR $(Join-Path "tools" "license.py"))
$license_extra = @{}
Import-Csv -Path $(Join-Path $SCRIPT_DIR "..\..\tools\license_extra.csv") | foreach { $license_extra[$_.name] = @{ license_override=$_.license_override; license_url=$_.license_url; functionality=$_.functionality; notes=$_.notes } }

$report = @()
$pkgs = (& $Env:MAMBA_EXE 'list' -n 'psc' --json) | ConvertFrom-Json
ForEach ($pkg in $pkgs)
{
#    Write-Output $pkg | ConvertTo-Json
#    Write-Output $license_extra[$pkg.name] | ConvertTo-Json
    $pkg_search_res=(& $Env:MAMBA_EXE 'repoquery' 'search' ($pkg.name + '=' + $pkg.version + '=' + $pkg.build_string) -c $pkg.channel --json) | ConvertFrom-Json
#    Write-Output $pkg_search_res.result.pkgs[0]  | ConvertTo-Json
    $search_res=$pkg_search_res.result.pkgs[0]
    $license=$search_res.license
    if ($search_res.license_override -eq "") {
        $license=$license_extra[$pkg.name].license_override
    }
    $pkg_report = [pscustomobject]@{ name=$pkg.name; version=$pkg.version; license=$license; license_url=$license_extra[$pkg.name]["license_url"]; functionality=$license_extra[$pkg.name]["functionality"]; notes=$license_extra[$pkg.name]["notes"]; dist_name=$pkg.dist_name; channel=$pkg.channel;  build=$search_res.build; build_number=$pkg.build_number; }
    Write-Output $pkg_report | ConvertTo-Json
    $report += $pkg_report
}
Write-Output $report | ConvertTo-Csv


Write-Output "`r`n[INFO] License file ${PLATFORM_DIR}/LICENSE updated"