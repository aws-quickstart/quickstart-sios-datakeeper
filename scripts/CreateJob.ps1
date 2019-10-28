[CmdletBinding()]
param
(
    [parameter(Mandatory = $true)]
    [System.String]
    $JobName,
    
    [parameter(Mandatory = $true)]
    [System.String]
    $JobDesc,

    [parameter(Mandatory = $true)]
    [System.String]
    $SourceName,

    [parameter(Mandatory = $true)]
    [System.String]
    $SourceIP,

    [parameter(Mandatory = $true)]
    [System.String]
    $SourceVol,

    [parameter(Mandatory = $true)]
    [System.String]
    $TargetName,

    [parameter(Mandatory = $true)]
    [System.String]
    $TargetIP,

    [parameter(Mandatory = $true)]
    [System.String]
    $TargetVol,

    [parameter(Mandatory = $true)]
    [System.String]
    $SyncType
)

Start-Transcript -Path "C:\cfn\log\CreateJob.ps1.log" -Append
"Creating Job from $SourceName to $TargetName"

$ErrorActionPreference = "Continue"
    
$tries = 120
$retryIntervalSec = 30
$job = $NULL
while ($tries -ge 1) {
	
	$tries--
	Start-Sleep -Seconds $retryIntervalSec
	$job = & "$env:extmirrbase\emcmd" . CREATEJOB $JobName $JobDesc $SourceName $SourceVol $SourceIP $TargetName $TargetVol $TargetIP $SyncType
		
	# normally createjob returns the job info on success, otherwise it gives 'Status = X'
	if($job -ne $NULL) {
		$statusMessage = $false
		$job | foreach { if($_.Contains("Status")) {
				$statusMessage = $true
			}
		}
		if($statusMessage) {
			"Job creation failed with code $LastExitCode, tries remaining: $tries. Retrying in $retryIntervalSec seconds ..."
		} else {
			"Job created successfully"
			$tries = 0
            exit 0
		}   
	}
}
    