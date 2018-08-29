[CmdletBinding()]
param(
    [parameter(Mandatory = $true)]
    [System.String]
    $SIOSLicenseKeyFtpURL
)

try {
    $logfile = "C:\cfn\log\DownloadDKCELicense.ps1.txt"
    Start-Transcript -Path $logfile -Append
    Write-Host "Downloading DKCE license from '$SIOSLicenseKeyFtpURL'`n" | % { $_ -replace ' +$','' }
    
    $ErrorActionPreference = "Continue"
    
    $DestPath = "$env:windir\SysWOW64\LKLicense"
    if(-Not (Test-Path $DestPath)) {
        New-Item "$DestPath" -Type directory -Force
    }
    
    # check to see if the user pasted in a different license file, and preserve it's name / use it
    # this also works if the user navigated to the link first and pasted in the full file path url 
    $licFile = ""
    $source = ""
    if($SIOSLicenseKeyFtpURL.EndsWith(".lic")) {
        $licFile = $SIOSLicenseKeyFtpURL.Substring($SIOSLicenseKeyFtpURL.LastIndexOf("/") + 1)
        $source = $SIOSLicenseKeyFtpURL
    } elseif($SIOSLicenseKeyFtpURL.EndsWith("/")) {
        $licFile = "DK-W-Cluster.lic"
        $source = "$SIOSLicenseKeyFtpURL$licFile"
    } else {
        $licFile = "DK-W-Cluster.lic"
        $source = "$SIOSLicenseKeyFtpURL/$licFile"
    }
    
    # user passed in an s3 uri, so we're going to need the aws cli installed
    if($source -Like "s3://*") {
        Start-BitsTransfer -Source "https://s3.amazonaws.com/aws-cli/AWSCLI64.msi" -Destination "$env:SystemDrive\AWSCLI64.msi" -ErrorAction Stop 
        msiexec.exe /i "$env:SystemDrive\AWSCLI64.msi" /qn
        
        $awscmd = "$env:ProgramW6432\Amazon\AWSCLI\aws.exe"
        # wait on the aws cli installer
        $tries = 30
        $retryIntervalSec = 10
        While ( $tries -ge 1 -And -Not (Test-Path -Path $awscmd)) {
            Start-Sleep $retryIntervalSec
            $tries--
        }
    }
    
    $tries = 120
    $retryIntervalSec = 30
    $extmirrsvc = $NULL
    while ($tries -ge 1) {
        try {
            Write-Host "Downloading the license file from $source to $DestPath\$licFile"
            if($source -Like "s3://*") {
                $results = & "$awscmd" s3 cp $source "$DestPath\$licFile"
                Write-Host $results
            } else {
                Start-BitsTransfer -Source $source -Destination "$DestPath" -ErrorAction Stop
            }
            
            Start-Service ExtMirrSvc
            
            $extmirrsvc = Get-Service ExtMirrSvc
            if(($extmirrsvc -ne $NULL) -And ($extmirrsvc.Status -eq "Running")) {
                "ExtMirrSvc is RUNNING"
                break
            }
            Start-Sleep $retryIntervalSec
            $tries--
        }
        catch {}
    }
    
    $ErrorActionPreference = "Stop"
    if($extmirrsvc -eq $NULL) {
        Write-Host "ExtMirrSvc could not start after 120 attempts.`nEither the license file was not found at $SIOSLicenseKeyFtpURL, or it is invalid."
        throw "ExtMirrSvc could not start after 120 attempts.`nEither the license file was not found at $SIOSLicenseKeyFtpURL, or it is invalid."
    }
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
