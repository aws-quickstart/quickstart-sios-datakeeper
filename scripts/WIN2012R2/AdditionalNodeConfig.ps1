[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$WSFCNodePrivateIP2,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminPassword,

    [Parameter(Mandatory=$true)]
    [string]$SQLServiceAccount,

    [Parameter(Mandatory=$true)]
    [string]$SQLServiceAccountPassword

)

# Formatting AD User to proper format for DSC Resources in this Script
$ClusterAdminUser = $DomainNetBIOSName + '\' + $DomainAdminUser
$SQLAdminUser = $DomainNetBIOSName + '\' + $SQLServiceAccount
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force)))
$SQLCredentials = (New-Object PSCredential($SQLAdminUser,(ConvertTo-SecureString $SQLServiceAccountPassword -AsPlainText -Force)))

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

Configuration AdditionalWSFCNode {
    param(
        [PSCredential] $Credentials
    )

    Import-Module -Name xFailOverCluster
    Import-Module -Name PSDscResources
    
    Import-DscResource -ModuleName xFailOverCluster
    Import-DscResource -ModuleName PSDscResources

    Node 'localhost'{

        Group Administrators {
            GroupName = 'Administrators'
            Ensure = 'Present'
            MembersToInclude = @($ClusterAdminUser, $SQLAdminUser)
        }

        WindowsFeature AddFailoverFeature {
            Ensure = 'Present'
            Name   = 'Failover-clustering'
            DependsOn = '[Group]Administrators'
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

        xWaitForCluster WaitForCluster {
            Name             = $ClusterName
            RetryIntervalSec = 10
            RetryCount       = 60
            DependsOn        = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
        }

        xCluster JoinNodeToCluster {
            Name                          = $ClusterName
            StaticIPAddress               = $WSFCNodePrivateIP2
            DomainAdministratorCredential = $Credentials
            DependsOn                     = '[xWaitForCluster]WaitForCluster'
        }
    }
}

AdditionalWSFCNode -OutputPath 'C:\AWSQuickstart\AdditionalWSFCNode' -ConfigurationData $ConfigurationData -Credentials $Credentials