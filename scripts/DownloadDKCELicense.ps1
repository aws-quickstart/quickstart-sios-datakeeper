[CmdletBinding()]
param(
    [parameter(Mandatory = $true)]
    [System.String]
    $SIOSLicenseKeyFtpURL
)

try {
    $logfile = "C:\cfn\log\DownloadDKCELicense.ps1.txt"
    Start-Transcript -Path $logfile -Append
    "Downloading DKCE license from '$SIOSLicenseKeyFtpURL'"
    
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
        $licFile = $SIOSLicenseKeyFtpURL.Substring($SIOSLicenseKeyFtpURL.LastIndexOf("/"))
        $source = $SIOSLicenseKeyFtpURL
    } else { # otherwise use the standard file name
        $licFile = "/DK-W-Cluster.lic"
        $source = $SIOSLicenseKeyFtpURL+$licFile
    }
    
    $tries = 120
    $retryIntervalSec = 30
	$extmirrsvc = $NULL
    while ($tries -ge 1) {
        try {
			Start-Sleep $retryIntervalSec
			$tries--
            
			Start-BitsTransfer -Source $source -Destination "$DestPath" -ErrorAction Stop
            Start-Service ExtMirrSvc
			
			$extmirrsvc = Get-Service ExtMirrSvc
			if(($extmirrsvc -ne $NULL) -And ($extmirrsvc.Status -eq "Running")) {
				"ExtMirrSvc is RUNNING"
				break
			}
        }
        catch {}
    }
	
	$ErrorActionPreference = "Stop"
	if($extmirrsvc -eq $NULL) {
		"ExtMirrSvc could not start after 120 attempts.`nEither the license file was not found at $SIOSLicenseKeyFtpURL, or it is invalid."
		throw "ExtMirrSvc could not start after 120 attempts.`nEither the license file was not found at $SIOSLicenseKeyFtpURL, or it is invalid."
	}
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
