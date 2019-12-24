<# 
.SYNOPSIS
    Logging Module. Please use "Using Module ..." to also import enumerator as well.
.DESCRIPTION
    Logging Module, logs to AppData by default and can publish full Log or filtered report to another location(eg network drive).

    #Constructor, use $SomeVariable = [logging]::new() to initialize
    #ConstructorOverload, use $SomeVariable = [logging]::new($TempPath,$Name) to initialize
    #TempPath = "$env:APPDATA\Logs"
    #Name = $($this.time).log
    #SetPath() to set Publish Path
    #SetLevel() to set Default Logging Level filter(default is INFO), 1-5 or DEBUG, INFO, WARNING, ERROR, CRITICAL
    #Log($Message). Logs message with INFO level.
    #Log($Message,$Level), Logs message with specified Level
    #PublishLog(), Publishs full log content to Path
    #PublishReport(), Publishs report log content to Path
    #GenerateReport($Level), Filters content for issues at or above the defined level.
    #EmailReport($Email,$Subject), Sends Report to $Email with $Subject as Header.

    Please use "Using Module \\internal.contoso.com\resources\scripts\Modules\Logging" to import enumerator as well.
.NOTES
    Author : Benjamin Gardner bgardner160@gmail.com
#>


Class Logging {
    [ValidatePattern('^[\w\-. ]+$')][string]$Name
    [string]$TempPath
    [string]$Path
    [string]$Time
    [LoggingLevel]$LoggingLevel
    [System.Collections.ArrayList]$Content
    [System.Collections.ArrayList]$Report

    #Constructor with default values
    Logging(){
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.Name = "$($this.Time).log"
        $this.TempPath = "$env:APPDATA\Logs\"
        $this.Path = "\\internal.contoso.com\resources\scripts\Logs\General\"
        $this.LoggingLevel = "INFO"
        $this.Content = [System.Collections.ArrayList]@()
        New-Item -Path $this.TempPath -Name $this.Name -ItemType "File" -Force
    }

    #Constructor with Specified Values
    Logging([string]$TempPath,[string]$Name){
        if(!(Test-Path $TempPath)){
            Throw "$TempPath does not exist"
        }
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.Name = $Name
        $this.TempPath = $TempPath
        $this.Path = "\\internal.contoso.com\resources\scripts\Logs\General\"
        $this.LoggingLevel = "INFO"
        $this.Content = [System.Collections.ArrayList]@()
        $this.CheckPath()
        New-Item -Path $this.TempPath -Name $this.Name -ItemType "File" -Force
    }

    #Change Publish Path
    SetPath([string]$Path){
        if(!(Test-Path $Path)){
            Throw "$Path does not exist"
        }
        $this.Path = $Path
        $this.CheckPath()
    }

    hidden CheckPath(){
        if($this.Path[-1] -ne '\'){
            $this.Path = $this.Path + '\'
        }
        if($this.TempPath[-1] -ne '\'){
            $this.TempPath = $this.TempPath + '\'
        }
    }

    #Set logging level threashold
    SetLevel([LoggingLevel]$Level){
        $this.LoggingLevel = $Level
    }

    #List log levels for user
    static [PSCustomObject] GetLevels(){
        Return ([System.Enum]::GetValues([LoggingLevel])) | Foreach-Object {[PSCustomObject]@{ValueName = $_; IntValue = [int]$_}}
    }

    #Log message with default INFO level
    Log([string]$Message){
        #Check if Logging Level is Set to allow Info(2)
        if($this.LoggingLevel -le 2){
            $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - INFO - " + $Message
            Add-Content -Path ($this.TempPath + $this.Name) -Value $Message -Force
            $this.Content.Add($Message)
        }
    }

    #Log message with log level threshold check
    Log([string]$Message,[logginglevel]$Level){
        if($Level -ge $this.LoggingLevel){
            $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - $Level - " + $Message
            Add-Content -Path ($this.TempPath + $this.Name) -Value $Message -Force
            $this.Content.Add($Message)
        }
    }

    #Push log to Path
    PublishLog(){
        Try {
            New-Item -Path $this.Path -Name $this.Name -ItemType "File" -Force
            Set-Content -Path ($this.TempPath + $this.Name) -Value $this.Content -Force
        }
        Catch{
            $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - Error - " + $Error[0]
            Add-Content -Path ($this.TempPath + $this.Name) -Value $Message -Force
        }
    }

    #Push Report to Path
    PublishReport(){
        if($this.Report.Count -gt 0){
            Try {
                New-Item -Path $this.Path -Name $this.Name -ItemType "File" -Force
                Set-Content -Path ($this.TempPath + $this.Name) -Value $this.Report -Force
            }
            Catch{
                $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - Error - " + $Error[0]
                Add-Content -Path ($this.TempPath + $this.Name) -Value $Message -Force
            }
        }
    }

    #Generate Report of logs at/above defined level
    GenerateReport($Level){
        $Levels = [System.Enum]::GetValues([LoggingLevel]) -ge $Level
        $List = [System.Collections.ArrayList]@()
        foreach($Filter in $Levels){
            if($this.Content -match $Filter){
                Foreach($Line in $this.Content){
                    $Result = $Line | Select-String "- $Filter -" -CaseSensitive
                    if($Result){
                        $List.Add($Result)
                    }
                }
            }
        }
        $this.Report = [System.Collections.ArrayList]@($List | select-object -Unique)
    }

    #Send email of report
    EmailReport([string]$Email,[string]$Subject){
        if($this.Report.Count -gt 0){
            Try{
                Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailServer
                Send-MailServer -body $this.Report -to $Email -subject $Subject
            }
            Catch{
                $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - Error - " + $Error[0]
                Add-Content -Path ($this.TempPath + $this.Name) -Value $Message -Force
            }
        }
    }
}


#Logging levels
Enum LoggingLevel
   {
      DEBUG = 1
      INFO = 2
      WARNING = 3
      ERROR = 4
      CRITICAL = 5
   }


Export-ModuleMember -Function *
