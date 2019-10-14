# Title: MigrationTool.ps1
# Authors:
# Stevenkb42
# Purpose: 
# Remotely Migrate a user's data after a profile rebuild.
# Version: 1.00

# Create bat file to migrate data

param(
    [Parameter(Mandatory=$True,Position=1)]
    $Machine, $User, $Date, $LongDate, $ProfileLog
)

$Host.UI.RawUI.WindowTitle = "Profile Migration tool"
$ErrorActionPreference = 'SilentlyContinue'
Clear-Host

#*****Starting Fix*****
Write-Host ""
Write-Warning "DO NOT Close Window Until the Scrpt is Finished"
Write-Host ""

Write-Host "Migrating $User's profile data on $machine" -ForegroundColor Magenta
Write-Host ""

Write-Host ""
Write-Warning "DO NOT Close Window Until the Scrpt is Finished"
Write-Host ""
Pause
$LongDate = (Get-Date).ToString("yyyy.MM.dd_HHmm")

New-Item "C:\AIP\Paths.txt" -ItemType file | Out-Null
$RebuildLog = "C:\AIP\Paths.txt"

$OldProfile = 'old.' + $User + '.' + $Date

$Agent = ($env:USERNAME)
$error.clear() 
$ErrorFile = "\\ADIDBO390422\C$\AIP\Migration\$machine-MigrateErrorLog-$LongDate.txt"
Add-Content -Path $ErrorFile "`r`nFix ran by $Agent on $LongDate"

Write-Host ""
Write-Host "Starting migration" -ForegroundColor Yellow

# Importing NTUSER.DAT
Write-Host "Importing registry hive"
Robocopy.exe "\\$machine\C$\Users\$OldProfile" "C:\AIP" NTUSER.DAT `/MT:256 | Out-Null
$NTUserImp = (Test-Path 'C:\AIP\NTUSER.DAT')
If ($NTUserImp -eq $False){
    Write-Host "Unable to copy NTUSER.DAT, trying again"
    Robocopy.exe "\\$machine\C$\Users\$OldProfile" "C:\AIP" NTUSER.DAT `/MT:256 | Out-Null
    $NTUserImp2 = (Test-Path 'C:\AIP\NTUSER.DAT')
    If ($NTUserImp2 -eq $False){
        Write-Warning "Unable to copy NTUSER.DAT, will need to be copied manually."
        Write-Host 'From an Adimistrator Command window type'
        Write-Host "Robocopy.exe "\\$machine\C$\Users\$OldProfile" "C:\AIP" NTUSER.DAT" -ForegroundColor Red
        Write-Host 'then hit enter.' 
        Pause
    } Else {}
} Else {}

reg load HKLM\Temp "C:\AIP\NTUSER.DAT"
$ImportPth = (Test-Path "HKLM:\Temp")
If ( $ImportPth -eq $False ){
    Write-Host "Unable to import hive file, trying again."
    reg load HKLM\Temp "C:\AIP\NTUSER.DAT"
    $ImportPth2 = (Test-Path "HKLM:\Temp")
    If ( $ImportPth2 -eq $False ){
        Write-Warning "Unable to import hive file. Hive file will need to be manually imported."
        Write-Host 'From an Adimistrator Command window type '
        Write-Host 'regload HKLM\Temp "C:\AIP\NTUSER.DAT"' -ForegroundColor Red 
        Write-Host 'then hit enter.' 
        Pause
    } Else {}
} Else {}

# Pulling drives
Write-Host ""
Write-Host "Searching for previously mapped share drives" -ForegroundColor Yellow
$DriveMap = (Get-ItemProperty -Path HKLM:\Temp\Network\* | Select-Object -Property PSChildName, RemotePath)
ForEach ($DriveMap in $DriveMap) {
    $DriveStr = [string]$DriveMap
    $StrLength = [int]$DriveStr.Length
    $PathLength = [int]( $StrLength - 29)
    $DriveLtr = ($DriveStr.Substring(14,1))
    # Write-Host ""
    # Write-Host "Drive letter = $DriveLtr"
    $DrivePath = ($DriveStr.Substring(28, ($PathLength)))
    # Write-Host "Drive path = $DrivePath"
    Write-Host ""
    Write-Host " Found network drive $DriveLtr $DrivePath"
    Add-Content -path $RebuildLog -value "`nFound drive $DriveLtr $DrivePath"
}

# PST HKEY_LOCAL_MACHINE\Temp\Software\Microsoft\Office\16.0\Outlook\Search
# https://stackoverflow.com/questions/23800571/registry-key-to-find-pst-locations
Write-Host ""
Write-Host "Searching for previously mapped PST files" -ForegroundColor Yellow
$PstMap = (Get-ItemProperty HKLM:\Temp\Software\Microsoft\Office\16.0\Outlook\Search -Name '*.pst' )
$PstSplit = ($PstMap -split ';')
ForEach ($PstSplit in $PstSplit) { 
    $PstStr = [string] $PstSplit
    $PstLength = [int]$PstStr.Length
    $PstTrim = ($PstStr.Substring(1, ($PSTLength - 3)))
    $PstPath = ($PstTrim -replace "{", "")
    If  ($PstPath -like '*[.pst]') {
        # Write-Host ""
        # Write-Host "Pst path = $PstPath"
        Write-Host ""
        Write-Host "Found PST $PstPath"
        Add-Content -path $RebuildLog -value "`nFound pst $PstPath"
    } else {}
}

Copy-Item "C:\AIP\Paths.txt" -Destination "\\$machine\C$\Users\$User\Desktop\Paths.txt"

Write-Host ""
Write-Host "Open the Mappings.txt file on the user's desktop and remap their shaed drives, pst files" -ForegroundColor Red
        
# Data transfer
# $Source = ("C:\Users\"+$FromPath+"\Contacts"+"").ToString().Insert(0,'"');$Source+='"' $Dest = ("C:\Users"+"\Contacts").ToString().Insert(0,'"');$Dest+='"'
New-Item "\\$machine\C$\AIP\FileMigration.txt" -ItemType file -Force
$FromPath = "$OldProfile"
$Switches = "`/E `/MT:256"
$FileMigration = "\\$machine\C$\AIP\FileMigration.txt"
Add-Content $FileMigration -value "@echo off"
Add-Content $FileMigration -value "cls"
Add-Content $FileMigration -value "color 17"
Add-Content $FileMigration -value "Title File Migration"
Add-Content $FileMigration -value ""
$Desktop = 'Robocopy "C:\Users\' + $FromPath + '\Desktop" ' + '"C:\Users\' + + '\Desktop" ' + $Switches 
Add-Content $FileMigration -value $Desktop
$Favorites = 'Robocopy "C:\Users\' + $FromPath + '\Favorites" ' + '"C:\Users\' + + '\Favorites" ' + $Switches 
Add-Content $FileMigration -value $Favorites
$Contacts = 'Robocopy "C:\Users\' + $FromPath + '\Contacts" ' + '"C:\Users\' + + '\Contacts" ' + $Switches 
Add-Content $FileMigration -value $Contacts
$Chrome = 'Robocopy "C:\Users\' + $FromPath + '\AppData\Local\Google\Chrome\User Data\Default" ' + '"C:\Users\' + + '\AppData\Local\Google\Chrome\User Data\Default" ' + $Switches 
Add-Content $FileMigration -value $Chrome
$FireFox = 'Robocopy "C:\Users\' + $FromPath + '\AppData\Roaming\Mozilla\Firefox\Profiles" ' + '"C:\Users\' + + '\AppData\Roaming\Mozilla\Firefox\Profiles" ' + $Switches 
Add-Content $FileMigration -value $FireFox
$Links = 'Robocopy "C:\Users\' + $FromPath + '\Links" ' + '"C:\Users\' + + '\Links" ' + $Switches 
Add-Content $FileMigration -value $Links
$Music = 'Robocopy "C:\Users\' + $FromPath + '\Music" ' + '"C:\Users\' + + '\Music" ' + $Switches 
Add-Content $FileMigration -value $Music
$OneDrive = 'Robocopy "C:\Users\' + $FromPath + '\OneDrive" ' + '"C:\Users\' + + '\OneDrive" ' + $Switches 
Add-Content $FileMigration -value $OneDrive
$Pictures = 'Robocopy "C:\Users\' + $FromPath + '\Pictures" ' + '"C:\Users\' + + '\Pictures" ' + $Switches 
Add-Content $FileMigration -value $Pictures
$Videos = 'Robocopy "C:\Users\' + $FromPath + '\Videos" ' + '"C:\Users\' + + '\Videos" ' + $Switches 
Add-Content $FileMigration -value $Videos
$Downloads = 'Robocopy "C:\Users\' + $FromPath + '\Downloads" ' + '"C:\Users\' + + '\Downloads" ' + $Switches 
Add-Content $FileMigration -value $Downloads
$Documents = 'Robocopy "C:\Users\' + $FromPath + '\Documents" ' + '"C:\Users\' + + '\Documents" ' + $Switches 
Add-Content $FileMigration -value $Documents
Add-Content $FileMigration -value 'Pause'
Add-Content $FileMigration -value 'Verify data has transfered'
Add-Content $FileMigration -value 'DEL "%~f0"'
Move-Item -Path "\\$machine\C$\AIP\FileMigration.txt" -Destination "\\$machine\C$\Users\Desktop\$User\FileMigration.bat" -Force

Write-Host ""
Write-Warning "Ask the user to run the FileMigration.bat file on their desktop to migrate their files"

#Removing temporary files
Write-Host ""
Write-Host "Cleaning up" -ForegroundColor Yellow
Test-Path 'HKCU:\Console\%SystemRoot%_system32_cmd.exe' | Out-Null
Test-Path 'C:\Windows' | Out-Null
Start-Sleep -Seconds 30
Write-Host ""
Write-Host "Unloading Hive"
reg unload HKLM\Temp
$Test12 = (Test-Path "HKLM:\Temp" -PathType Container)
if ($Test12 -eq $True) {
    Write-Host ""
    Write-Host "Hive not removed" -ForegroundColor Red
 } else {
    Write-Host ""
    Write-Host "Hive unloaded" -ForegroundColor Green
}
Write-Host ""
Write-Host "Removing Temporary files"
Start-Sleep -Seconds 15
Remove-Item C:\AIP\NTUSER* -Force
$Test13 = (Test-Path "C:\AIP\NTUSER*")
If ($Test13 -eq $True) {
    Write-Host ""
    Write-Host "Temporary files not removed" -ForegroundColor Red
} else {
    Write-Host ""
    Write-Host "Temporary files removed" -ForegroundColor Green
}

Remove-Item "C:\AIP\Paths.txt"

Write-Host ""
Write-Host "Migration finished"

$ErrorType = $Error.exception.message 
Add-Content -Path $ErrorFile $ErrorType

Write-Host ""
Write-Host "Migration finished"
Write-Host "Hit enter to return to rebuild script"
Pause
Return
# Return to other script

