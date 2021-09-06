[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SharePath = ''
)

try {
    Start-Transcript -Path C:\cfn\log\WSFCQuorumConfig.ps1.txt -Append

    if ($SharePath -like '') {
        Set-ClusterQuorum -NodeMajority
    }
    else {
        Set-ClusterQuorum -NodeAndFileShareMajority "$SharePath"
    }
}
catch {
    $_ | Write-AWSQuickStartException
}
finally {
    Stop-Transcript
}