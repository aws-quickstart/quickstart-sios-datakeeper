[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]
    $DirectoryID,

    [Parameter(Mandatory=$true)]
    [string]
    $AWSRegion,

    [Parameter(Mandatory=$true)]
    [string]
    $VPCCIDR
)

try {
    Start-Transcript -Path C:\cfn\log\AddDNSForward.ps1.txt -Append
    $ErrorActionPreference = "Stop"


    $CIDR = $VPCCIDR.Split('/')[0]
    $TrimmedCIDR = $CIDR.TrimEnd("0")
    $VPCDNS = $TrimmedCIDR + "2"

    New-DSConditionalForwarder -DirectoryId $DirectoryID -DnsIpAddr $VPCDNS -RemoteDomainName amazonaws.com 

}

catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}