$Path = "$($env:USERPROFILE)\AppData\Local\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets"

$Items = Get-ChildItem -Path $Path | Where-Object {$_.Length -gt 100000}

if(!(Test-Path "$($env:USERPROFILE)\Pictures\Spotlight\")){
    New-Item -ItemType Directory "$($env:USERPROFILE)\Pictures\Spotlight" -Force
}

$Items | Foreach {Copy-Item -Path $_.FullName -Destination  "$($env:USERPROFILE)\Pictures\Spotlight\$($_.Name).jpg" -Force}
