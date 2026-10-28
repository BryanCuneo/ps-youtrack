# ps-youtrack

ps-youtrack is a very work-in-progress PowerShell 7 wrapper around the YouTrack REST API. This is a prerelease version and is not yet available on PS Gallery, however you may download the latest `.nupkg` file directly from the [releases page](https://github.com/BryanCuneo/ps-youtrack/releases) and install it using a local repository:

```PowerShell
PS > $myRepoParams = @{
  Name = "MyPsRepo"
  SourceLocation = "/path/to/MyPsRepo/"
  ScriptSourceLocation = "/path/to/MyPsRepo/"
  InstallationPolicy = "Trusted"
}
PS > Register-PSRepository @myRepoParams
PS > Copy-Item -Path "/path/to/ps-youtrack.0.0.1-alpha.nupkg" -Destination "/path/to/MyPsRepo/"
PS > Install-Module -Name "ps-youtrack" -Repository "MyPsRepo"
```

[YouTrack REST API docs](https://www.jetbrains.com/help/youtrack/devportal/youtrack-rest-api.html)
