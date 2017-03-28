[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]
    $NetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminPassword

)

try {
    Start-Transcript -Path C:\cfn\log\WaitForCluster.ps1.txt -Append
    $ErrorActionPreference = "Continue"

    $DomainAdminFullUser = $DomainNetBIOSName + '\' + $DomainAdminUser
    $DomainAdminSecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    $DomainAdminCreds = New-Object System.Management.Automation.PSCredential($DomainAdminFullUser, $DomainAdminSecurePassword)

    $WaitForCluster={
        "`nWaiting on cluster service to come online...`n"
        $tries = 120
        $retryIntervalSec = 30
		
        $cluster = $NULL
        while ($tries -ge 1) {
            try {
                "$tries Looking for cluster"
                Start-Sleep $retryIntervalSec
				$tries--
                $cluster = Get-Cluster
                if ($cluster -ne $null)
                {
					"Cluster Service RUNNING on this node"
                    break
				}
            }  catch [System.Exception] {}
        }
		
		$ErrorActionPreference = "Stop"
		if($cluster -eq $NULL) {
			"Cluster NOT found after 120 attempts."
			throw "Cluster NOT found after 120 attempts."
		}
    }
    
    Invoke-Command -Authentication Credssp -Scriptblock $WaitForCluster -ComputerName $NetBIOSName -Credential $DomainAdminCreds
}
catch {
    $_ | Write-AWSQuickStartException
}
