[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [Switch]$WS2012R2
)

"Setting up Powershell Gallery to Install DSC Modules"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

"Installing the needed Powershell DSC modules for this Quick Start"
Install-Module -Name ComputerManagementDsc -RequiredVersion 8.4.0
Install-Module -Name xFailOverCluster -RequiredVersion 1.14.1
Install-Module -Name PSDscResources -RequiredVersion 2.12.0.0
Install-Module -Name xSmbShare -RequiredVersion 2.2.0.0
Install-Module -Name xActiveDirectory

"Disabling Windows Firewall"
Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False

"Creating Directory for DSC Public Cert"
New-Item -Path C:\AWSQuickstart\publickeys -ItemType directory -Force

"Removing DSC Certificate if it already exists"
(Get-ChildItem Cert:\LocalMachine\My\) | Where-Object { $_.Subject -eq "CN=AWSQSDscEncryptCert" } | Remove-Item

If($WS2012R2) {
    Get-ChildItem -Path cert:\LocalMachine\My | Where { $_.subject -eq "CN=AWSQSDscEncryptCert" } | foreach { $_ | Remove-Item -Force }
    $cert = C:\cfn\scripts\New-SelfSignedCertificateEx -Subject "CN=AWSQSDscEncryptCert" -EKU "1.3.6.1.4.1.311.80.1" -KeySpec Exchange -KeyUsage "DataEncipherment, KeyEncipherment" -StoreLocation "LocalMachine" -ProviderName "Microsoft RSA SChannel Cryptographic Provider" -SignatureAlgorithm SHA256 -NotAfter $(Get-Date).AddYears(100) -Exportable
}
else {
    $cert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'AWSQSDscEncryptCert' -HashAlgorithm SHA256
}

# Exporting the public key certificate
$cert | Export-Certificate -FilePath "C:\AWSQuickstart\publickeys\AWSQSDscPublicKey.cer" -Force