param(
    [string]$ModulePath = "..\ps-youtrack\ps-youtrack.psm1",
    [string]$CredsPath = "..\ignore\youtrack_permanent_token.key"
)

Import-Module $ModulePath -Force

Write-Host "Trying API call before client creation:"
try {
    $my_issues = Get-YtIssues -ForMe -Fields @("idReadable", "summary")
    Write-Host "Uh-oh, it worked. We shouldn't be here."
} catch {
    Write-Host "Task failed succesfully: '$_'"
}


Write-Host "Importing credentials"
$creds = Import-Clixml -Path $CredsPath

Write-Host "Creating YouTrack client"
New-YtClient `
    -BaseUrl "https://youtrack.tnwops.com/api" `
    -PermanentToken $creds.Password

Write-Host "Fetching YouTrack Issues assigned to me"
$my_issues = Get-YtIssues -ForMe -Fields @(
    "idReadable",
    "summary",
    "customFields(name,value(name))")
$my_issues | Select-Object idReadable, summary, @{
    Name       = "state"
    Expression = {
        ($_.customFields | Where-Object name -Like "State").value.name
    }
} | Format-Table -AutoSize

foreach ($iss in $my_issues) {
    $state = ($iss.customFields | Where-Object name -Like "State").value.name

    switch ($state) {
        { $_.StartsWith("To Do") } {
            "**WAIT $($iss.idReadable) - $($iss.summary)"
            break
        }
        { $_.StartsWith("In Progress") } {
            "**PROG $($iss.idReadable) - $($iss.summary)"
            break
        }
        { $_.StartsWith("Submitted") } {
            "**WAIT $($iss.idReadable) - $($iss.summary)"
            break
        }
        default { "** TODO $($iss.idReadable) - $($iss.summary)" }
    }
}

# $my_issues | ForEach-Object {
#     Write-Host "$($_.idReadable) - $($_.summary)" -NoNewline
#     $_.customFields | Format-Table
# }
