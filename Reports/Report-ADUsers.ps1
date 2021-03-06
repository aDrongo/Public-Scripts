#Weekly Report

Import-Module ActiveDirectory
Import-Module \\internal.contoso.com\resources\scripts\Modules\Get-ADUsersHidden
Import-Module \\internal.contoso.com\resources\scripts\Modules\ConvertHtml
Import-Module \\internal.contoso.com\resources\scripts\Modules\Convert-OddEven
Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailContoso
Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Get-MailboxSizes
Import-Module \\internal.contoso.com\resources\scripts\Modules\Execute-Command

$HtmlParams = @"
<!DOCTYPE html>
<html><head>
<style>
body { background-color:#E5E4E2; font-family:Monospace; font-size:10pt; }
td, th { border:0px solid black; border-collapse:collapse; white-space:pre; }
th { color:white; background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px ;white-space:pre; word-wrap: break-word; }
.even {background-color: white}
.odd {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px;}
div { word-wrap: break-word;}
</style></head>
"@

$UserEnabledCount = $(Get-ADUser -Filter "Enabled -eq '$true'" -SearchBase "OU=Server Users,DC=internal,DC=contoso,DC=com").Count
$UserDisabledCount = $(Get-ADUser -Filter "Enabled -eq '$false'" -SearchBase "OU=Server Users,DC=internal,DC=contoso,DC=com").Count
$ServiceEnabledCount = $(Get-ADUser -Filter "Enabled -eq '$true'").Count - $UserEnabledCount
$UserCount = New-Object PSObject
$UserCount | Add-Member -MemberType NoteProperty -Name 'Users Enabled' -Value $UserEnabledCount
$UserCount | Add-Member -MemberType NoteProperty -Name 'Users Disabled' -Value $UserDisabledCount
$UserCount | Add-Member -MemberType NoteProperty -Name 'Services Enabled' -Value $ServiceEnabledCount

#Get Azure Licensing Sku Counts
Try{
    #Need to run this command as 64bit(jenkins runs as 32bit) so call external 64bit powershell and return output
    $EnterpriseSkuCount = Execute-Command -commandTitle "Get-AzureSkuCount" -commandPath "$($env:SystemRoot)\sysnative\WindowsPowerShell\v1.0\powershell.exe" -commandArguments '& {Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Get-AzureSkuCount; $AzureCount = Get-AzureSkuCount; Return $AzureCount | Where SkuPartNumber -match "ENTERPRISEPACK"}'
    $EnterpriseSkuCount = $EnterpriseSkuCount.stdout

    $BusinessSkuCount = Execute-Command -commandTitle "Get-AzureSkuCount" -commandPath "$($env:SystemRoot)\sysnative\WindowsPowerShell\v1.0\powershell.exe" -commandArguments '& {Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Get-AzureSkuCount; $AzureCount = Get-AzureSkuCount; Return $AzureCount | Where SkuPartNumber -match "O365_BUSINESS_ESSENTIALS"}'
    $BusinessSkuCount = $BusinessSkuCount.stdout

    $ExchangeSkuCount = Execute-Command -commandTitle "Get-AzureSkuCount" -commandPath "$($env:SystemRoot)\sysnative\WindowsPowerShell\v1.0\powershell.exe" -commandArguments '& {Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Get-AzureSkuCount; $AzureCount = Get-AzureSkuCount; Return $AzureCount | Where SkuPartNumber -match "EXCHANGESTANDARD"}'
    $ExchangeSkuCount = $ExchangeSkuCount.stdout


    #Output is a string so need to parse it
    $EnterpriseSkuCount = $EnterpriseSkuCount.Split([Environment]::NewLine)
    $EnterpriseConsumed = $($EnterpriseSkuCount | Select-String -Pattern "ConsumedUnits").ToString() -replace '[\D]*',""
    $EnterpriseEnabled = $($EnterpriseSkuCount | Select-String -Pattern "Enabled").ToString() -replace '[\D]*',""

    $BusinessSkuCount = $BusinessSkuCount.Split([Environment]::NewLine)
    $BusinessConsumed = $($BusinessSkuCount | Select-String -Pattern "ConsumedUnits").ToString() -replace '[\D]*',""
    $BusinessEnabled = $($BusinessSkuCount | Select-String -Pattern "Enabled").ToString() -replace '[\D]*',""

    $ExchangeSkuCount = $ExchangeSkuCount.Split([Environment]::NewLine)
    $ExchangeConsumed = $($ExchangeSkuCount | Select-String -Pattern "ConsumedUnits").ToString() -replace '[\D]*',""
    $ExchangeEnabled = $($ExchangeSkuCount | Select-String -Pattern "Enabled").ToString() -replace '[\D]*',""


    $UserCount | Add-Member -MemberType NoteProperty -Name "E3 Enterprise" -Value "$($EnterpriseConsumed)/$($EnterpriseEnabled)"
    $UserCount | Add-Member -MemberType NoteProperty -Name "Business Essentials" -Value "$($BusinessConsumed)/$($BusinessEnabled)"
    $UserCount | Add-Member -MemberType NoteProperty -Name "Exchange Online" -Value "$($ExchangeConsumed)/$($ExchangeEnabled)"
}
Catch{
    $UserCount | Add-Member -MemberType NoteProperty -Name 'Azure License Count' -Value "Error getting License Count"
}

$ADUsersHidden = Get-ADUsersHidden | Select Name,SamAccountName,Title,Department,LastLogonDate
if(!$ADUsersHidden){$ADUsersHidden = "None"}

$NonDisabledFormer = Get-ADUser -Filter "Enabled -eq '$true'" -SearchBase "OU=Former Employees,OU=Server Users,DC=internal,DC=contoso,DC=com" | Select Name,SamAccountName,Title,Department,LastLogonDate
if(!$NonDisabledFormer){$NonDisabledFormer = 'None'}

$OldestPasswords = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=Server Users,DC=internal,DC=contoso,DC=com" -Properties PasswordLastSet,Title,Department | Sort-Object PasswordLastSet |where-object {$_.PasswordLastSet -ne $null} | select Name,SamAccountName,Title,Department,PasswordLastSet -First 10

$LastLogonDate = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=Server Users,DC=internal,DC=contoso,DC=com" -Properties LastLogonDate,Title,Department |where-object {$_.LastLogonDate -ne $null} | Sort-Object LastLogonDate | Select Name,SamAccountName,Title,Department,LastLogonDate -First 10

$LockedAccounts = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=Server Users,DC=internal,DC=contoso,DC=com" -Properties LockedOut | Where-Object {$_.LockedOut -match 'True'} | Select Name,SamAccountName,Title,Department,LastLogonDate,PasswordLastSet,LockedOut
if(!$LockedAccounts){$LockedAccounts = 'None'}

$NeverExpires = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=Server Users,DC=internal,DC=contoso,DC=com" -Properties PasswordNeverExpires | Where-Object {$_.PasswordNeverExpires -match 'True'} | Select Name,SamAccountName,PasswordNeverExpires
if(!$NeverExpires){$NeverExpires = 'None'}

Try{
    Write-Host "Getting Mailbox"
    $MailBoxSizesHtml = Get-MailBoxSizes | Sort-Object MailboxSizeGB -Descending | Select-Object -First 5
}
Catch{
    Write-Host "Failed"
    Write-Host "$($Error[0])"
    $MailboxSizesHtml = "Failed to Get-MailboxSizes"
}

$AdminAccounts = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "DC=internal,DC=contoso,DC=com" -Properties AdminCount | Where-Object {$_.AdminCount -gt 0} | Select Name,SamAccountName,AdminCount | Add-Member -MemberType ScriptProperty -Name Groups -Value {$((Get-ADPrincipalGroupMembership $this.SamAccountName).name)} -PassThru

$body ="
$HtmlParams
<body>
<h1>AD User Report</h1>
<h3>User Counts:</h3>
$(Convert-OddEven($(ConvertHtml -intake $UserCount)))
<h3>Hidden From Address List Users:</h3>
$(Convert-OddEven($(ConvertHtml -intake $ADUsersHidden)))
<h3>Non Disabled Former Users:</h3>
$(Convert-OddEven($(ConvertHtml -intake $NonDisabledFormer)))
<h3>Oldest Passwords:</h3>
$(Convert-OddEven($(ConvertHtml -intake $OldestPasswords)))
<h3>Last Logon Date:</h3>
$(Convert-OddEven($(ConvertHtml -intake $LastLogonDate)))
<h3>Locked Accounts:</h3>
$(Convert-OddEven($(ConvertHtml -intake $LockedAccounts)))
<h3>Password Never Expires:</h3>
$(Convert-OddEven($(ConvertHtml -intake $NeverExpires)))
<h3>Top Mailbox Sizes:</h3>
$(Convert-OddEven($(ConvertHtml -intake $MailboxSizesHtml)))
<h3>Admin Counts:</h3>
$(Convert-OddEven($(ConvertHtml -intake $AdminAccounts)))
</body></html>
"

$to = "wa.west.puyallup.400.internet.it@contoso.com,it@contoso.com"
#$to = 'ben.gardner@contoso.com' # for debuging

Write-Host "Sent"
Send-MailContoso -body $body -to $to -subject "Report-ADUser"
