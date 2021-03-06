#Interactive Search Function for Arrays
Function Search-Array($Array){
    $Name = $($Array | GM -MemberType NoteProperty)[0].Name
    if ($($($Array.$($Name))[0]).StartsWith("1") -eq $False){
        $i = 0
        foreach ($item in $Array){
            $i++
            $item.$($Name) = "$i. "+$item.$($Name)
            Write-Host "$($item.$($Name))"
        }
    }
    else {
        foreach ($item in $Array){
            Write-Host "$($item.$($Name))"
        }
    }
    :loop while ($true){
        $Number = $(Read-Host('Enter No. or "search"'))
        if ($Number -notmatch "^[0-9]*$" -AND $Number -notmatch "search" -AND $Number -notmatch "skip"){
            Write-Host "Invalid input"
        }
        else {
            break loop
        }
    }
    if ($Number -match 'search'){
        :loop while ($true){
            $Result = [ordered]@{}
            $Search = Read-Host ('Type search term')
            foreach ($item in $Array){
                if ($item[0] -like "*$Search*"){
                    $Result += $item
                }
            }
            if($Result.Count -ge 1){
                Write-Host $($Result | Out-String)
                $Number = $(Read-Host('Enter selection or "search" again'))
                $Max = $Array.Count
                if ($Number -in 0..$($Max)){
                    break loop
                }
                else {Write-Host 'Out of bounds'}
            }
            else{
                Write-Host "Couldn't find anything matching $Search"
                if($(Read-Host('Search again Y/N?')) -match 'n'){
                $Number = 'skip'
                break loop}
            }
        }
    }
    if ($Number -ne 'skip'){
        $Number = [int]$Number
        return $Array[$($Number-1)]
    }
}
