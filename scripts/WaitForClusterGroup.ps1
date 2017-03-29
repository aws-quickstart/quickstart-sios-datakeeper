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
    Start-Transcript -Path C:\cfn\log\WaitForClusterGroup.ps1.txt -Append
    $ErrorActionPreference = "Continue"

    $DomainAdminFullUser = $DomainNetBIOSName + '\' + $DomainAdminUser
    $DomainAdminSecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    $DomainAdminCreds = New-Object System.Management.Automation.PSCredential($DomainAdminFullUser, $DomainAdminSecurePassword)

    $WaitForSQLClusterGroup={
        "`nWaiting on 'SQL Server (MSSQLSERVER)' cluster group to come online...`n"
        $tries = 240
        $retryIntervalSec = 30
		
				
        $clustergroup = $NULL
        while ($tries -ge 1) {
            try {
                "$tries Looking for cluster group"
                Start-Sleep $retryIntervalSec
                $tries--

                $clustergroup = Get-ClusterGroup -Name "SQL Server (MSSQLSERVER)"
                if ($clustergroup -ne $null)
                {
                    $state = $clustergroup.State
                    "Found clustergroup $Name with state $state"
                    
                    if($state -eq "Online") {
                        "CLUSTER GROUP ONLINE"
                        $clustergroupFound = $true
                        break;
                    } 
                } else {
                    "Cluster group not found"
                }
            }  catch {}
        }
		
		$ErrorActionPreference = "Stop"
		if($clustergroup -eq $NULL) {
			"Cluster NOT created after 120 attempts."
			throw "Cluster NOT created after 120 attempts."
		}
    }
    
    Invoke-Command -Authentication Credssp -Scriptblock $WaitForSQLClusterGroup -ComputerName $NetBIOSName -Credential $DomainAdminCreds
}
catch {
    $_ | Write-AWSQuickStartException
}
