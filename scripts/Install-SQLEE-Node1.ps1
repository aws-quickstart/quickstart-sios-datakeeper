[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$DomainDnsName,

    [Parameter(Mandatory=$true)]
    [string]$WSFCNode1PrivateIP2,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$SQLSecret

)

# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$DscCertThumbprint = (get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=AWSQSDscEncryptCert" }).Thumbprint
# Getting Password from Secrets Manager for AD Admin User
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$SQLUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $SQLSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
$SQLAdminUser = $DomainNetBIOSName + '\' + $SQLUser.UserName
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))
$SQLCredentials = (New-Object PSCredential($SQLAdminUser,(ConvertTo-SecureString $SQLUser.Password -AsPlainText -Force)))

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            CertificateFile = "C:\AWSQuickstart\publickeys\AWSQSDscPublicKey.cer"
            Thumbprint = $DscCertThumbprint
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}

Configuration SQLInstall {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlInstallCredential,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlAdministratorCredential = $SqlInstallCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlServiceCredential,

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $SqlAgentServiceCredential = $SqlServiceCredential
    )

    Import-Module -Name PSDesiredStateConfiguration
    Import-Module -Name SqlServerDsc
    
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module SqlServerDsc

    Node 'localhost'{
        #region Install prerequisites for SQL Server
        WindowsFeature 'NetFramework35'{
            Name   = 'NET-Framework-Core'
            Source = '\\fileserver.company.local\images$\Win2k12R2\Sources\Sxs' # Assumes built-in Everyone has read permission to the share and path.
            Ensure = 'Present'
        }

        WindowsFeature 'NetFramework45'{
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
        }
        #endregion Install prerequisites for SQL Server

        #region Install SQL Server Failover Cluster
        SqlSetup 'InstallSqlNode1'{
            Action                     = 'InstallFailoverCluster'
            ForceReboot                = $false
            UpdateEnabled              = 'False'
            SourcePath                 = '\\fileserver.company.local\images$\SQL2016RTM'
            SourceCredential           = $SqlInstallCredential

            InstanceName               = 'MSSQLSERVER'
            Features                   = 'SQLENGINE,Replication,FullText,Conn'

            InstallSharedDir           = 'C:\Program Files\Microsoft SQL Server'
            InstallSharedWOWDir        = 'C:\Program Files (x86)\Microsoft SQL Server'
            InstanceDir                = 'C:\Program Files\Microsoft SQL Server'

            SQLCollation               = 'SQL_Latin1_General_CP1_CI_AS'
            SQLSvcAccount              = $SqlServiceCredential
            AgtSvcAccount              = $SqlAgentServiceCredential
            SQLSysAdminAccounts        = $ClusterAdminUser, $SqlAdministratorCredential.UserName
            ASSvcAccount               = $SqlServiceCredential
            ASSysAdminAccounts         = $ClusterAdminUser, $SqlAdministratorCredential.UserName

            # Drive D: must be a shared disk.
            InstallSQLDataDir          = 'D:\MSSQL\Data'
            SQLUserDBDir               = 'D:\MSSQL\Data'
            SQLUserDBLogDir            = 'E:\MSSQL\Log'
            SQLTempDBDir               = 'F:\MSSQL\Temp'
            SQLTempDBLogDir            = 'F:\MSSQL\Temp'
            SQLBackupDir               = 'F:\MSSQL\Backup'

            FailoverClusterNetworkName = $ClusterName
            FailoverClusterIPAddress   = $WSFCNode1PrivateIP2
            FailoverClusterGroupName   = $ClusterName

            PsDscRunAsCredential       = $SqlInstallCredential

            DependsOn                  = '[WindowsFeature]NetFramework35', '[WindowsFeature]NetFramework45'
        }
    }
}
