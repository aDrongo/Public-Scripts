. \\internal.contoso.com\resources\scripts\Tasks\Class.ps1

cls
Write-Host "Loading..."
$Tasks = [Tasks]::new()
Write-Host "Testing..."
$Tasks.TestTickets()

pause
