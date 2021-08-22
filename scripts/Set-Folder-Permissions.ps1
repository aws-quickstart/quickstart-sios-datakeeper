[CmdletBinding()]
param(

    [Parameter(Mandatory=$true)]
    [string]$DomainNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminUser,

    [Parameter(Mandatory=$true)]
    [string]$DomainAdminPassword,

    [Parameter(Mandatory=$true)]
    [string]$FileServerNetBIOSName,

    [Parameter(Mandatory=$true)]
    [string]$AdminSecret,

    [Parameter(Mandatory=$true)]
    [string]$SQLSecret,

    [Parameter(Mandatory=$true)]
    [string]$ClusterName

)

Try{
    Start-Transcript -Path C:\cfn\log\Set-Folder-Permissions.ps1.txt -Append
    $ErrorActionPreference = "Stop"

    # Getting Password from Secrets Manager for AD Admin User
    $AdminUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $AdminSecret).SecretString
    $SQLUser = ConvertFrom-Json -InputObject (Get-SECSecretValue -SecretId $SQLSecret).SecretString
    $SQLServiceAccount = $SQLUser.username
    $DomainAdminFullUser = $DomainNetBIOSName + '\' + $AdminUser.username
    # Creating Credential Object for Administrator
    $DomainAdminCreds = (New-Object PSCredential($DomainAdminFullUser,(ConvertTo-SecureString $AdminUser.password -AsPlainText -Force)))

    $SetPermissions={
        $ErrorActionPreference = "Stop"
        $timeoutMinutes=30
        $intervalMinutes=1
        $elapsedMinutes = 0.0
        $startTime = Get-Date
        $stabilized = $false

        While (($elapsedMinutes -lt $timeoutMinutes)) {
            Try {
                $acl = Get-Acl C:\witness
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule( $Using:obj, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
                $acl.AddAccessRule($rule)
                Set-Acl C:\witness $acl
                $stabilized = $true
                break
            } 
            Catch {
                Start-Sleep -Seconds $($intervalMinutes * 60)
                $elapsedMinutes = ($(Get-Date) - $startTime).TotalMinutes
            }
        }

        if ($stabilized -eq $false) {
            Throw "Item did not propgate within the timeout of $Timeout minutes"
        }

    }

    $obj = "$($DomainNetBIOSName)\$($ClusterName)$"
    Invoke-Command -ScriptBlock $SetPermissions -ComputerName $FileServerNetBIOSName -Credential $DomainAdminCreds

    $obj = "$($DomainNetBIOSName)\$($SQLServiceAccount)"
    Invoke-Command -ScriptBlock $SetPermissions -ComputerName $FileServerNetBIOSName -Credential $DomainAdminCreds

}
Catch {
    $_ | Write-AWSQuickStartException
}
Finally {
    Stop-Transcript
}   
