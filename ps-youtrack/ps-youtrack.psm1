# Copyright (c) 2025 Bryan Cuneo

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

$script:_client = $null

class YouTrackApiClient {
    [ValidateNotNullOrEmpty()] [string]$BaseUrl
    hidden [ValidateNotNullOrEmpty()] [string]$PermanentToken
    hidden [hashtable]$AuthorizationHeader

    # Throw human-readable errors if the class is initialized with the wrong number of arguments
    YouTrackApiClient() { throw [System.ArgumentException] 'Please provide both a $BaseUrl and a $PermanentToken' }
    YouTrackApiClient([string]$s) { $this.YouTrackApiClient() }
    YouTrackApiClient([securestring]$ss) { $this.YouTrackApiClient() }

    # Accept $PermanentToken as a regular string, or convert from a securestring. securestring is not actually very
    # secure, but it's used by Get-Credential which is how I expect to be storing the token on disk.
    YouTrackApiClient([string]$BaseUrl, [securestring]$PermanentToken) {
        $this.Init(@{
                BaseUrl        = $BaseUrl
                PermanentToken = ConvertFrom-SecureString -AsPlainText $PermanentToken
            })
    }
    YouTrackApiClient([string]$BaseUrl, [string]$PermanentToken) {
        $this.Init(@{BaseUrl = $BaseUrl; PermanentToken = $PermanentToken })
    }

    hidden [void] Init([hashtable]$Properties) {
        foreach ($p in $Properties.Keys) {
            $this.$p = $Properties.$p
        }

        $this.AuthorizationHeader = @{
            "Authorization" = "Bearer $($this.PermanentToken)"
        }

        $this.TestConnection()
    }

    # Save ourselves some typing for each API request with these wrapper methods
    [object] InvokeApi([string]$Method, [string]$Endpoint, [hashtable]$Parameters) {
        if (-not $Endpoint) {
            throw [System.ArgumentNullException] '$Endpoint cannot be null or an empty string'
        } else {
            $Endpoint = $Endpoint.Trim().Trim("/")
        }

        if ($Method -notin [System.Enum]::GetValues([Microsoft.PowerShell.Commands.WebRequestMethod])) {
            throw [System.ArgumentNullException] '$Method must be a valid web request method'
        }

        if ($Parameters) {
            $params = "?"
            foreach ($p in $Parameters.GetEnumerator()) {
                $params += "$($p.Key)=$($p.Value)&"
            }
        } else {
            $params = ""
        }

        $req = @{
            Uri     = [Uri]::EscapeUriString("$($this.BaseUrl)/$Endpoint$($params.TrimEnd("&"))")
            Method  = $Method
            Headers = $this.AuthorizationHeader + @{
                "Content-Type" = "application/json"
                "Accept"       = "application/json"
            }
        }

        return Invoke-RestMethod @req
    }

    [object] InvokeApiGet([string]$Endpoint, [hashtable]$Parameters) {
        return $this.InvokeApi("Get", $Endpoint, $Parameters)
    }

    [object] InvokeApiPost([string]$Endpoint, [hashtable]$Parameters) {
        return InvokeApi("Post", $Endpoint, $Parameters)
    }

    hidden [void] TestConnection() {
        try {
            $This.InvokeApiGet("/users/me", $null) | Out-Null
        } catch {
            throw "Unable to connect to the YouTrack API: $_"
        }
    }

    [object] GetIssues([string]$Query, [string[]]$Fields) {
        $req_params = @{
            "query"  = $Query
            "fields" = $Fields -join ","
        }

        return $this.InvokeApiGet("/issues", $req_params)
    }

    [string] ToString() {
        return "Base Url: $($this.BaseUrl)`nPermanent token:$($this.PermanentToken -replace ".(?=.{4})", "*")"
    }
}

function Test-Client {
    if ($null -eq $_client) {
        throw [System.InvalidOperationException]::new(
            "The YouTrack API client has not been initialized. Please run 'New-YtClient'.")
    }
}

function New-YtClient {
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [securestring]$PermanentToken
    )

    $script:_client = [YouTrackApiClient]::new($BaseUrl.Trim().TrimEnd("/"), $PermanentToken)
}

function Get-YtIssues {
    param(
        [Parameter(Mandatory, ParameterSetName = "General", Position = 0)]
        [string]$Query,

        [Parameter(Mandatory, ParameterSetName = "ForMe", Position = 0)]
        [switch]$ForMe,

        [string[]]$Fields
    )

    Test-Client

    if ($ForMe) {
        $Query = "for:me"
    }

    return $script:_client.GetIssues($Query, $Fields)
}

Export-ModuleMember -Function New-YtClient, Get-YtIssues
