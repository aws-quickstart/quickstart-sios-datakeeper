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
    
    [parameter(Mandatory = $true)]
    [System.String]
    $SQLServerClusterIP,
    
    [Parameter(Mandatory=$true)]
    [System.String]
    $ClusterSubnetCidr
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
    Start-Transcript -Path "C:\cfn\log\InstallSQLEE.ps1.txt" -Append
    $ErrorActionPreference = "Continue"

    $DomainAdminFullUser = $DomainNetBIOSName + '\' + $DomainAdminUser
    $SQLFULLServiceAccount = $DomainNetBIOSName + '\' + $SQLServiceAccount
    $DomainAdminSecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    $DomainAdminCreds = New-Object System.Management.Automation.PSCredential($DomainAdminFullUser, $DomainAdminSecurePassword)

    $subnetMask = Get-SubnetMask($ClusterSubnetCidr)

    $exitcode = $NULL
    $InstallSqlPs={
        Param($DomainAdminFullUser, $SQLFULLServiceAccount, $SQLServiceAccountPassword, $SQLServerClusterIP, $subnetMask)
        $installer = "C:\SQL2014\SETUP.EXE"
        $arguments = '/Q /ACTION=InstallFailoverCluster /UpdateEnabled=False /FEATURES=SQLENGINE,REPLICATION,FULLTEXT,DQ,SSMS,ADV_SSMS /SkipRules=Cluster_VerifyForErrors Cluster_IsWMIServiceOperational /ENU=True  /ERRORREPORTING="False" /USEMICROSOFTUPDATE="False"  /UpdateSource="MU" /HELP="False" /INDICATEPROGRESS="False" /X86="False" /INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server" /INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server" /INSTANCENAME="SIOSSQLSERVER" /SQMREPORTING="False" /INSTANCEID="SIOSSQLSERVER" /SQLSVCACCOUNT=' + $SQLFULLServiceAccount + ' /SQLSVCPASSWORD=' + $Using:SQLServiceAccountPassword + ' /AGTSVCACCOUNT=' + $SQLFULLServiceAccount + ' /AGTSVCPASSWORD=' + $Using:SQLServiceAccountPassword + ' /SQLSYSADMINACCOUNTS=' + $DomainAdminFullUser + ' /FAILOVERCLUSTERIPADDRESSES="IPv4;' + $SQLServerClusterIP + ';Cluster Network 1;' + $subnetMask + '" /INSTANCEDIR="C:\Program Files\Microsoft SQL Server" /FAILOVERCLUSTERDISKS="DataKeeper Volume D" /FAILOVERCLUSTERGROUP="SQL Server (SIOSSQLSERVER)" /FAILOVERCLUSTERNETWORKNAME="siossqlserver" /COMMFABRICPORT="0" /COMMFABRICNETWORKLEVEL="0" /COMMFABRICENCRYPTION="0" /MATRIXCMBRICKCOMMPORT="0" /FILESTREAMLEVEL="0" /SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS" /INSTALLSQLDATADIR="D:" /SQLTEMPDBDIR="C:\TempDB" /FTSVCACCOUNT="NT Service\MSSQLFDLauncher" /IAcceptSQLServerLicenseTerms'
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
            Invoke-Command -Authentication Credssp -Scriptblock $InstallSqlPs -ComputerName $NetBIOSName -Credential $DomainAdminCreds -ArgumentList $DomainAdminFullUser,$SQLFULLServiceAccount,$SQLServiceAccountPassword,$SQLServerClusterIP,$subnetMask
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
