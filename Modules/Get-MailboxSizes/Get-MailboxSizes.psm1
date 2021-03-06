Function Get-MailboxSizes{
    [CmdletBinding()]
    Param ()
    #Load Powershell Exchange Module, requires it to be installed via Exchange Online Center in Edge.
    $CreateEXOPSSession = (Get-ChildItem -Path $env:userprofile -Filter CreateExoPSSession.ps1 -Recurse -ErrorAction SilentlyContinue -Force | Select -Last 1).DirectoryName
    . "$CreateEXOPSSession\CreateExoPSSession.ps1"
    $password = "" | ConvertTo-SecureString -asPlainText -Force
    $username = "reporting@contoso.com"
    $credential = New-Object System.Management.Automation.PSCredential($username,$password)
    Write-Verbose "Connecting"
    Connect-EXOPSSession -Credential $credential | out-null

    $MailboxSizes = [System.Collections.ArrayList]@()

    Write-Verbose "Getting Mailboxes"
    $Mailboxes = Get-Mailbox *

    #Work through each mailbox and get statistics, if archiving is enabled get those too. Sizes need to be converted from deserialized bytes(strings). Add to Hash after all done
    Foreach ($Mailbox in $Mailboxes){
        Write-Verbose "Working $($Mailbox.DisplayName)"
        $Archive = $null
        Write-Verbose "Getting Statistics"
        $Stats = Get-MailboxStatistics $Mailbox.Guid.Guid
        Write-Verbose "Creating Hash"
        $Hash = [PSCustomObject]@{
            Name = $Stats.DisplayName
            MailboxSizeGB = [math]::Round((([int64]($Stats.TotalItemSize.Value | Out-String | Select-String -Pattern '\(\S+').Matches.Value.Replace("(",""))/1GB), 2)
            ArchiveStatus = $Mailbox.ArchiveStatus
            RetentionPolicy = $Mailbox.RetentionPolicy
        }
        if($Mailbox.ArchiveStatus -eq 'Enabled'){
            Write-Verbose "Getting Archive Detail"
            $Archive = Get-MailboxStatistics $Mailbox.Guid.Guid -Archive
            $ArchiveSize = [math]::Round((([int64]($Archive.TotalItemSize.Value | Out-String | Select-String -Pattern '\(\S+').Matches.Value.Replace("(",""))/1GB), 2)
            $Hash.add("ArchiveSizeGB", "$($ArchiveSize)") 
        }
        Write-Verbose "Adding Hash"
        $MailboxSizes.Add($Hash) | Out-Null
    }
    Write-Verbose "Sorting all"
    $MailboxSizes = $MailboxSizes | Sort MailboxSize -Descending

    Return $MailboxSizes
}

Export-ModuleMember -Function Get-MailboxSizes
