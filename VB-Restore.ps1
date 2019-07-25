
###############################################################################
# Script info     :  VEEAM Backup Automated Data Restore Test from Backup.
# Script          :  VBRestore.ps1
# Verified on     :  VEEAM Backup 9.5 or above
# Author          :  Sijo John
# Version         :  V-1.0
# Last Modified   :  25/07/2019
# The Script can be used to automate file/folder restore test from the VEEAM backup. 
# Restore test is to ensure that the data is recoverable from the backup..
# .SYNOPSIS
# Usage Example   : PS>.VB-Restore.ps1
################################################################################

Begin

{

$ContentFolder = "$PSScriptRoot\Content"
$LogFolder = "$PSScriptRoot\logs"
$today = Get-Date -Format "ddMMyyy"
$time = Get-Date

#region generate the transcript log
    #Modifying the VerbosePreference in the Function Scope
    $Start = Get-Date
    $VerbosePreference = 'SilentlyContinue'
    $TranscriptName = '{0}_{1}.log' -f $(($MyInvocation.MyCommand.Name.split('.'))[0]), $(Get-Date -Format ddMMyyyyhhmmss)
    Start-Transcript -Path "$LogFolder\$TranscriptName"
    #endregion generate the transcript log

#Edit this session

$Foldername = "D:\BackupTest\Data-Backup-Test\"             # ENTER THE FOLDER YOU WISH TO RESTORE
$Restorepath = "\\SERVER01\D$\BackupTest\"                  # ENTER THE RESTORE PATH
$Server = "SERVER01"                                        # ENTER THE NAME OF THE SERVER
$Accountname = "DOMAIN\veeam_access"                        # ENTER THE PRIVILEGED VEEAM USER ACCOUNT
$Backupname = "Main Backup"                                 # ENTER YOUR BACKUP NAME
$FromAddress = "SENDER EMAIL ADDRESS"
$ToAddress = "RECIEPIENT EMAIL ADDRESS"
$Subject = "Monthly scheduled VEEAM backup-Restore Test"
$Attachments = Get-ChildItem $LogFolder\*.* -include *.txt,*.log | Where{$_.LastWriteTime -gt (Get-Date).AddDays(-1)} #Donot Edit
$SMTPServer = "ENTER YOUR SMTP SERVER"
$SMTPPort = "ENTER YOUR SMTP PORT"
$Restorepathcheck = "\\SERVER01\D$\BackupTest\RESTORED-Data-Backup-Test"  # Since Veeam backup powershell module doesn't support copyto command ; the folder gets restored into same root folder with prefix RESTORED-Foldername. 

#Edit session ends

#Cleaning the restore directory if any previuos data exists

if (Test-Path $Restorepathcheck) {remove-item -Path $Restorepathcheck -Force -Recurse}

Write-host ("Older restored folders are deleted")


# Import required PS Modules

Add-PSSnapin VeeamPSSnapin

write-host ("Module imported successfully")

Write-Host ("Starting scheduled backup-restore test")

Write-Host ("Restoration start time $time")

$starttime = $time

Write-Host ("Searching for restorepoints")


$restorepoint = Get-VBRBackup -Name $Backupname | Get-VBRRestorePoint -Name *$Server* | Select -Last 1


$filerestore = Start-VBRWindowsFileRestore -RestorePoint $restorepoint

Write-Host ("Restorepoint successfully mounted")

Write-Host ("Searching for restoresessioninfo")

$session = Get-VBRRestoreSession | ? {$_.Id -eq $filerestore.MountSession.RestoreSessionInfo.Id}


Write-Host ("Getting credentials")

$credentials = Get-VBRCredentials -Name $Accountname

Write-Host ("Restoring files to orginal location")


Start-VBRWindowsGuestItemRestore -Path $Foldername -Session $session -RestorePolicy Keep -GuestCredentials $credentials

Write-Host ("Files successfully restored to original destination with duplicated name")

Write-Host ("Restoration complete time $time")

$completetime = $time

Write-Host ("Scheduled restore job completed successfully, please check and verify the output path $Restorepath")

Write-Host ("Verifying restored file")


$Restoredfile = Get-ChildItem "$Restorepath"| Where {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} -ErrorAction SilentlyContinue
   If ($Restoredfile.Exists) {Write-Host "Restored files verified and restore task succeeded"}
   Else {Write-Host "File does not exist/ Restore failed- Check restore logs"}

$size = 0
$size = "{0:N2} MB" -f ((gci $Restorepath -Recurse | Measure-Object -property Length -s).Sum /1MB)

  if  ($size -gt 0) {$restorestatus = "Success"; Write-Host "Success"} Else {$restorestatus = "Failed" ;Write-Host "Failed - Check logs for details"}

  $Summary = @"

   Restore test performed on Server =  $Server

   Restored folder = $Foldername

   Restore path = $Restorepath

   Restore start time = $starttime

   Restore complete time = $completetime

   Size of data restored in MB = $size

   Please find atached log report of scheduled file restoration test.

   Restore status = $restorestatus

"@

Write-Host ("$Summary")

Stop-VBRWindowsFileRestore $filerestore

Write-Host ("Gathering restore log and sending email")

$Attachments = Get-ChildItem $LogFolder\*.* -include *.txt,*.log | Where{$_.LastWriteTime -gt (Get-Date).AddMinutes(-3)}
  $body = "<p>Restore test performed on Server = $Server</p>"
  $body += "<p>Restored folder = $Foldername</p>"
  $body += "<p>Restore path = $Restorepath</p>"
  $body += "<p>Restore start time = $starttime</p>"
  $body += "<p>Restore complete time = $completetime</p>"
  $body += "<p>Size of data restored in MB = $size</p>"
  $bosy += "<p>Please find atached log report of scheduled file restoration test.</p>"
  $body += "<p>Restore status = $restorestatus</p>"

Send-Mailmessage -From $FromAddress -To $ToAddress -Subject $Subject -Attachments $Attachments -BodyAsHTML -Body "Please find atached log report of scheduled file restoration test" -Priority Normal -SmtpServer $SMTPServer -Port $SMTPPort
Write-Host "Report has been sent by E-mail to " $ToAddress " from " $FromAddress

Stop-Transcript

}