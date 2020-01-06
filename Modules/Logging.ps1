Class Logging {
    [ValidatePattern('^[\w\-. ]+$')][string]$Name
    [string]$LocalPath
    [string]$Time
    [LoggingLevel]$LoggingLevel

    #Constructor with default values
    Logging(){
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.LoggingLevel = "INFO"
        $this.LocalPath = "$env:APPDATA\Logs\"
        $this.Name = "$($this.Time).log"
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    #TimeStamp Method
    static [String] GetTimeStamp(){
        Return $(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)
    }

    #Set logging level threshold
    SetLevel([LoggingLevel]$Level){
        $this.LoggingLevel = $Level
    }


    #Log message with default INFO level
    Log([string]$Message){
        $this.Log($Message,2)
    }

    #Log message with log level threshold check
    Log([string]$Message,[logginglevel]$Level){
        if($Level -ge $this.LoggingLevel){
            $Message = [logging]::GetTimeStamp() + " - $Level - " + $Message
            Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
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

$Logger = [logging]::new()

$Logger.log('Your log')
$Logger.log($Error[0],4)
