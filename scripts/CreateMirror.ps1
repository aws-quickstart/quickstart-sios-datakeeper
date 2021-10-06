[CmdletBinding()]
param
(
    [parameter(Mandatory = $true)]
    [System.String]
    $SourceIP,

    [parameter(Mandatory = $true)]
    [System.String]
    $Volume,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $TargetIPs,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $SyncTypes
)

try {
    Start-Transcript -Path "C:\cfn\log\CreateMirror.ps1.log" -Append

    $ErrorActionPreference = "Continue"

    $tries = 30
    $retryIntervalSec = 30
    $mirror = $NULL
    $mirror1 = $false
    $mirror2 = $false
    while ($tries -ge 1) {
        try {
            Write-Host "$($env:extmirrbase)\emcmd $SourceIP CREATEMIRROR $Volume $($TargetIPs[0]) $($SyncTypes[0])"
            $mirror = & "$env:extmirrbase\emcmd" $SourceIP CREATEMIRROR $Volume $TargetIPs[0] $SyncTypes[0]
            if($?) {
                "Mirror created successfully"
                $mirror1 = $true
            }
            else {
                "Mirror creation failed with code $LastExitCode, tries remaining: $tries"
                "Retrying in $retryIntervalSec seconds ..."
                $tries--
                Start-Sleep -Seconds $retryIntervalSec
            }
            if($TargetIPs.Count -gt 1) {
                Write-Host "$($env:extmirrbase)\emcmd $SourceIP CREATEMIRROR $Volume $($TargetIPs[1]) $($SyncTypes[1])"
                $mirror = & "$env:extmirrbase\emcmd" $SourceIP CREATEMIRROR $Volume $TargetIPs[1] $SyncTypes[1]

                if($?) {
                    "Mirror 2 created successfully"
                    $mirror2 = $true
                }

                if($mirror1 -And $mirror2) {
                    break
                }
            }
            else {
                if($mirror1) {
                    break
                }
            }
        }
        catch {}
    }

    $ErrorActionPreference = "Stop"
    if($mirror -eq $NULL) {
        "Mirror NOT created after $tries attempts."
        throw "Mirror NOT created after $tries attempts."
    }
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
