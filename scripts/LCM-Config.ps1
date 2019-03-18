# This block sets the LCM configuration to what we need for QS
[DSCLocalConfigurationManager()]
configuration LCMConfig
{
    Node 'localhost' {
        Settings {
            RefreshMode = 'Push'
            ActionAfterReboot = 'StopConfiguration'                      
            RebootNodeIfNeeded = $false 
        }
    }
}
    
#Generates MOF File for LCM
LCMConfig -OutputPath 'C:\AWSQuickstart\LCMConfig'
    
# Sets LCM Configuration to MOF generated in previous command
Set-DscLocalConfigurationManager -Path 'C:\AWSQuickstart\LCMConfig' 
