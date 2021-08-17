[CmdletBinding()]
param()

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

Configuration Disk_InitializeDataDisk
{
    Import-DSCResource -ModuleName StorageDsc

    Node localhost {
        WaitForDisk Disk1 {
            DiskId = 1
            RetryIntervalSec = 60
            RetryCount = 60
        }

        Disk DVolume {
            DiskId = 1
            DriveLetter = 'D'
            PartitionStyle = 'GPT'
            FSFormat = 'NTFS'
            AllowDestructive = $true
            ClearDisk = $true
            DependsOn = '[WaitForDisk]Disk2'
        }

        WaitForDisk Disk2 {
            DiskId = 2
            RetryIntervalSec = 60
            RetryCount = 60
        }

        Disk EVolume {
            DiskId = 2
            DriveLetter = 'E'
            PartitionStyle = 'GPT'
            FSFormat = 'NTFS'
            AllowDestructive = $true
            ClearDisk = $true
            DependsOn = '[WaitForDisk]Disk2'
        }

        WaitForDisk Disk3 {
            DiskId = 3
            RetryIntervalSec = 60
            RetryCount = 60
       }

       Disk FVolume {
            DiskId = 3
            DriveLetter = 'F'
            PartitionStyle = 'GPT'
            FSFormat = 'NTFS'
            AllowDestructive = $true
            ClearDisk = $true
            DependsOn = '[WaitForDisk]Disk3'
       }
    }
}

Disk_InitializeDataDisk -OutputPath 'C:\AWSQuickstart\InitializeDisk' -ConfigurationData $ConfigurationData

Start-DscConfiguration 'C:\AWSQuickstart\InitializeDisk' -Wait -Verbose -Force