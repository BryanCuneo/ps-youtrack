param(
    [ValidateNotNullOrWhiteSpace()]
    [string]$ModulePath = "../module-name/module-name.psm1",

    [ValidateNotNullOrWhitespace()]
    [string]$LogOutputPath = "./module-name.log"
)

Import-Module -Name $ModulePath -Force

Write-Host "Testing module-name"