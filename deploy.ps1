# Copyright (c) 2026 Bryan Cuneo

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

param(
    [string]$FolderPath = "",
    [string]$ModuleName,
    [version]$Version,
    [string]$LocalRepoName = "",
    [string]$Author,
    [string]$CompanyName = "Unknown",
    [version]$MinPsVersion,
    [string[]]$FunctionsToExport = "*",
    [string[]]$CmdletsToExport = "*",
    [string[]]$VariablesToExport = "*",
    [string[]]$AliasesToExport = "*",
    [string]$LicenseUri,
    [string]$ProjectUri,
    [string]$Prerelease,

    [string]$LogPath = "./deploy.log",

    [switch]$Install,
    [switch]$Force
)

Import-Module ps-jsonlogger

$logger_params = @{
    Path        = $LogPath
    ProgramName = "PS Module Deploy Script"
    WriteToHost = "Simple"
    Overwrite   = $true
    Force       = $true
}
New-Logger @logger_params

if ($Force) {
    Write-Log -Wrn "`$Force flag enabled"
}

# Use Resolve-Path and Test-Path to throw an error if $FolderPath is
# not a valid directory
try {
    $FolderPath = Resolve-Path -Path $FolderPath -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        throw "Test-Path: '$FolderPath' is not a directory"
    }
    Write-Log -Inf "`$FolderPath '$FolderPath' validated"
}
catch {
    Write-Log -Ftl "Input validation failed `$FolderPath '$FolderPath' is not a directory"
}

# Try a couple ways to find the current user's name
if ([string]::IsNullOrWhiteSpace($Author)) {
    Write-Log -Wrn "`$Author not specified. Checking 'git config user.name'"
    $Author = git config user.name

    if ([string]::IsNullOrWhiteSpace($Author)) {
        Write-Log -Wrn "Unsuccessful. Checking Office registry key"
        $Author = (Get-ItemProperty "HKCU:\\Software\\Microsoft\\Office\\Common\\UserInfo\\" -ErrorAction SilentlyContinue).UserName
    }

    if ([string]::IsNullOrWhiteSpace($Author)) {
        Write-Log -Ftl "Unable to find a name. Please run this scrip again with the '-Author' parameter"
    }

    Write-Log -Scs "Found '$Author'"
}

if ([string]::IsNullOrWhiteSpace($ModuleName)) {
    $ModuleName = Split-Path -Path $FolderPath -Leaf
    Write-Log -Wrn "`$ModuleName not provided, using '$ModuleName'"
}

$copyright = "(c) $(Get-Date -f "yyyy") $Author. <TERMS OR LICENSE BLURB>"
$description = "$ModuleName <DESCRIPTION>"
$psd_path = Join-Path -Path $FolderPath -ChildPath "$ModuleName.psd1"

$manifest_params = @{
    Path              = $psd_path
    RootModule        = $ModuleName
    ModuleVersion     = $Version
    Author            = $Author
    CompanyName       = $CompanyName
    Copyright         = $copyright
    Description       = $description
    FunctionsToExport = $FunctionsToExport
    CmdletsToExport   = $CmdletsToExport
    VariablesToExport = $VariablesToExport
    AliasesToExport   = $AliasesToExport
}
if ($MinPsVersion) {
    $manifest_params.PowerShellVersion = $MinPsVersion
}
if ($LicenseUri) {
    $manifest_params.LicenseUri = $LicenseUrirams
}
if ($ProjectUri) {
    $manifest_params.ProjectUri = $ProjectUri
}
if ($Prerelease) {
    $manifest_params.Prerelease = $Prerelease
}

if (Test-Path $psd_path) {
    Write-Log -Inf "Updating module manifest"
    Update-ModuleManifest @manifest_params -ErrorAction Stop
}
else {
    Write-Log -Inf "Generating module manifest"
    New-ModuleManifest @manifest_params -ErrorAction Stop
}
Write-Log -Scs "Module manifest built. Review at '$psd_path'"

# If this is a prerelease, combine that with the $Version variable for use in
# a few times later in the script
if ($Prerelease) {
    $version_str = "$Version-$Prerelease"
}
else {
    $version_str = $Version.ToString()
}

if ($Force) {
    $pkg_path = Join-Path `
        -Path (Get-PSRepository $LocalRepoName).SourceLocation `
        -ChildPath "$ModuleName.$version_str.nupkg"
    Write-Log -Inf "`$Force flag enabled. Removing '$pkg_path' if it exists"
    Remove-Item `
        -Path $pkg_path `
        -ErrorAction Stop `
        -ProgressAction SilentlyContinue
}

try {
    Write-Log -Inf "Publishing module"
    Publish-Module -Path $FolderPath -Repository $LocalRepoName
}
catch {
    Write-Log -Ftl "Error publishing module: '$_'"
}

if (-not $Install) {
    Write-Log -Scs "Module published successfully"
    Close-Log "All done"
    exit
}

$module_params = [ordered]@{
    Name            = $ModuleName
    RequiredVersion = $version_str
    WarningAction   = "Stop"
    ProgressAction  = "SilentlyContinue"
}
if ($Prerelease) {
    $module_params.AllowPrerelease = $true
}

# Build a string representation of the Install-/Update-Module commands
# to log out to the user.
$parts = foreach ($entry in $module_params.GetEnumerator()) {
    $value = $entry.Value

    if ($value -is [bool]) {
        $formattedValue = "`$$($value.ToString().ToLowerInvariant())"
    }
    else {
        $text = [string]$value
        $formattedValue = '"' + $text.Replace('"', '`"') + '"'
    }

    "-$($entry.Key) $formattedValue"
}

if ($Force -and (Get-Module -ListAvailable -Name $ModuleName)) {
    try {
        $update_str = "Update-Module " + ($parts -join " ")
        $log_params = @{
            Level   = "INFO"
            Message = "`$Force flag enabled. Updating existing module with '$update_str"
            Context = $module_params
        }
        Write-Log @log_params

        Update-Module @module_params
        Write-Log -Scs "Module published and updated successfully"
    }
    catch {
        Write-Log -Ftl "Error updating module: '$_'"
    }
    finally {
        Close-Log
        exit
    }
}

try {
    $module_params.Repository = $LocalRepoName
    $parts += "-Repository `"$LocalRepoName`""
    $install_str = "Install-Module " + ($parts -join " ")
    $log_params = @{
        Level   = "INFO"
        Message = "Installing existing module with '$install_str"
        Context = $module_params
    }
    Write-Log @log_params

    Install-Module @module_params
    Write-Log -Scs "Module published and installed successfully"
}
catch {
    Write-Log -Ftl "Error installing module: '$_'"
}
finally {
    Close-Log "All done"
}
