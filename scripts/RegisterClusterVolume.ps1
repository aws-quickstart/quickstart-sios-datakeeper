[CmdletBinding()]
param
(
    [parameter(Mandatory = $true)]
    [System.String]
    $Volume
)

try {
    $logfile = "C:\cfn\log\RegisterClusterVolume.ps1.log"
    Start-Transcript -Path $logfile -Append
    "Registering cluster volume $Volume"

    $ErrorActionPreference = "Stop"
    
    $tries = 120
    $retryIntervalSec = 30
    $results = $NULL
    while ($tries -ge 1) {
        try {
            $results = & "$env:extmirrbase\emcmd" . REGISTERCLUSTERVOLUME $Volume
            if($results.Contains("Status = 0")) {
                "Volume $Volume registered with the cluster"
                break			
            } else {
                "Cluster volume registration failed with code $LastExitCode"
                "Retrying in $retryIntervalSec seconds ..."
                Start-Sleep -Seconds retryIntervalSec
            }
        }
        catch {
            $tries--
            Write-Verbose "Exception:"
            Write-Verbose "$_"
            if ($tries -lt 1) {
                throw $_
            }
            else {
                Write-Verbose "Failed Registering cluster volume. Retrying again in $retryIntervalSec seconds"
                Start-Sleep $retryIntervalSec
            }
        }
    }
    
    if($results -eq $NULL) {
		"Failed Registering cluster volume after $tries attmpts."
		throw "Failed Registering cluster volume after $tries attmpts."
	}
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
