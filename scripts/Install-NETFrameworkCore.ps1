[CmdletBinding()]
param(

)

try {
    Start-Transcript -Path C:\cfn\log\Install-NetFrameworkCore.ps1.txt -Append
    $ErrorActionPreference = "Stop"

    $Retries = 0
    $Installed = $false
	while (($Retries -lt 4) -and (!$Installed)) {
        try {
            Install-WindowsFeature NET-Framework-Core
            $Installed = $true
        }
        catch {
            $Exception = $_
            $Retries++
            if ($Retries -lt 4) {
                Start-Sleep ($Retries * 60)
            }
        }
    }
    if (!$Installed) {
          throw $Exception
    }
}
catch {
    $_ | Write-AWSQuickStartException
}
