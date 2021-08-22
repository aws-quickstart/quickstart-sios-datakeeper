[CmdletBinding()]
param()

"Setting Execution Policy to Remote Signed"
Set-ExecutionPolicy RemoteSigned -Force

"Setting up Powershell Gallery to Install DSC Modules"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

"Installing the needed Powershell DSC modules for this Quick Start"
Install-Module -Name ComputerManagementDsc
Install-Module -Name "xFailOverCluster"
Install-Module -Name PSDscResources
Install-Module -Name "xActiveDirectory"
Install-Module -Name xSmbShare

"Disabling Windows Firewall"
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False

"Creating Directory for DSC Public Cert"
New-Item -Path C:\AWSQuickstart\publickeys -ItemType directory -Force

"Removing DSC Certificate if it already exists"
(Get-ChildItem Cert:\LocalMachine\My\) | Where-Object { $_.Subject -eq "CN=AWSQSDscEncryptCert" } | Remove-Item

"Setting up DSC Certificate to Encrypt Credentials in MOF File"
$cert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'AWSQSDscEncryptCert' -HashAlgorithm SHA256
# Exporting the public key certificate
$cert | Export-Certificate -FilePath "C:\AWSQuickstart\publickeys\AWSQSDscPublicKey.cer" -Force