
Write-Output "Deploying ***repack.ps1***"
& $(Join-Path $($PWD.Path) "repack.ps1")

Write-Output "Deploying ***build.ps1***"
& $(Join-Path $($PWD.Path) "build.ps1")
