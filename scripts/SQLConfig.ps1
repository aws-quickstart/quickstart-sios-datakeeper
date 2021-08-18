[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$DomainDNSName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName,

    [Parameter(Mandatory=$false)]
    [string] $ManagedAD = 'No'
)

Function Get-Domain {
	
	#Retrieve the Fully Qualified Domain Name if one is not supplied
	# division.domain.root
	if ($DomainDNSName -eq "") {
		[String]$DomainDNSName = [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain()
	}

	# Create an Array 'Item' for each item in between the '.' characters
	$FQDNArray = $DomainDNSName.split(".")
	
	# Add A Separator of ','
	$Separator = ","

	# For Each Item in the Array
	# for (CreateVar; Condition; RepeatAction)
	# for ($x is now equal to 0; while $x is less than total array length; add 1 to X
	for ($x = 0; $x -lt $FQDNArray.Length ; $x++)
		{ 

		#If it's the last item in the array don't append a ','
		if ($x -eq ($FQDNArray.Length - 1)) { $Separator = "" }
		
		# Append to $DN DC= plus the array item with a separator after
		[string]$DN += "DC=" + $FQDNArray[$x] + $Separator
		
		# continue to next item in the array
		}
	
	#return the Distinguished Name
	return $DN
}

# Getting the DSC Cert Encryption Thumbprint to Secure the MOF File
$DscCertThumbprint = (get-childitem -path cert:\LocalMachine\My | where { $_.subject -eq "CN=AWSQSDscEncryptCert" }).Thumbprint
# Getting Password from Secrets Manager for AD Admin User
$AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
$ClusterAdminUser = $DomainNetBIOSName + '\' + $AdminUser.UserName
# Creating Credential Object for Administrator
$Credentials = (New-Object PSCredential($ClusterAdminUser,(ConvertTo-SecureString $AdminUser.Password -AsPlainText -Force)))
# Getting the Name Tag of the Instance
$NameTag = (Get-EC2Tag -Filter @{ Name="resource-id";Values=(Invoke-RestMethod -Method Get -Uri http://169.254.169.254/latest/meta-data/instance-id)}| Where-Object { $_.Key -eq "Name" })
$NetBIOSName = $NameTag.Value

if ($ManagedAD -eq 'Yes'){
    $DN = Get-Domain
    $IdentityReference = $DomainNetBIOSName + "\" + $ClusterName + "$"
    $OUPath = 'OU=Computers,OU=' + $DomainNetBIOSName + "," + $DN
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName     = '*'
            CertificateFile = "C:\AWSQuickstart\publickeys\AWSQSDscPublicKey.cer"
            Thumbprint = $DscCertThumbprint
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = $NetBIOSName
        }
    )
}

Configuration SQLConfig {
    param(
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credentials
    )

    Import-Module -Name PSDesiredStateConfiguration
    Import-Module -Name ActiveDirectoryDsc
    
    Import-DscResource -Module PSDesiredStateConfiguration
    Import-DscResource -Module ActiveDirectoryDsc

    Node $AllNodes.NodeName {
        if ($ManagedAD -eq 'Yes'){
            WindowsFeature RSAT-ADDS-Tools {
                Name = 'RSAT-ADDS-Tools'
                Ensure = 'Present'
            }

            ADObjectPermissionEntry 'ADObjectPermissionEntry' {
                Ensure                             = 'Present'
                Path                               = $OUPath
                IdentityReference                  = $IdentityReference
                ActiveDirectoryRights              = 'GenericAll'
                AccessControlType                  = 'Allow'
                ObjectType                         = '00000000-0000-0000-0000-000000000000'
                ActiveDirectorySecurityInheritance = 'All'
                InheritedObjectType                = '00000000-0000-0000-0000-000000000000'
                PsDscRunAsCredential               = $Credentials
            }
        }
    }
}

SQLConfig -OutputPath 'C:\AWSQuickstart\SQLConfig' -Credentials $Credentials -ConfigurationData $ConfigurationData