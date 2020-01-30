#Task
class Task {
    [string]$Title
    [string]$Message
    [System.Array]$Days = @()
    [System.Array]$DaysofMonth = @()

    #Constructor with specified details
    Task([string]$Title,[string]$Message,$Days){
        $this.Initialize($Title,$Message,$Days)
    }

    #Constructor overload with Days of Month
    Task([string]$Title,[string]$Message,$Days,$DaysofMonth){
        [ValidateScript({$_ -in (1 .. 31)})]$DaysofMonth
        $this.Initialize($Title,$Message,$Days)
        foreach ($Day in $DaysofMonth){
            $this.DaysofMonth += $Day
        }
    }

    #Method used by Constructor
    hidden Initialize($Title,$Message,$Days){
        $this.Title = $Title
        $this.Message = ([string]$Message).Insert(0,"#category Task`n")
        if ($Message -notmatch '#due'){
            $this.Message = $this.Message.Insert(0,"#due in 8 hours`n")
        }
        if ($Days -eq 'All' -or $Days -eq 7){
            $this.Days += [System.DayOfWeek].GetEnumNames()
        }
        else{
            foreach ($Day in $Days){
                $this.Days += [System.DayOfWeek]$Day
            }
        }
    }

    #Method to Send Ticket.
    [boolean] SendTicket(){
        Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailPlainServer
        if ((Get-Date).DayOfWeek -in $this.Days){
            #If Days of Month specified, check if Day matches
            if ($this.DaysOfMonth.Count -gt 0){
                if ((Get-Date).Date -notin $this.DaysofMonth){
                    #Day doesn't match
                    return $False
                }
            }
            #Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailPlainServer
            Send-MailServer -body $this.Message -to 'help@contoso.on.spiceworks.com'  -subject $this.Title
            return $True
        }
        return $False
    }
}
