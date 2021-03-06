<#
.SYNOPSIS
    Script to speed up offboarding proccess
.DESCRIPTION
    Find User
    Get Details and Groups
    Remove from Groups
    Disable User and Move OU
    Sync to Azure
    Open Web pages to continue disabling
    Create Word Document
    Export-Mailbox
    List user details
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>

Using module \\internal.contoso.com\resources\scripts\Employee\Employee.psm1
Import-Module \\internal.contoso.com\resources\scripts\Employee\WordDoc.psm1
Import-Module ActiveDirectory
. \\internal.contoso.com\resources\scripts\Modules\Mailbox.ps1
. \\internal.contoso.com\resources\scripts\Select-ADUser.ps1
. \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

$Structure = Get-Content \\internal.contoso.com\resources\scripts\Employee\Structure.json | ConvertFrom-Json

#Start Log
$timestamp = Get-Date -Format FileDateTime
Try{
    $logpath = "\\internal.contoso.com\resources\scripts\Logs\Offboard-ServerUser\$($timestamp).log"
    New-Item $logpath -Force -ErrorAction Stop
}
Catch {
    $logpath = "C:\Logs\Offboard-ServerUser\$($timestamp).log"
    New-Item $logpath -Force
}
Start-Transcript -LiteralPath $logpath
Write-Host("Logging to $logpath")

Do{
    $User = [Employee]::New()
    $User.GetADUser()
    Write-Host "WARNING" -ForegroundColor Magenta
    $Continue = Read-Host "Continue Offboarding with this User? $($User.Name):$($User.EmployeeNumber) Y/N?"
}
Until ($Continue -match 'Y')

#Get Location of User if not pulled
if(!$User.Location){
    $OU = ($User.OU -split ",")[0].Replace("OU=","")
    $Location = $Structure.Service.'Active Directory'.ReverseOU.$OU
}

#Get Users Groups and Remove
Write-Host "Removing from Groups"
$Groups = $User.RemoveGroups()

#Disable User
Write-Host 'Moving User OU and Disabling'
$User.DisableADUser()

#Sync changes to Azure
Write-Host 'Invoking Start-ADSyncSyncCycle on Server'
Invoke-Command -computername Server -scriptblock {Start-ADSyncSyncCycle} -Verbose -ErrorAction SilentlyContinue

#TODO Open websites based on Structure -> users Sercurity Group -> Services
If ($(Read-Host('Opening sites to continue user offboarding? Y/N')) -match 'Y'){
  if ($($User.Title) -match "Sales"){
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.DealerSocket.Website)")
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.VAuto.Website)")
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.DealerRater.Website.$($User.Location))")
  }
  if ($($User.Title) -match "Service"){
        [system.Diagnostics.Process]::Start("firefox","https://s15.rapidrecon.com/Server/")
  }
  if ($($User.Title) -match "Service|Sales"){
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.KeyTrak.Website)")
  }
  if ($($User.Title) -match "Sales Manager|Finance"){
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.CUDL.Website)")
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.RouteOne.Website)")
  }
  [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.AssetTiger.Website)")
}

If($(Read-Host("Audit DealerMe Services? Y/N")) -match 'y'){
    [DealerMe]::DisableServices($User)
}

If($(Read-Host("Disable DealerMe User? Y/N")) -match 'y'){
    [DealerMe]::DisableUser($User)
}

If($(Read-Host('Create Documentation Sheet? Y/N?')) -match 'y'){
    $Doc = OpenWordDoc("\\internal.contoso.com\resources\scripts\Employee\Offboarding.docx")
    $SaveFilePath = "\\Server\Employee Change Logs\Separation\$($User.Name) $(Get-Date -format yyyy-MM-dd).docx"
    ReplaceWordDocTag -Document $Doc -FindText "#Name" -ReplaceWithText $User.Name
    ReplaceWordDocTag -Document $Doc -FindText "#EMail" -ReplaceWithText $User.UserPrincipalName
    ReplaceWordDocTag -Document $Doc -FindText "#Date" -ReplaceWithText "$(Get-Date -format yyyy-MM-dd)"
    ReplaceWordDocTag -Document $Doc -FindText "#Location" -ReplaceWithText $User.Location
    SaveAsWordDoc -Document $Doc -FileName $SaveFilePath
    Invoke-Item $SaveFilePath
}

if ($(Read-Host("Export Mailbox? Y/N")) -match "y"){
    Write-Host "WARNING: Only perform one export at a time"
    Get-ADUser -Identity $User.SamAccountName | Export-Mailbox
    #Alert user as process takes some time.
    [console]::beep(550,500)
    Start-Sleep -milliseconds 200
    [console]::beep(550,500)
    Start-Sleep -milliseconds 200
    [console]::beep(700,800)
}

#Remove User License
If($(Read-Host('Remove License? Y/N?')) -match 'y'){
    [Azure]::RemoveAzureLicense($User.UserPrincipalName)
}

#Remove Azure groups
If($(Read-Host('Remove Azure groups? Y/N?')) -match 'Y'){
    [Azure]::RemoveAzureGroups($User.UserPrincipalName)
}

#Stop and wait for user
stop-transcript
pause
