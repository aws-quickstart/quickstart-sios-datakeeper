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
    $SQLServiceAccount,

    [Parameter(Mandatory=$true)]
    [string]
    $SQLServiceAccountPassword,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]
    $DomainAdminPassword,
    
    [Parameter(Mandatory=$true)]
    [String[]]
    $ClusterIPAddresses,
			
	[Parameter(Mandatory=$true)]
	[String[]]
    $ClusterSubnetCidrs
)

function toSubnetMask ($binary){
	$mask = ""
	
	for($i = 0; $i -lt 24; $i+=8) {
		$mask += [string]$([convert]::toInt32($binary.substring($i,8),2))
		$mask += "."
	}
	
	$mask += [string]$([convert]::toInt32($binary.substring(24,8),2))
	
	return $mask
}

function CidrToBinary ($cidr){
    if($cidr -le 32){
        [Int[]]$bits = (1..32)
        for($i=0;$i -lt $bits.length;$i++){
            if($bits[$i] -gt $cidr){
				$bits[$i]="0"
			} else {
				$bits[$i]="1"
			}
        }
        $cidr =$bits -join ""
    }
    return $cidr
}

function Get-SubnetMask ($IPv4cidr){
	[string[]]$cidr = $IPv4CIDR.split("/")
	return toSubnetMask( CidrToBinary( [convert]::ToInt32( $cidr[1],10 )))
}

try {
    Start-Transcript -Path "C:\cfn\log\InstallSQLEE-AddNode.ps1.txt" -Append
    $ErrorActionPreference = "Continue"

	if(-Not (Test-Path "C:\TempDB")) {
		mkdir "C:\TempDB"
	}
	
    $DomainAdminFullUser = $DomainNetBIOSName + '\' + $DomainAdminUser
    $SQLFULLServiceAccount = $DomainNetBIOSName + '\' + $SQLServiceAccount
    $DomainAdminSecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    $DomainAdminCreds = New-Object System.Management.Automation.PSCredential($DomainAdminFullUser, $DomainAdminSecurePassword)
    
    # Build strings needed for SQL silent install. The last one needs to be ip address of the node being added to the cluster.
	# Each string needs to be in the format <ipv4>;Cluster Network <int>;<4 octet subnet mask>
	# these get parsed in reverse order by the DSC module and then used as one long string.
	[string[]]$ClusterAddresses = New-Object string[] $ClusterSubnetCidrs.Length
	$mask = ""
	for($i = 0; $i -lt $ClusterSubnetCidrs.Length; $i++) {
		$mask = Get-SubnetMask($ClusterSubnetCidrs[$i])
		$ClusterAddresses[$i] = "IPv4;" + $ClusterIPAddresses[$i].split("/")[0] + ";" + "Cluster Network " + ($i + 1) + ";" + $mask
	}
    
    [bool]$isMultiSubnet = $false
    if($ClusterIPAddresses.Length -gt 1) {
        $isMultiSubnet = $true
    }
    
    [string]$Addresses = ""
    for($i = $ClusterAddresses.Length; $i -gt 0; $i--) { 
        $Addresses += "`"" + $ClusterAddresses[($i-1)] + "`" "
    }
    
	$exitcode = $NULL
    $InstallSqlPs={
        Param($DomainAdminFullUser, $SQLFULLServiceAccount, $SQLServiceAccountPassword, $isMultiSubnet, $Addresses)
        $installer = "C:\SQL2014\SETUP.EXE"
        $arguments = '/ACTION="AddNode" /SkipRules=Cluster_VerifyForErrors Cluster_IsWMIServiceOperational /ENU="True" /Q /UpdateEnabled="False" /ERRORREPORTING="False" /USEMICROSOFTUPDATE="False" /UpdateSource="MU" /HELP="False" /INDICATEPROGRESS="False" /X86="False" /INSTANCENAME="MSSQLSERVER" /SQMREPORTING="False" /FAILOVERCLUSTERGROUP="SQL Server (MSSQLSERVER)" /CONFIRMIPDEPENDENCYCHANGE=' + $isMultiSubnet + ' /FAILOVERCLUSTERIPADDRESSES=' + $Addresses + ' /FAILOVERCLUSTERNETWORKNAME="siossqlserver" /AGTSVCACCOUNT=' + $SQLFULLServiceAccount + ' /SQLSVCACCOUNT=' + $SQLFULLServiceAccount + ' /FTSVCACCOUNT="NT Service\MSSQLFDLauncher" /SQLSVCPASSWORD=' + $Using:SQLServiceAccountPassword + ' /AGTSVCPASSWORD=' + $Using:SQLServiceAccountPassword + ' /IAcceptSQLServerLicenseTerms'
        $arguments >> "C:\cfn\log\arguments.txt"
        $installResult = Start-Process $installer $arguments -Wait -ErrorAction Continue -PassThru -RedirectStandardOutput "C:\cfn\log\SQLInstallerOutput.txt" -RedirectStandardError "C:\cfn\log\SQLInstallerErrors.txt"
        $exitcode=$installResult.ExitCode
    }

    $Retries = 0
    $Installed = $false
    while (($Retries -lt 20) -and (!$Installed)) {
        try {
			if ($Retries -lt 20) {
                powershell.exe -ExecutionPolicy RemoteSigned -Command C:\cfn\scripts\EnableCredSsp.ps1
                Start-Sleep 60
            }
			$Retries++
            Invoke-Command -Authentication Credssp -Scriptblock $InstallSqlPs -ComputerName $NetBIOSName -Credential $DomainAdminCreds -ArgumentList $DomainAdminFullUser,$SQLFULLServiceAccount,$SQLServiceAccountPassword,$isMultiSubnet,$Addresses
            $Installed = $true
        }
        catch {}
    }
	
	$ErrorActionPreference = "Stop"
    if ((!$Installed) -And ($exitcode -ne $NULL)) {
		"SQL install failed with exit code $exitcode"
        throw "SQL install failed with exit code $exitcode"
    }
}
catch {
    $_ | Write-AWSQuickStartException
}
