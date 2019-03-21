[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$DomainDnsName,

    [Parameter(Mandatory=$true)]
    [string]$WSFCNodePrivateIP2,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminPassword,

    [Parameter(Mandatory=$false)]
    [string]$SQLServiceAccount,

    [Parameter(Mandatory=$false)]
    [string]$SQLServiceAccountPassword,

    [Parameter(Mandatory=$false)]
    [string]$FileServerNetBIOSName

)

# Formatting AD User to proper format for DSC Resources in this Script
$ClusterAdminUser = $DomainNetBIOSName + '\' + $DomainAdminUser
$SQLAdminUser = $DomainNetBIOSName + '\' + $SQLServiceAccount
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force)))
$SQLCredentials = (New-Object PSCredential($SQLAdminUser,(ConvertTo-SecureString $SQLServiceAccountPassword -AsPlainText -Force)))

$ShareName = "\\" + $FileServerNetBIOSName + "." + $DomainDnsName + "\witness"

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}

Configuration WSFCNode1Config {
    param(
        [PSCredential] $Credentials,
        [PSCredential] $SQLCredentials
    )

    Import-Module -Name PSDscResources
    Import-Module -Name xFailOverCluster
    Import-Module -Name xActiveDirectory
    
    Import-DscResource -Module PSDscResources
    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName xActiveDirectory
    
    Node 'localhost' {
        WindowsFeature RSAT-AD-PowerShell {
            Name = 'RSAT-AD-PowerShell'
            Ensure = 'Present'
        }

        WindowsFeature AddFailoverFeature {
            Ensure = 'Present'
            Name   = 'Failover-clustering'
            DependsOn = '[WindowsFeature]RSAT-AD-PowerShell' 
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-Mgmt'
            DependsOn = '[WindowsFeature]AddFailoverFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringPowerShellFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }
        
        if ($SQLServiceAccount) {
            xADUser SQLServiceAccount {
                DomainName = $DomainDnsName
                UserName = $SQLServiceAccount
                Password = $SQLCredentials
                DisplayName = 'SQL Service Account'
                PasswordAuthentication = 'Negotiate'
                DomainAdministratorCredential = $Credentials
                Ensure = 'Present'
                DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature' 
            }
            
            Group Administrators {
                GroupName = 'Administrators'
                Ensure = 'Present'
                MembersToInclude = @($ClusterAdminUser, $SQLAdminUser)
                DependsOn = "[xADUser]SQLServiceAccount"
            }
        } else {
            Group Administrators {
                GroupName = 'Administrators'
                Ensure = 'Present'
                MembersToInclude = @($ClusterAdminUser)
            }
        }

        xCluster CreateCluster {
            Name                          =  $ClusterName
            StaticIPAddress               =  $WSFCNodePrivateIP2
            DomainAdministratorCredential =  $Credentials
            DependsOn                     = '[Group]Administrators'
        }

        xClusterQuorum 'SetQuorumToNodeAndFileShareMajority' {
            IsSingleInstance = 'Yes'
            Type             = 'NodeAndFileShareMajority'
            Resource         = $ShareName
            DependsOn        = '[xCluster]CreateCluster'
        }
    }
}
    
WSFCNode1Config -OutputPath 'C:\AWSQuickstart\WSFCNode1Config' -ConfigurationData $ConfigurationData -Credentials $Credentials -SQLCredentials $SQLCredentials
