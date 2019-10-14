# Functions

Function Set-KeyOwn {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]    
        $rootKey, $Key, $Group
    )
    process {
        $AddALM = New-Object System.Security.AccessControl.RegistryAccessRule ($Group, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $owner = [System.Security.Principal.NTAccount]$Group
        $keyLM = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($Key, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
        # Get a blank ACL since you don't have access and need ownership
        $aclLM = $keyLM.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
        $aclLM.SetOwner($owner)
        $keyLM.SetAccessControl($aclLM)
        # Get the acl and modify it
        $aclLM = $keyLM.GetAccessControl()
        $aclLM.SetAccessRule($AddALM)
        $keyLM.SetAccessControl($aclLM)
        $keyLM.Close()
    }
}

function Backup-Key {
    [CmdletBinding()]   
    Param (
        [parameter(Mandatory)]
        $machine, $SID, $NameExtract, $DoDLog, $RemoteKey, $DoDTestLog, $FullRemoteKey, $Date, $DoDLogRemote
    )
    $FullRemoteKey = $RemoteKey + $SID
    # Backing up Key to account's desktop folder
    Write-Host "Backing up registry key to profile's desktop" -ForegroundColor Yellow
    #https://www.pdq.com/blog/invoke-command-and-remote-variables/
    Invoke-Command -ComputerName $machine -ArgumentList $SID, $NameExtract {
        Param ( $SID, $NameExtract )
        Reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID" "C:\Users\$NameExtract\Desktop\OldKey.reg"
        Add-Content $DoDLog "Backed up registry key to C:\Users\$NameExtract\Desktop\OldKey.reg"
        $KeyBU = (Test-Path "C:\Users\$NameExtract\Desktop\OldKey.reg")
        If ($KeyBU -eq $True ) {
            Add-Content $DoDTestLog "Key Backed up"
            Write-Host "Key backed up, deleting key"
            Remove-Item -Path $FullRemoteKey
            $KeyDel = (Test-Path ($RemoteKey + $SID))
            if ($KeyDel -eq $true) {
                Write-Host "Key deleted"
            }
            else {
                Write-Host "Key not deleted"
                Write-Host "The registry key " + $FullRemoteKey " was not able to be deleted. Please manually delete this key."
                Pause
            }
        }
        else {
            Add-Content $DoDTestLog "Key failed to back up"
            Write-Host "Key was not backed up, renaming"
            
            Rename-key -FullRemoteKey $FullRemoteKey -machine $machine -SID $SID -RemoteKey $RemoteKey -Date $Date -DoDLogRemote $DoDLogRemote -DoDTestLog $DoDTestLog   
        }
    }          
}

function Rename-key {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        $FullRemoteKey, $machine, $SID, $RemoteKey, $Date, $DoDLogRemote, $DoDTestLog
    )
    # Renaming registry key
    Write-Host "Old key name:" 
    Write-Host $FullRemoteKey
    Invoke-Command -ComputerName $machine -ArgumentList $FullRemoteKey, $SID, $RemoteKey, $Date {
        Param ( $FullRemoteKey, $SID, $RemoteKey, $Date )
        # NOTE - Will change to deleting after testing
        # Remove-Item -Path $FullRemoteKey
        $RenamedSID = "Old." + $SID + "." + $Date
        Rename-Item -Path $FullRemoteKey -NewName "$RenamedSID"
        Write-Host "Key Check"
        $RenamedKey = $RemoteKey + $RenamedSID
        $Temp1 = (Test-Path ($RemoteKey + $SID))
        If ($Temp1 -eq $True) {
            Write-Host ""
            Write-Host "Key not renamed" -ForegroundColor Red
            Add-Content $DoDLogRemote "Failed to rename registry key"
            Add-Content $DoDTestLog "Key not renamed"
            Write-Host "The registry key " + $FullRemoteKey " was not able to be deleted. Please manually delete this key."
            Pause
        }
        else {
            Write-Host ""
            Write-Host "Key renamed"-ForegroundColor Green
            Write-Host "New key name:"
            Write-Host $RenamedKey
            Add-Content $DoDLogRemote "Renamed registry key to $RenamedKey"
            Add-Content $DoDTestLog "Key renamed to $RenamedKey"
        }
    }
}

function Rename-Profile {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        $NameExtract, $LocalProfile, $BaseKey, $SID, $machine, $Date, $DoDLog, $DoDTestLog
    )
    #Renaming profile
    Write-Host "Renaming the Local Profile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Local Profile is $NameExtract"
    $LocalProfile = (Get-ItemProperty $BaseKey + $SID -name ProfileImagePath).ProfileImagePath
    Rename-Item -Path "\\$machine\C$\Users\$NameExtract" -NewName "old.$NameExtract.$Date"
    $Temp2 = (Test-Path "\\$machine\C$\Users\$NameExtract" -PathType Container)
    If ($Temp2 -eq $True) {
        Write-Host "Unable to rename folder $LocalProfile" -ForegroundColor Red
        Add-Content $DoDLog "Unable to rename local profile C:\Users\$NameExtract"
        Add-Content $DoDTestLog "Unable to rename local profile C:\Users\$NameExtract"
        Write-Host "Unable to rename local profile C:\Users\$NameExtract. Please manually rename this folder."
        Pause
    }
    Else {
        Write-Host "Folder has been renamed" -ForegroundColor Green
        Add-Content $DoDLog "Renamed local folder to C:\Users\old.$NameExtract.$Date"
        Add-Content $DoDTestLog "Folder renamed"
    }
}

