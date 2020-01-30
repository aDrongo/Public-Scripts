Using Module ..\Modules\Logging
. .\Class.ps1

$Logger = [logging]::new()
$Logger.SetPublishPath('.\Logs')
$Logger.Log('Starting Script')

#For debug
#$logger.LoggingLevel(1)

#Load Files
$Files = Get-ChildItem -LiteralPath '.\Files'
$Logger.Log("Found Files: $($Files.Name -join ',')",1)

#Load Tasks from Files
$Tasks = [System.Collections.ArrayList]@()
Foreach ($File in $Files){
    #Load Json
    Try{
        $Content = Get-Content $File.FullName | ConvertFrom-Json
        }
    Catch{
        $Logger.Log($Error[0],4)
        Continue
    }
    foreach ($Task in $Content){
        if($Task.DaysOfMonth){
            $Tasks.add([Task]::new($Task.Title,$Task.Message,$Task.Days,$Task.DaysofMonth))
            $Logger.Log("Added $Task",1)
        }
        else{
            $Tasks.add([Task]::new($Task.Title,$Task.Message,$Task.Days))
            $Logger.Log("Added $Task",1)
        }
    }
}

#Send Tickets from Tasks
Foreach ($Task in $Tasks){
    $Return = $Task.SendTicket()
    $Logger.Log("Send $Return for $($Task.Title)")
}

$Logger.PublishLog()
