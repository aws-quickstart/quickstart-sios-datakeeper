[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SharePath = ''
)

# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$DscCertThumbprint = (get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=AWSQSDscEncryptCert" }).Thumbprint

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

Configuration WSFCQuorumConfig {
    param()

    Import-Module -Name PSDscResources
    Import-Module -Name xFailOverCluster

    Import-DscResource -Module PSDscResources
    Import-DscResource -ModuleName xFailOverCluster
    
    Node 'localhost' {
        if($SharePath -eq '') {
            xClusterQuorum 'SetQuorumToNodeMajority' {
                IsSingleInstance = 'Yes'
                Type             = 'NodeMajority'
            }
        }
        else {
            xClusterQuorum 'SetQuorumToNodeAndFileShareMajority' {
                IsSingleInstance = 'Yes'
                Type             = 'NodeAndFileShareMajority'
                Resource         = $SharePath
            }
        }
    }
}

WSFCQuorumConfig -OutputPath 'C:\AWSQuickstart\WSFCQuorumConfig' -ConfigurationData $ConfigurationData
