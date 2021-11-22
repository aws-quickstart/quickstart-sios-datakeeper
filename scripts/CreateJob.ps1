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
    [System.String[]]
    $SourceNames,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $SourceVols,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $SourceIPs,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $TargetNames,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $TargetVols,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $TargetIPs,

    [parameter(Mandatory = $true)]
    [System.String[]]
    $SyncTypes
)

Start-Transcript -Path "C:\cfn\log\CreateJob.ps1.log" -Append
$ErrorActionPreference = "Continue"

$tries = 120
$retryIntervalSec = 30
$job = $NULL
while ($tries -ge 1) {

    if($SyncTypes.Count -eq 3) {
        Write-Host "$env:extmirrbase\emcmd . CREATEJOB $JobName $JobDesc $($SourceNames[0]) $($SourceVols[0]) $($SourceIPs[0]) $($TargetNames[0]) $($TargetVols[0]) $($TargetIPs[0]) $($SyncTypes[0]) $($TargetNames[1]) $($TargetVols[1]) $($TargetIPs[1]) $($SourceNames[1]) $($SourceVols[1]) $($SourceIPs[1]) $($SyncTypes[0]) $($SourceNames[1]) $($SourceVols[1]) $($SourceIPs[1]) $($TargetNames[1]) $($TargetVols[1]) $($TargetIPs[1]) $($SyncTypes[1])"
        $job = & "$env:extmirrbase\emcmd" . CREATEJOB $JobName $JobDesc $SourceNames[0] $SourceVols[0] $SourceIPs[0] $TargetNames[0] $TargetVols[0] $TargetIPs[0] $SyncTypes[0] $TargetNames[0] $TargetVols[0] $TargetIPs[0] $TargetNames[1] $TargetVols[1] $TargetIPs[1] $SyncTypes[1] $SourceNames[0] $SourceVols[0] $SourceIPs[0] $TargetNames[1] $TargetVols[1] $TargetIPs[1] $SyncTypes[2]
    }
    else {
        Write-Host "$env:extmirrbase\emcmd . CREATEJOB $JobName $JobDesc $($SourceNames[0]) $($SourceVols[0]) $($SourceIPs[0]) $($TargetNames[0]) $($TargetVols[0]) $($TargetIPs[0]) $($SyncTypes[0])"
        $job = & "$env:extmirrbase\emcmd" . CREATEJOB $JobName $JobDesc $SourceNames[0] $SourceVols[0] $SourceIPs[0] $TargetNames[0] $TargetVols[0] $TargetIPs[0] $SyncTypes[0]
    }

    # normally createjob returns the job info on success, otherwise it gives 'Status = X'
    if ($?) {
        "Job created successfully"
        $job
        exit 0
    }
    else {
        "Job creation failed with code $LastExitCode, tries remaining: $tries. Retrying in $retryIntervalSec seconds ..."
        $tries--
        Start-Sleep -Seconds $retryIntervalSec
    }
}
    