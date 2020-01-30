. .\Class.ps1

#Load Files
$Files = Get-ChildItem -LiteralPath '.\Files'

#Load Tasks from Files
$Tasks = [System.Collections.ArrayList]@()
Foreach ($File in $Files){
    #Load Json
    Try{
        $Content = Get-Content $File.FullName | ConvertFrom-Json
        }
    Catch{
        $Tasks.add("Can't load $($File.Fullname)`n$Error[0]`n")
        Continue
    }
    foreach ($Task in $Content){
        $Tasks.add('-----------------------------')
        if($Task.DaysOfMonth){
            $Tasks.add([Task]::new($Task.Title,$Task.Message,$Task.Days,$Task.DaysofMonth))
        }
        else{
            $Tasks.add([Task]::new($Task.Title,$Task.Message,$Task.Days))
        }
        $Tasks.add('-----------------------------')
    }
}

cls
Write-Host $($Tasks | FL | Out-String)

pause
