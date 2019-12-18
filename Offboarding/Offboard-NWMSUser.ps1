<#
.SYNOPSIS
    Script to speed up offboarding proccess
.DESCRIPTION
    Find User
    Get Details and Groups
    Remove from Groups
    Disable User and Move OU
    Sync to Azure
    Open Word Document and Web pages to continue creation
    Export-Mailbox
    List user details
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>

. \\internal.contoso.com\resources\scripts\Modules\Mailbox.ps1
. \\internal.contoso.com\resources\scripts\Select-ADUser.ps1
. \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

$Structure = Get-Content \\internal.contoso.com\resources\scripts\Onboarding\Structure.json | ConvertFrom-Json

#DMe Keys
$apiKey = ""
$accessKeyID = ""
$secretAccessKey = ""

#Start Log
$timestamp = Get-Date -Format FileDateTime
Try{
    $logpath = "\\internal.contoso.com\resources\scripts\Logs\Offboard-NWMSUser\$($timestamp).log"
    New-Item $logpath -Force -ErrorAction Stop
}
Catch {
    $logpath = "C:\Logs\Offboard-NWMSUser\$($timestamp).log"
    New-Item $logpath -Force
}
Start-Transcript -LiteralPath $logpath
Write-Host("Logging to $logpath")

Import-Module ActiveDirectory

Do{
  $User = Select-ADUser
  $User = Get-ADUser $User.ObjectGUID -Properties *
  Write-Host "WARNING:" -ForegroundColor Yellow
  $Continue = Read-Host "Continue Offboarding with this User? $($User.DisplayName):$($User.EmployeeNumber) Y/N?"
}
Until ($Continue -match 'Y')

$OU = ($User.DistinguishedName -split ",")[1].Replace("OU=","")
$Location = $Structure.Service.'Active Directory'.ReverseOU.$OU

#Get Users Groups and Remove from each
#This has been spitting out an error so attempt workaround in catch block
Try {
    $Groups = Get-ADPrincipalGroupMembership $User.ObjectGUID | Where-Object {$_.Name -notlike "Domain Users"}
    Foreach ($Group in $Groups){
        Remove-ADGroupMember -identity $Group.objectGUID -Members $User.ObjectGUID -Verbose
    }
}
Catch {
    Write-Host "Error: $($Error[0])" -ForegroundColor Red
    Write-Host "Attempting workaround..." -ForegroundColor Magenta
    sleep 1
    $Groups = $User.MemberOf
    $User.MemberOf | ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $User.ObjectGUID -Confirm:$false}
}
Write-Host "Removing from Groups"

Write-Host 'Moving User OU and Disabling'
Set-ADUser -Identity $User.ObjectGUID -Enabled $False -Verbose
Move-ADObject -Identity $User.ObjectGUID.Guid -TargetPath "OU=Former Employees,OU=NWMS Users,DC=internal,DC=contoso,DC=com" -Verbose


Write-Host "Removing user from global address list (GAL)"
Try {
    Set-ADuser -Identity $User.ObjectGUID.Guid -Add @{msExchHideFromAddressLists="TRUE"} -Verbose
}
Catch{
    Set-ADuser -Identity $User.ObjectGUID.Guid -Replace @{msExchHideFromAddressLists="TRUE"} -Verbose
}


#Sync changes to Azure
Write-Host 'Invoking Start-ADSyncSyncCycle on NWMSVS400'
Invoke-Command -computername Server -scriptblock {Start-ADSyncSyncCycle} -Verbose -ErrorAction SilentlyContinue


#Open sites to continue user removal
If ($(Read-Host('Opening sites to continue user offboarding? Y/N')) -match 'Y'){
  [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.DealerMe.Website)?first_name=$($User.GivenName)&last_name=$($User.Surname)&active=0,1&sort=first_name_asc")
  [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.AssetTiger.Website)")
  if ($($User.Title) -match "Sales"){
      [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.DealerSocket.Website)")
      [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.KeyTrak.Website)")
      [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.VAuto.Website)")
      [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.DealerRater.Website.$($Location))")
  }
  if ($($User.Title) -match "Sales Manager" -OR $($User.Title) -match "Finance"){
      [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.CUDL.Website)")
      [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.RouteOne.Website)")
  }
}
#Open documentation sheet
Try {
  Invoke-Item "$env:UserProfile\Northwest Motorsport\IT Department - Documents\Employee Management\Employee Separation Worksheet.dotx"
}
Catch {
  Write-Host "Failed to open Employee Seperation Worksheet"
}


If($(Read-Host("Audit DealerMe Services? Y/N")) -match 'y'){
    #DMe Keys
    $apiKey = "mIBvjyNdAb6LGDrwzO7WD4P3NhDpGbQf4hAVUEf2"
    $accessKeyID = "AKIAJMXWUECDN2AQEM2Q"
    $secretAccessKey = "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"

    #Get DealerMe ID and list of user services
    $Uri = "https://api.contoso.com/user?email=$($User.UserPrincipalName)&include=services"
    $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uri -ApiKey $apiKey -AccessKeyID $AccessKeyID -SecretAccessKey $secretAccessKey).data
    #Services are a sub-object so expand to get details, rename users service id to not clash with service's id
    $DealerMeUserServices = $DealerMeUser.services.data | Select username,@{n='pivot_id';e={$_.id}} -ExpandProperty service
    $Uri = "https://api.contoso.com/user/$($DealerMeUser.id)/services"
    
    Write-Host "Services:"
    Write-Output $DealerMeUserServices | FT name,username
    pause

    #individual calls for each service.
    foreach ($Service in $DealerMeUserServices){
        #if service already exists for user then update it
        Write-Host "`nService: $($Service.name): $($Service.username)" -ForegroundColor Yellow
        if($(Read-Host ("Did you disable this service? Y/N")) -match "y"){
            $Service_Assignment_ID = $Service.pivot_id
            $UriExtension = "?action=update&active=0&service_assignment_id=$($Service_Assignment_ID)&service_id=$($Service.id)&shared=false&username=$($Service.username)"
            Write-Host "Updating $($Service.name)"
            $Result = Invoke-AwsApiCall -Uri ($Uri + $UriExtension) -ApiKey $apiKey -AccessKeyID $AccessKeyID -SecretAccessKey $secretAccessKey -RequestPayload $null -ContentType application/json -Method Post
        }
    }
}


#Write user details to host
$DataSheet = "`n`nProcedure completed for:
Selected: $($User.DisplayName)
ID: $($User.EmployeeNumber)
Title: $($User.Title)
Department: $($User.Department)
Location: $($User.StreetAddress)
Email: $($User.EmailAddress)
DN: $($User.DistinguishedName)
Groups:$(foreach ($Group in $Groups){"`n $($Group.name)"})
Services:$(foreach ($Service in $DealerMeUserServices){"`n $($Service.name) : $($Service.username)"})"
Echo $DataSheet
#save to temp
cd $env:TEMP
$DataSheet > "temp.txt"
#open temp data
invoke-item .\temp.txt


if ($(Read-Host("Export Mailbox? Y/N")) -match "y"){
    Write-Host "WARNING: Only perform one export at a time"
    $User | Export-Mailbox
    #Alert user as process takes some time.
    [console]::beep(550,500)
    Start-Sleep -milliseconds 200
    [console]::beep(550,500)
    Start-Sleep -milliseconds 200
    [console]::beep(700,800)
}

#Remove User License
If($(Read-Host('Remove License? Y/N?')) -match 'y'){
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    $license_choice = $null
    $license = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    $licenseDetail = Get-AzureADUserLicenseDetail -ObjectId $($User.UserPrincipalName)
    $license.SkuId = $licenseDetail.SkuId
    $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $licenses.AddLicenses = @()
    $licenses.RemoveLicenses = $license.SkuId
    Do{
        Try {
            Write-Host "Removing $($licenseDetail.SkuPartNumber)"
            Set-AzureADUserLicense -ObjectId "$($User.UserPrincipalName)" -AssignedLicenses $licenses -Verbose
            $SetAzureLicenseSuccess = "Yes" 
            }
        Catch {
            Write-Host "Failed:`n$($Error[0])"
            if($(Read-Host "Try Again? Y/N?") -match "N"){
                $SetAzureLicenseSuccess = "Cancel"
            }
        }
    }
    Until($SetAzureLicenseSuccess -match "Yes|Cancel")
}

#Remove Azure groups
If($(Read-Host('Remove Azure groups? Y/N?')) -match 'Y'){
    #Check if connected
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    $AzureUserId = (Get-AzureADuser -ObjectId $($User.UserPrincipalName)).ObjectId

    $AzureGroups = (Get-AzureADUserMembership -ObjectId $AzureUserId)

    Foreach ($AzureGroup in $AzureGroups){
        Write-Host "Removing $($AzureGroup.DisplayName)"
        Remove-AzureADGroupMember -ObjectId $AzureGroup.ObjectId -MemberId $AzureUserId -Verbose
    }
}

#Stop and wait for user
stop-transcript
pause
