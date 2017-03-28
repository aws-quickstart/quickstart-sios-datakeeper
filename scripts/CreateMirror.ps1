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
    [System.String]
    $TargetIP,

    [parameter(Mandatory = $true)]
    [System.String]
    $SyncType
)


try {
    Start-Transcript -Path "C:\cfn\log\CreateMirror.ps1.log" -Append
    "Creating Mirror from $SourceIP to $TargetIP"

    $ErrorActionPreference = "Continue"
    
    $tries = 120
    $retryIntervalSec = 30
    $mirror = $NULL
    while ($tries -ge 1) {
        try {
			$tries--
			Start-Sleep -Seconds $retryIntervalSec	
            $mirror = & "$env:extmirrbase\emcmd" $SourceIP CREATEMIRROR $Volume $TargetIP $SyncType
		
            if($mirror -ne $NULL) {
                $success = $false
                $mirror | foreach { if($_.Contains("Status = 0")) {
                        $success = $true
                    }
                }
                if($success) {
                    "Mirror created successfully"
                    break
                } else {
                    "Mirror creation failed with code $LastExitCode, tries remaining: $tries"
                    "Retrying in $retryIntervalSec seconds ..."
                }
            } else {
                "Mirror creation failed with code $LastExitCode, tries remaining: $tries"
                "Retrying in $retryIntervalSec seconds ..."
            }
        }
        catch {}
    }
    
	$ErrorActionPreference = "Stop"
    if($mirror -eq $NULL) {
		"Mirror NOT created after $tries attmpts."
		throw "Mirror NOT created after $tries attmpts."
	}
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
