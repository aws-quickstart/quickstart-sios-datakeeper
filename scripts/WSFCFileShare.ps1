[CmdletBinding()]
param()

# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$DscCertThumbprint = (get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=AWSQSDscEncryptCert" }).Thumbprint

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            CertificateFile = "C:\AWSQuickstart\publickeys\AWSQSDscEncryptCert.cer"
            Thumbprint = $DscCertThumbprint
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = 'localhost'
        }
    )
}

Configuration WSFCFileServer {

    Import-Module -Name xSmbShare 
    Import-Module -Name PSDscResources
    
    Import-DscResource -ModuleName xSmbShare
    Import-DscResource -ModuleName PSDscResources

    Node 'localhost' {

        WindowsFeature FileServices {
            Ensure = 'Present'
            Name   = 'File-Services'
        }

        File WitnessFolder {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = 'C:\witness'
        }

        xSmbShare WitnessShare {
            Ensure     = 'Present'
            Name       = 'witness'
            Path       = 'C:\witness'
            FullAccess = 'Everyone'
            DependsOn  = '[File]WitnessFolder'
        }
    }
}

WSFCFileServer -OutputPath 'C:\AWSQuickstart\WSFCFileServer' -ConfigurationData $ConfigurationData

Start-DscConfiguration 'C:\AWSQuickstart\WSFCFileServer' -Wait -Verbose -Force