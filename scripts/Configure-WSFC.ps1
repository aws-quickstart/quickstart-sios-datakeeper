[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]
    $DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminPassword,

    [Parameter(Mandatory=$false)]
    [string]
    $WSFCNode1NetBIOSName,

    [Parameter(Mandatory=$false)]
    [string]
    $WSFCNode2NetBIOSName,

    [Parameter(Mandatory=$false)]
    [string]
    $WSFCNode3NetBIOSName=$null,

    [Parameter(Mandatory=$false)]
    [string]
    $WSFCNode1PrivateIP2,

    [Parameter(Mandatory=$false)]
    [string]
    $WSFCNode2PrivateIP2,

    [Parameter(Mandatory=$false)]
    [string]
    $WSFCNode3PrivateIP2=$null,

    [Parameter(Mandatory=$false)]
    [string]
    $NetBIOSName

)
try {
    Start-Transcript -Path C:\cfn\log\Configure-WSFC.ps1.txt -Append
    
    $DomainAdminFullUser = $DomainNetBIOSName + '\' + $DomainAdminUser
    $DomainAdminSecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    $DomainAdminCreds = New-Object System.Management.Automation.PSCredential($DomainAdminFullUser, $DomainAdminSecurePassword)
	
	$ErrorActionPreference = "Continue"
    
    $tries = 120
    $retryIntervalSec = 30
	
    $cluster = $NULL
	while ($tries -ge 1) {
		$tries--
		Start-Sleep -Seconds $retryIntervalSec
				
		$ConfigWSFCPs={
			$nodes = $Using:WSFCNode1NetBIOSName, $Using:WSFCNode2NetBIOSName
			$addr =  $Using:WSFCNode1PrivateIP2, $Using:WSFCNode2PrivateIP2
			New-Cluster -Name WSFCluster1 -Node $nodes -StaticAddress $addr -NoStorage
		}
		if ($WSFCNode3NetBIOSName) {
			$ConfigWSFCPs={
				$nodes = $Using:WSFCNode1NetBIOSName, $Using:WSFCNode2NetBIOSName, $Using:WSFCNode3NetBIOSName
				$addr =  $Using:WSFCNode1PrivateIP2, $Using:WSFCNode2PrivateIP2, $Using:WSFCNode3PrivateIP2
				New-Cluster -Name WSFCluster1 -Node $nodes -StaticAddress $addr -NoStorage
			}
		}

		$cluster = Invoke-Command -Authentication Credssp -Scriptblock $ConfigWSFCPs -ComputerName $NetBIOSName -Credential $DomainAdminCreds
		Start-Sleep 60
		if($cluster -ne $NULL) {
			"Cluster formed SUCCESSFULLY"
			break
		}
	}
	
	$ErrorActionPreference = "Stop"
	if($cluster -eq $NULL) {
		"Cluster NOT created after 120 attempts."
		throw "Cluster NOT created after 120 attempts."
	} elseif( -Not ((Get-ClusterNode).Name -Contains $NetBIOSName) ) {
		"Local node NOT ADDED TO CLUSTER, failing"
		throw "Local node NOT ADDED TO CLUSTER, failing"
	} else {
		"Node verified added to cluster"
	}
}
catch {
    $_ | Write-AWSQuickStartException
}
