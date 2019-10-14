# Title: ProfileRebuild.ps1
# Authors:
# Stevenkb42
# Purpose: 
# Remotely Automatically backup and delete the user's registry key and rename their user folder.
#
# Version: 1.00

<#
    .Synopsis
   This is a profile rebuild tool in powershell. Will rebuild the user's profile
  
#>
param(
    #[Parameter(Mandatory = $True, Position = 1)]
    $ScriptDir, $Machine, $User
)

$Host.UI.RawUI.WindowTitle = "Profile rebuild tool"
$ErrorActionPreference = 'SilentlyContinue'
Clear-Host
If ($Null -eq $User){
    $RebuildInfo = $ScriptDir + ", " +  $Machine
} else {$RebuildInfo = $ScriptDir + ", " +  $Machine + ", " + $User}
Write-Host $RebuildInfo
If ($Null -eq $User){
    $User = (Read-Host "What is the User's account name?")
}
If ($Null -eq $machine){
    $machine = (Read-Host "What is the User's machine name?")
}
#*****Starting Fix*****
Write-Host 'Would you like to rebuild the profile for' $User 'on' $machine '?'
$Rebuild = Read-Host '( y / n )'
Switch ($Rebuild) {  
    Y {
        Write-Host "Rebuilding $User's profile on $machine" -ForegroundColor Magenta
        Write-Host ""

        # Verify no one is logged in
        $Global:System.SID = Get-WmiObject -Class win32_computersystem -ComputerName $Global:System.machineInt |
        Select-Object -ExpandProperty Username |
        ForEach-Object { ([System.Security.Principal.NTAccount]$_).Translate([System.Security.Principal.SecurityIdentifier]).Value }
        IF ($null -eq $Global:System.SID) {
            Write-Host "Verified user is logged off" -ForegroundColor Green
        }
        Else {
            $UserPth = ([System.Security.Principal.SecurityIdentifier]($Global:System.SID)).Translate([System.Security.Principal.NTAccount]).Value
            $Global:System.User = (($UserPth -Split "\\" )[1])
            Write-Warning "System shows that " + $Global:System.User + " is logged on. Verify that the user logs off prior to continuing."
            Pause
        }
        Pause
        $Agent = ($env:USERNAME)
        $error.clear() 

        $Time = (Get-Date).ToString("HH:mm")
        $Date = (Get-Date).ToString("MM.dd.yyyy")
        $LongDate = (Get-Date).ToString("yyyy.MM.dd_HHmm")
        Set-Variable -name LogName -value "$machine-ProfileRebulld-$LongDate.txt" -Scope Global
        $ProfileLog = "\\ADIDBO390422\C$\AIP\ProfileLogs\$LogName"
        Add-Content $ProfileLog -value "Profile rebuld started on $LongDate for $User"
        Add-Content $ProfileLog "Ran by $Agent"

        # Creating AIP folder if it does not exist 
        $AIP = (Test-Path "C:\AIP")
        If ($AIP -eq $True) {
            Write-Host "AIP folder exists"
        }
        Else {
            New-Item -path "C:\" -Name "AIP" -ItemType Directory
            Write-Host "AIP folder created"
        } 
        $AIP = $Null
        $AIP = (Test-Path "\\$machine\C$\AIP")
        If ($AIP -eq $True) {
            Write-Host "AIP folder exists"
        }
        Else {
            New-Item -path "\\$machine\C$\" -Name "AIP" -ItemType Directory
            Write-Host "AIP folder created"
        } 

        # Converting user name to SID
        $objUser = New-Object System.Security.Principal.NTAccount($user)
        $SID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        Write-Host "Resolved user's sid: $SID"

        # Verifying registry key
        Write-Host "Checking for registry key" -ForegroundColor Yellow
        $reg1 = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $machine)
        $Test1 = $reg1.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID")
        If ($null -eq $Test1) {
            Write-Host ""
            Write-Host "Registry key not found for $user" -ForegroundColor Red
            Write-Host "Will move on to renaming the local folder"
            Add-Content $ProfileLog -value "Registry key not found"
            Pause
        }
        Else {
            # Backing up Key to account's desktop folder
            Copy-Item $ProfileLog -Destination "\\$machine\C$\AIP\$LogName" -force
            Write-Host ""
            Write-Host "Backing up registry key to profile's desktop" -ForegroundColor Yellow
            Invoke-Command -ComputerName $machine -ArgumentList $SID, $user, $LogName {
                Param ( $SID, $User, $LogName )
                Reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID" "C:\Users\$User\Desktop\OldKey.reg" /y
                $Test2 = (Test-Path -path "C:\Users\$User\Desktop\OldKey.reg")
                If ($Test2 -eq $True) {
                    Write-Host ""
                    Write-Host "Key was Backed up. Removing registry key" -ForegroundColor Green
                    Add-Content "C:\AIP\$LogName" -value "`r`nRegistry key was backed up"
                    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID"
                    Write-Host "Checking for registry key" -ForegroundColor Yellow
                    $reg3 = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $machine)
                    $Test3 = $reg3.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID")
                    If ($Null -ne $Test3) {
                        Write-Host ""
                        Write-Host "Failed to remove registry key" -ForegroundColor Red
                        Pause
                    }
                    Else {
                        Write-Host ""
                        Write-Host "Registry key was removed" -ForegroundColor Green
                        Add-Content "C:\AIP\$LogName" -value "`r`nProfile key was not deleted"
                    }
                }
                else {
                    Write-Host ""
                    Write-Host "Failed to back up key" -ForegroundColor Red
                    Add-Content "C:\AIP\$LogName" -value "`r`nProfile key was not backed up"
                    Pause
                    # Renaming registry key
                    Write-Host ""
                    Write-Host "Renaming registry key" -ForegroundColor Yellow
                    $Date = (Get-Date).ToString("MM.dd.yyyy")
                    $RenamedSID = "Old." + $SID + "." + $Date
                    Rename-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID" -NewName "$RenamedSID"
                    Write-Host ""
                    Write-Host "Checking key" 
                    Write-Host "Checking for registry key" -ForegroundColor Yellow
                    $reg4 = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $machine)
                    $Test4 = $reg4.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID")
                    If ($Null -ne $Test4) {
                        Write-Host ""
                        Write-Host "Key not renamed" -ForegroundColor Red
                        Write-Host "You will need to manually rename the key prior to the user logging on" -ForegroundColor Red
                        Add-Content "C:\AIP\$LogName" -value "`r`nProfile key was not renamed"
                        Pause
                    }
                    else {
                        Write-Host ""
                        Write-Host "Key renamed"-ForegroundColor Green
                        Write-Host ""
                        Write-Host "New key name:"
                        Write-Host "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$RenamedSID"
                        Add-Content "C:\AIP\$LogName" -value "`r`nProfile key was renamed to $RenamedSID"
                    }
                }
            }
        }
        Copy-Item "\\$machine\C$\AIP\$LogName" -Destination "\\ADIDBO390422\C$\AIP\ProfileLogs\$LogName" -force

        #Renaming profile
        Write-Host ""
        Write-Host "Renaming the Local Profile" -ForegroundColor Yellow
        Rename-Item -Path "\\$machine\C$\Users\$user" -NewName "old.$user.$Date"
        $Test5 = (Test-Path "\\$machine\C$\Users\$user" -PathType Container)
        If ($Test5 -eq $True) {
            Write-Host ""
            Write-Host "Unable to rename folder '\\$machine\C$\Users\old.$user.$Date'" -ForegroundColor Red
            Add-Content $ProfileLog -value "Unable to rename folder, restarting"
            Write-Host ""
            write-Host "Restarting computer to see if it can be renamed after restart"
            Write-Host "Hit Enter to start restart"
            Write-Host ""
            Write-Host "Instruct user NOT to log on after the restart" -ForegroundColor Red
            Pause
            Restart-Computer -ComputerName $machine -Wait -For PowerShell -Timeout 900 -Delay 2
            $Service = Get-Service 'ActivID Shared Store Service' -ComputerName $machine
            if ($service.Status -eq 'Running') {
                write-Host 'System is back up, attempting to rename the folder again' -ForegroundColor Green
                Rename-Item -Path "\\$machine\C$\Users\$user" -NewName "old.$user.$Date"
                $Test6 = (Test-Path "\\$machine\C$\Users\$user" -PathType Container)
                If ($Test6 -eq $True) {
                    Write-Host ""
                    Write-Host "Unable to rename folder '\\$machine\C$\Users\old.$user.$Date'" -ForegroundColor Red
                    Write-Host "Connect with UNC and attempt to manually rename the folder" -ForegroundColor Red
                    Add-Content $ProfileLog -value "Unable to rename folder, after the restart"
                    Pause
                }
                else {
                    Write-Host ""
                    Write-Host "Folder has been renamed" -ForegroundColor Green
                    Add-Content $ProfileLog -value "Folder was renamed" 
                }
            }
            else { }
        }
        Else {
            Write-Host ""
            Write-Host "Folder has been renamed" -ForegroundColor Green
            Add-Content $ProfileLog -value "Folder was renamed"
        }

        Add-Content $ProfileLog -value "Verifying issue is resolved"
        Write-Host "Have user log on and test for the error"
        Pause
        Write-host "Is the error resolved?" -ForegroundColor Yellow 
        $Readhost = Read-Host " ( y / n ) " 
        Switch ($ReadHost) { 
    
            Y {

                # Migration tool call
                
                Add-Content $ProfileLog -value "Issue is resolved"
                Write-Host "Hit enter to start migration"
                Pause

                $ArgsMen = $ScriptDir + "\MigrationTool.ps1 -Machine " + $Machine + " -User " + $User + " -Date " + $Date + " -LongDate " + $LongDate + " -ProfileLog " + $ProfileLog
                Start-Process PowerShell.exe -ArgumentList $ARGSMEN -Verbose
        
                Pause
                Write-Host "Completed, Have user verify the data is migrated"
                Write-Host "Hit Enter to exit"
                Pause
                Exit
            }   
            N {
                Write-Host "Hit enter to restore the user's old profile"
                Pause
                Write-host "Restoring profile" 
             
                # ****************Starting rebuild of old profile***********************
                Write-Host "Have the user log off" -ForegroundColor Green
                Write-Host "When the user is at the logon screen hit Enter"
                Pause

                Add-Content $ProfileLog -value "******Restoring old profile******"
                # Removing new profile key
                Write-Host ""
                Write-Host "Removing new profile registry key" -ForegroundColor Yellow
                Invoke-Command -ComputerName $machine -ArgumentList $SID, $ProfileLog {
                    Param ($SID, $ProfileLog)
                    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID"
                    $reg7 = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $machine)
                    $Test7 = $reg7.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID")
                    If ($Null -ne $Test7) {
                        Write-Host ""
                        Write-Host "Failed to remove registry key" -ForegroundColor Red
                        Write-Host "Key will need to be removed manually" -ForegroundColor Red
                        Add-Content $ProfileLog -value "Key not deleted"
                        Pause
                    }
                    Else {
                        Write-Host ""
                        Write-Host "Registry key was removed" -ForegroundColor Green
                        Add-Content $ProfileLog -value "Profile key was deleted"
                    }
                }   

                # Restoring old profile key
                Write-Host ""
                Write-Host "Restoring profile registry key" -ForegroundColor Yellow
                Invoke-Command -ComputerName $machine -ArgumentList $SID, $user, $ProfileLog, $Date {
                    Param ( $SID, $user, $ProfileLog, $Date)
                    Reg import "C:\Users\old.$User.$Date\Desktop\OldKey.reg"
                    $reg8 = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $machine)
                    $Test8 = $reg8.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID")
                    If ($Null -ne $Test8) {
                        Write-Host ""
                        Write-Host "Key was restored" -ForegroundColor Green
                        Add-Content $ProfileLog -value "Profile key was restored"
                    }
                    else {
                        Write-Host ""
                        Write-Host "Failed to restore key" -ForegroundColor Red
                        Write-Host "The key will need to be manually restored from C:\Users\old.$User.$Date"
                        Add-Content $ProfileLog -value "Profile key was not restored"
                        Pause
                    }
                }

                # Renaming new profile folder
                Write-Host ""
                Write-Host "Renaming the Local Profile" -ForegroundColor Yellow
                Rename-Item -Path "\\$machine\C$\Users\$user" -NewName "old.$user.$Date-1"
                $Test9 = (Test-Path "\\$machine\C$\Users\$user" -PathType Container)
                If ($Test9 -eq $False) {
                    Write-Host ""
                    Write-Host "Unable to rename folder "\\$machine\C$\Users\$user"" -ForegroundColor Red
                    Add-Content $ProfileLog -value "Unable to rename folder, restarting"
                    Write-Host ""
                    write-Host "Restarting computer to see if it can be renamed after restart"
                    Write-Host ""
                    Write-Host "Instruct user NOT to log on after the restart" -ForegroundColor Red
                    Pause
                    Restart-Computer -ComputerName Server01 -Wait -For PowerShell -Timeout 900 -Delay 2
                    $Service = Get-Service 'ActivID Shared Store Service' -ComputerName $machine
                    if ($service.Status -eq 'Running') {
                        write-Host 'System is back up, attempting to rename folder again' -ForegroundColor Green
                        Rename-Item -Path "\\$machine\C$\Users\$user" -NewName "old.$user.$Date-1"
                        $Test10 = (Test-Path "\\$machine\C$\Users\$user" -PathType Container)
                        If ($Test10 -eq $False) {
                            Write-Host ""
                            Write-Host "Unable to rename folder "\\$machine\C$\Users\$user"" -ForegroundColor Red
                            Write-Host "Connect with UNC and attempt to manually rename the folder" -ForegroundColor Red
                            Add-Content $ProfileLog -value "Unable to rename folder"
                            Pause
                        }
                        else {
                            Write-Host ""
                            Write-Host "Folder has been renamed" -ForegroundColor Green
                            Add-Content $ProfileLog -value "Folder was renamed" 
                        }
                    }
                    else { }
                }
                Else {
                    Write-Host ""
                    Write-Host "Folder has been renamed" -ForegroundColor Green
                    Add-Content $ProfileLog -value "Folder was renamed"
                }

                # Renaming old profile folder
                Write-Host ""
                Write-Host "Renaming the Local Profile" -ForegroundColor Yellow
                Rename-Item -Path "\\$machine\C$\Users\old.$user.$Date" -NewName "$user"
                $Test11 = (Test-Path "\\$machine\C$\Users\old.$user.$Date" -PathType Container)
                If ($Test11 -eq $False) {
                    Write-Host ""
                    Write-Host "Unable to rename folder \\$machine\C$\Users\old.$user.$Date" -ForegroundColor Red
                    Write-Host "The folder will need to be manually renamed"
                    Add-Content $ProfileLog -value "Unable to rename folder"
                    Pause
                }
                else {
                    Write-Host ""
                    Write-Host "Folder has been renamed" -ForegroundColor Green
                    Add-Content $ProfileLog -value "Folder was renamed"
                }
                Write-Host "Have the user log on and verify the profile has been restored" -ForegroundColor Yellow
            }    
        }

        Remove-Variable LogName
        $ErrorType = $Error.exception.message 
        Add-Content -Path $ErrorFile $ErrorType

        Write-Host "Finished"
        Add-Content $ProfileLog -value "Finished at $Time"
        Pause
    }
    N {
        Write-Host 'Exiting script'
        Pause
        Exit
    }

}

