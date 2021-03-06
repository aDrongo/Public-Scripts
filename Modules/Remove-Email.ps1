Function Remove-Email{
    # Note: Ensure you have the Powershell Exchange Online module, you can find this by opening Microsoft Edge and going to the Exchange Online admin center, clicking hybrid and then configure for the PS module.
    # Make it possible to connect to an IPPSSession (dot load the module to EXOPPSession)
    $CreateEXOPSSession = (Get-ChildItem -Path $env:userprofile -Filter CreateExoPSSession.ps1 -Recurse -ErrorAction SilentlyContinue -Force | Select -Last 1).DirectoryName
    . "$CreateEXOPSSession\CreateExoPSSession.ps1"
    
    Connect-IPPSSession

    cls
    Write-Host "You are starting the remove-email process, please follow the below link for query syntax." -ForegroundColor Yellow
    Write-Host "https://docs.microsoft.com/en-us/sharepoint/dev/general-development/keyword-query-language-kql-syntax-reference?redirectedfrom=MSDN"
    Write-Host "Query Example: from:azure@microsoft.com AND received:Today AND subject:'Test this'"
    Write-Host "Query Example: ‘virus’ AND ‘your account closure'`n"
    $Query = Read-Host "Enter Query"
    $SearchName = Read-Host "Enter Search Name"
    
    $ComplianceSearch = New-ComplianceSearch -Name $SearchName -ExchangeLocation all -ContentMatchQuery "$Query"
    Start-ComplianceSearch -Identity $ComplianceSearch.Name -Verbose
    Do{
        Write-Host "Waiting to complete..."
        Sleep 5
    }
    Until($(Get-ComplianceSearch -Identity $ComplianceSearch.Name).Status -eq 'Completed')
    $ComplianceSearch = Get-ComplianceSearch -Identity $ComplianceSearch.Name
    Write-Output $ComplianceSearch | Select Name,ContentMatchQuery,Items,JobEndTime,RunBy,Status

    Write-Host "Found $($ComplianceSearch.Items) Occurances"
    if ($ComplianceSearch.Items -gt 0){
        if ($(Read-Host ('Do you want to review occurances? Y/N')) -match 'Y'){
            #interpret output string
            Write-Output (($ComplianceSearch.SuccessResults -split "Location:") | Select-String '[\S]+ Item count: [1-9]' -AllMatches | ForEach-Object {$_.Matches.Value})
            Write-Host ""
        }

        If($(Read-Host('Proceed with Soft Deletion? Y/N')) -match 'Y'){
            $ComplianceAction = New-ComplianceSearchAction -SearchName $ComplianceSearch.Name -Purge -PurgeType SoftDelete -Verbose
            Do{
                Write-Host "Waiting to complete..."
                Sleep 10
            }
            Until($(Get-ComplianceSearchAction -Identity $ComplianceAction.Name).Status -eq 'Completed')
            Write-Output (Get-ComplianceSearchAction -Identity $ComplianceAction.Name)
        }
    }
}
