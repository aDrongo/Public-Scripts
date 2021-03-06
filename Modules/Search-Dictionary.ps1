#Interactive Search Function for Dictionaries
Function Search-Dictionary($Dictionary) {
    Foreach ($Key in $Dictionary.Keys){
        Write-Host "$Key $($Dictionary[$Key])"
    }
    :loop while ($true){
        $Number = $(Read-Host('Enter No. or "search" or "skip"'))
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
            foreach ($Key in $Dictionary.keys){
                $Value = $Dictionary.$($Key)[0]
                if ($Value -like "*$Search*"){
                    $Result += @{"$Key" = $Dictionary.$($Key)}
                }
            }
            if($Result.Count -ge 1){
                Write-Host $($Result | Out-String)
                $Number = $(Read-Host('Enter No. or "search"'))
                if ($Number -match "^[0-9]*$"){
                    break loop
                }
            }
            else{
                Write-Host "Couldn't find anything matching $Search"
                if($(Read-Host('Search again Y/N?')) -match 'n'){
                $Number = 'skip'
                break loop}
            }
        }
    }
    return $Number
}
