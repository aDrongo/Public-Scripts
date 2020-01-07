class Employee {
    [ValidatePattern("^\D+$")][string]$GivenName
    [ValidatePattern("^\D+$")][string]$Surname
    [ValidatePattern("^[0-9]*$")][string]$EmployeeNumber
    [string]$Mobile #[ValidatePattern("^[0-9]{3}-[0-9]{3}-[0-9]{4}$")]
    [string]$Name
    [string]$SamAccountName
    [string]$UserPrincipalName
    [string]$Department
    [string]$Title
    [string]$StreetAddress
    [string]$State
    [string]$OfficePhone
    [string]$Location
    [string]$OU
    [string]$GUID
    [string]$License
    [string]$Security
    [object]$Services

    Employee(){
    }
    
    Employee([string]$GivenName, [string]$Surname){
        $this.GivenName = $GivenName
        $this.Surname = $Surname
        $this.CreateSamName()
    }

    Employee([string]$GivenName, [string]$Surname, [string]$EmployeeNumber){
        $this.GivenName = $GivenName
        $this.Surname = $Surname
        $this.EmployeeNumber = $EmployeeNumber
        $this.CreateSamName()
    }


    Employee([string]$GivenName, [string]$Surname, [string]$EmployeeNumber, [string]$Mobile){
        $this.GivenName = $GivenName
        $this.Surname = $Surname
        $this.EmployeeNumber = $EmployeeNumber
        $this.Mobile = $Mobile
        $this.CreateSamName()
    }

    CreateSamName(){
        $this.Name = $this.GivenName + ' ' + $this.Surname
        $this.SamAccountName = ($this.GivenName + '.' + $this.Surname.replace(' ','')).ToLower()
        $this.UserPrincipalName = $this.SamAccountName + "@contoso.com"
    }

    [object] static FindADUser(){
    $UserFound = $False
    $User = $Null
    Do{
        $UserInput = Read-Host "Enter User"
        $Users = @()
        Try{
            $Users += Get-ADUser -Identity $UserInput -Properties EmployeeNumber -ErrorAction Stop
        }
        Catch{
            $UserInput = "*" + $UserInput + "*"
            $Users += Get-ADUser -Filter {Name -like $UserInput} -Properties EmployeeNumber -ErrorAction SilentlyContinue
        }
        if($Users.Count -ge 1){
            $i = 0
            $Table = @()
            foreach ($User in $Users){
                $Table += New-Object -TypeName PSObject -Property @{
                    Index = $i
                    Name = $User.Name
                    Employee = $User.EmployeeNumber
                    Enabled = $User.Enabled
                }
                $i++
            }
            $Table += New-Object -TypeName PSObject -Property @{
                    Index = $i
                    Name = 'None'
            }
            Write-Host ($Table | Out-String)
            Do{
                Try{
                    $UserInput = [int](Read-Host "Select Index")
                }
                Catch{
                    Write-Host "Please enter a number"
                }
            }
            Until($Userinput -in (0 .. $Users.Count))
            if($UserInput -ne ($Users.Count)){
                $User = $Users[$UserInput]
                $UserFound = $True
            }
        }
        Else{
            Write-Host "No Users Found" -ForegroundColor Red
        }
    }
    Until($UserFound)

    return $User
    }

    GetADUser(){
        $User = [Employee]::FindADUser()
        $this.GetADUser($User)
    }

    GetADUser([Object]$User){
        Try{
            $User = Get-ADUser -identity $User -ErrorAction Stop
            }
        Catch{
            $User = [Employee]::FindADUser()
        }
        $User = $User | Get-ADUser -properties Department,Title,StreetAddress,State,OfficePhone,extensionAttribute2,extensionAttribute4,EmployeeNumber,MobilePhone -ErrorAction Stop
        $this.SamAccountName = $User.SamAccountName
        $this.UserPrincipalName = $User.UserPrincipalName
        $this.Name = $User.Name
        $this.GivenName = $User.GivenName
        $this.Surname = $User.Surname
        $this.Department = $User.Department
        $this.Title = $User.Title
        $this.StreetAddress = $User.StreetAddress
        $this.State = $User.State
        $this.OfficePhone = $User.OfficePhone
        $this.GUID = $User.ObjectGUID
        $this.OU = $($User.DistinguishedName -split "," | select -skip 1) -join ','
        $this.Location = $User.extensionAttribute2
        $this.Security = $User.extensionAttribute4
        $this.EmployeeNumber = $User.EmployeeNumber
        $this.Mobile = $User.MobilePhone
    }

    CreateADUser([System.Security.SecureString]$Password){
        function ExistingUser($Sam){
            Try{
                Get-ADUser -Identity $Sam
                Return $true
            }
            Catch{
                Return $false
            }
        }
        $this.Name = $this.GivenName + ' ' + $this.Surname
        $this.SamAccountName = ($this.GivenName + '.' + $this.Surname.replace(' ','')).ToLower()
        if(ExistingUser($this.SamAccountName)){
            $Sam = $null
            Do{($Sam = $(Read-Host 'User already exists, select another SamAccountName'))}
            Until(!(ExistingUser($Sam)))
            $this.SamAccountName = $Sam
            $this.UserPrincipalName = $this.SamAccountName + "@contoso.com"
        }
        $hash = @{
            'SamAccountName' = $this.SamAccountName
            'UserPrincipalName' = $this.UserPrincipalName
            'Name' = $this.Name
            'DisplayName' = $this.Name
            'GivenName' = $this.GivenName
            'Surname' = $this.Surname
            'MobilePhone' = $this.Mobile
            'Path' = $this.OU
            'AccountPassword' = $Password
            'ChangePasswordAtLogon' = $True
            'Enabled' = $True
        }
        New-ADUser @hash -verbose
    }

    EnableADUser([System.Security.SecureString]$Password){
        if($this.SamAccountName -notmatch "[\w]+"){
            Throw "Please add user SamAccountName"
        }
        if($this.OU -notmatch "[\w]+"){
            Throw "Please add user OU first with GetOU()"
        }
        if($this.GUID -notmatch "[\w]+"){
            Throw "Please run get user first with GetADUser()"
        }
        $hash = @{
            'Identity' = $this.SamAccountName
            'ChangePasswordAtLogon' = $True
            'Enabled' = $True
        }
        Set-ADAccountPassword -Identity $this.SamAccountName -NewPassword $Password
        Set-ADUser @hash -verbose
        Set-ADuser -Identity $this.SamAccountName -Replace @{msExchHideFromAddressLists="FALSE"} -verbose -ErrorAction SilentlyContinue
        Move-ADObject -Identity $this.GUID -TargetPath $this.OU
    }

    TransferADUser(){
        if($this.OU -notmatch "[\w]+"){
            Throw "Please add OU with AddOU()"
        }
        if($this.GUID.Length -ne 36){
            Throw "Please add GUID with GetADUser()"
        }
        Move-ADObject -Identity $this.GUID -TargetPath $this.OU -Verbose
    }

    DisableADUser(){
        if($this.GUID -notmatch "[\w]+"){
            Throw "Please run GetADUser first"
        }
        Set-ADUser -Identity $this.GUID -Enabled $False -Verbose
        Move-ADObject -Identity $this.GUID -TargetPath "OU=Former Employees,OU=Server Users,DC=internal,DC=contoso,DC=com" -Verbose
        Try {
            Set-ADuser -Identity $this.GUID -Add @{msExchHideFromAddressLists="TRUE"} -Verbose
        }
        Catch{
            Set-ADuser -Identity $this.GUID -Replace @{msExchHideFromAddressLists="TRUE"} -Verbose
        }
    }

    AddLocation(){
        $this.Location = Read-Host "What is the Users location?"
    }

    AddLocation($Object){
        Write-Host "Please enter the matching index for their Location"
        $I = 0
        Foreach ($Item in $Object){
            $I++ 
            Write-Host "$I $($Item)"
        }
        $LocationIndex = $Null
        Do{
            [int]$LocationIndex = Read-Host "Index"
        }
        Until($LocationIndex -in 1 .. $($Object).Count)
        $this.Location = $Object[$($LocationIndex - 1)]
    }
 
    AddOU(){
    $this.OU = "OU=$(Read-Host('Enter OU')),OU=Server Users,DC=internal,DC=contoso,DC=com"
    }

    AddOU($Service){
    $this.OU = "OU=$($Service.$($this.Location)),OU=Server Users,DC=internal,DC=contoso,DC=com"
    }

    AddPosition(){
        $this.Title = Read-Host 'Enter Title'
        $this.Security = Read-Host 'Enter Security Group'
    }

    AddPosition($Object){
        Write-Host "Please enter the matching index for their Title or 'skip' for manual creation"
        $I = 0
        $TitleIndex = $null
        Foreach ($Item in $Object){
            $I++ 
            Write-Host "$I $($Item.Title)"
        }
        Do{ 
            [int]$TitleIndex = Read-Host "Index"
        }
        Until($TitleIndex -in 1 .. $($Object).Count -OR $TitleIndex -match "skip")
        if ($TitleIndex -notmatch "skip"){
            $this.Title = ($Object[$($TitleIndex - 1)]).Title
            $this.Security = ($Object[$($TitleIndex - 1)]).Security
            $this.Services = ($Object[$($TitleIndex - 1)]).Services
            $this.License = ($Object[$($TitleIndex - 1)]).License
        }
        Else{
            $this.Title = Read-Host 'Enter Title'
            $this.Security = Read-Host 'Enter Security Group'
        }
    }

    [Array] AddGroups($Object){
        $Groups = @()
        if($this.Location -notmatch "[\w]+"){
            Throw "Please add user location first with AddLocation()"
        }
        if($this.Security -notmatch "[\w]+"){
            Throw "Please add user security first with AddPosition()"
        }
        $DistributionGroup = $Object.AddressGroup.$($this.location) +" "+ $Object.DepartmentGroup.$($this.Security)
        Try{
            Add-ADGroupMember -Identity $this.Security -Members $this.SamAccountName -Verbose
            $Groups += $this.Security
        }
        Catch{
            $MissingGroup = (Get-ADObject -LDAPFilter "(cn=$($this.Security)*)" -SearchBase 'OU=Server Groups,DC=internal,DC=contoso,DC=com').ObjectGuid.Guid
            Add-ADGroupMember -Identity $MissingGroup -Members $this.SamAccountName -Verbose
        }
        Add-ADGroupMember -Identity $DistributionGroup -Members $this.SamAccountName -Verbose
        $Groups += $DistributionGroup
        Return $Groups
    }

    [Array] RemoveGroups(){
        $UserGroups = (Get-ADUser -Identity $this.SamAccountName -Properties MemberOf).MemberOf
        $RemovedGroups = @()
        Write-Host "Removing Groups, please confirm" -ForegroundColor Yellow
        Foreach ($UserGroup in $UserGroups){
            Remove-ADGroupMember -Identity $UserGroup -Members $this.SamAccountName
            $RemovedGroups += ($UserGroup -split ",")[0]
        }
        Return $RemovedGroups
    }

    SyncADUserFromDealerMe(){
        . \\internal.contoso.com\resources\scripts\Modules\SyncADUserFromDealerMe.ps1
        Sync-ADUserFromDealerMe -ADUser $(Get-ADUser -identity $this.SamAccountName)
    }

    AddDealerMeUser([boolean]$CreditEnabled,[boolean]$Visibility,[boolean]$MobileVisible,[int]$location_id,[int]$department_id){
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

        #DMe Keys
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON

        #Uri base
        $Uribase = "https://api.contoso.com/user"

        #Uri extension to submit Post
        $UriExtension = `
            "?action=add&"`
            +"active=1&"`
            +"credit_enabled=$([int]$CreditEnabled)&"`
            +"crm_email=$($this.SamAccountName)@app.contoso.com&"`
            +"department_id=$($department_id)&"`
            +"email=$($this.UserPrincipalName)&"`
            +"external_id=$($this.EmployeeNumber)&"`
            +"first_name=$($this.GivenName)&"`
            +'languages=["en"]&'`
            +"last_name=$($this.Surname)&"`
            +"ldapEnabled=0&"`
            +"location_id=$($location_id)&"`
            +"mobile_number_visible=$([int]$MobileVisible)&"`
            +"phone=$($this.Mobile)&"`
            +"title=$($this.Title)&"`
            +"user_name=$($this.GivenName)-$($this.Surname)&"`
            +"visible=$([int]$Visibility)"

        #TODO Alphabetically add?
        #Add roles if Title matches
        $(if ($this.Security -match 'IT'){
            Write-Host "Add Roles 1 & 2 manually"
            #$UriExtension = $UriExtension + "&role=[1,2]"
        })
        $(if ($this.Security -match 'Buyer'){
            Write-Host "Add Role 7 manually"
            #$UriExtension = $UriExtension + "&role=7"
        })
    
        #Submit API Call
        Invoke-AwsApiCall -Uri ($Uribase + $UriExtension) -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $null -ContentType application/json -Method Post
    }

    EnableDealerMeUser(){
        if(!$this.UserPrincipalName){
            Throw "Missing UserPrincipalName, please create or get user first"
        }
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1
        #DMe Keys        
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON

        #Get DealerMe ID and list of user services
        $Uribase = "https://api.contoso.com/user?email=$($this.UserPrincipalName)&active=1,0"
        $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        if(!$DealerMeUser){ Throw "User not found"}

        #Uri base
        $Uribase = "https://api.contoso.com/user/$($DealerMeUser.id)"

        #Payload
        $RequestPayload = @{
            "active" = 1
        }


        #Add roles if Title matches
        $(if ($this.Security -match 'IT'){
            Write-Host "Add Roles 1 & 2 manually"
            #$UriExtension = $UriExtension + "&role=[1,2]"
        })
        $(if ($this.Security -match 'Buyer'){
            Write-Host "Add Role 7 manually"
            #$UriExtension = $UriExtension + "&role=7"
        })
    
        $RequestPayload = $RequestPayload | ConvertTo-Json

        Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $RequestPayload -ContentType application/json -Method Patch
    }


    EnableDealerMeUser([boolean]$CreditEnabled,[boolean]$Visibility,[boolean]$MobileVisible,[int]$location_id,[int]$department_id){
        if(!$this.UserPrincipalName){
            Throw "Missing UserPrincipalName, please create user first"
        }
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

        #DMe Keys
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON

        #Get DealerMe ID and list of user services
        $Uribase = "https://api.contoso.com/user?email=$($this.UserPrincipalName)&active=1,0"
        $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        if(!$DealerMeUser){ Throw "User not found"}

        #Uri base
        $Uribase = "https://api.contoso.com/user/$($DealerMeUser.id)"

        #Payload
        $RequestPayload = @{
            "active"= 1
            "ldapEnabled"= 0
            "credit_enabled"= $([int]$CreditEnabled)
            "visible"= $([int]$Visibility)
            "mobile_number_visible"= $([int]$MobileVisible)
            "first_name"= "$($this.GivenName)"
            "last_name"= "$($this.Surname)"
            "nick_name"= "$($this.Name)"
            "title"= "$($this.Title)"
            "external_id"= "$($this.EmployeeNumber)"
            "phone"= "$($this.Mobile)"
            "email"= "$($this.thisPrincipalName)"
            "crm_email"= "$($this.SamAccountName)@app.contoso.com"
            "location_id"= $([int]$location_id)
            "department_id"=$([int]$department_id)
            "languages"= '["en"]'
        }

        #Add roles if Title matches
        $(if ($this.Security -match 'IT'){
            Write-Host "Add Roles 1 & 2 manually"
            #$UriExtension = $UriExtension + "&role=[1,2]"
        })
        $(if ($this.Security -match 'Buyer'){
            Write-Host "Add Role 7 manually"
            #$UriExtension = $UriExtension + "&role=7"
        })

        $RequestPayload = $RequestPayload | ConvertTo-Json

        Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $RequestPayload -ContentType application/json -Method Patch
    }

   TransferDealerMeUser([int]$location_id,[int]$department_id){
        if(!$this.UserPrincipalName){
            Throw "Missing UserPrincipalName, please create user first"
        }
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

        #DMe Keys
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON

        #Get DealerMe ID and list of user services
        $Uribase = "https://api.contoso.com/user?email=$($this.UserPrincipalName)"
        $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        if(!$DealerMeUser){ Throw "User not found"}

        #Uri base
        $Uribase = "https://api.contoso.com/user/$($DealerMeUser.id)"

        #Payload
        $RequestPayload = @{
            "location_id"= $([int]$location_id)
            "department_id"=$([int]$department_id)
            "title"= "$($this.Title)"
        }

        $RequestPayload = $RequestPayload | ConvertTo-Json

        Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $RequestPayload -ContentType application/json -Method Patch
    }

    DisableDealerMeUser(){
        if(!$this.UserPrincipalName){
            Throw "Missing UserPrincipalName, please create user first"
        }
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

        #DMe Keys
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON

        #Get DealerMe ID and list of user services
        $Uribase = "https://api.contoso.com/user?email=$($this.UserPrincipalName)"
        $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        if(!$DealerMeUser){ Throw "User not found"}

        #Uri base
        $Uribase = "https://api.contoso.com/user/$($DealerMeUser.id)"

        #Payload
        $RequestPayload = @{
            "active"= 0
        }

        $RequestPayload = $RequestPayload | ConvertTo-Json

        Invoke-AwsApiCall -Uri $Uribase -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $RequestPayload -ContentType application/json -Method Patch
    }

    AddDealerMeServices(){
        if(($this.Services).count -eq 0){
            Throw "Please add user services first with GetTitle()"
        }
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1
        #DMe Keys
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON

        #Get DealerMe ID and list of user services
        $Uri = "https://api.contoso.com/user?email=$($this.UserPrincipalName)&include=services"
        $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uri -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        if(!$DealerMeUser){ Throw "User not found"}
        #Services are a sub-object so expand to get details, rename users service id to not clash with service's id
        $DealerMeUserServices = $DealerMeUser.services.data | Select username,@{n='pivot_id';e={$_.id}} -ExpandProperty service
        #Get DealerMe Services list, need IDs for any new services to add to user
        $Uri = "https://api.contoso.com/user_service?limit=100"
        $DealerMeServices = (Invoke-AwsApiCall -Uri $Uri -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        #Get Services for users Title, then match DealerMe Services to get IDs
        $UserServices = $DealerMeServices | Where {$_.name -in $this.Services}
        $Uri = "https://api.contoso.com/user/$($DealerMeUser.id)/services"
    
        #Gets likely service username
        Function Get-UserNameService($Service, $User){
            if ($Service.name -match "DealerRater|AssetTiger"){
                $Service | Add-Member -NotePropertyName 'username' -NotePropertyValue $User.UserPrincipalName -Force}
            elseif ($Service.name -match "Active Directory|KeyTrak|VAuto"){
                $Service| Add-Member -NotePropertyName 'username' -NotePropertyValue $User.SamAccountName -Force }
            elseif ($Service.name -match "DealerSocket"){
                $Service | Add-Member -NotePropertyName 'username' -NotePropertyValue $("nw1" + ($User.GivenName.ToLower())[0] + $(if($User.Surname.Length -gt 5){$User.surname.Substring(0,6).ToLower()}else{$User.surname.ToLower()})) -Force }
            else{$Service.Username | Add-Member -NotePropertyName 'username' -NotePropertyValue Read-Host("Enter Username for $Service") -Force}
        }

        #individual calls for each service.
        foreach ($Service in $UserServices){
            Get-UserNameService -Service $Service -User $this
            #if service already exists for user then update it
            if ($Service.id -in $DealerMeUserServices.id){
                If($(Read-Host("Update $($Service.name)? Y/N")) -match 'y'){
                    $Service_Assignment_ID = ($DealerMeUserServices | Where {$_.name -eq $Service.name}).pivot_id
                    if($(Read-Host "Service [$($Service.name):$($Service.username)] correct username? Y/N") -match "N"){
                        $ServiceUserName = $(Read-Host "Service User Name")
                    }
                    else{
                        $ServiceUserName = $Service.username
                    }
                    $UriExtension = "?action=update&active=1&service_assignment_id=$($Service_Assignment_ID)&service_id=$($Service.id)&shared=false&username=$($ServiceUserName)"
                    Write-Host "Updating $($Service.name)"
                }
                else{
                    Continue
                }
            }
            #Otherwise add it
            else{
                if($(Read-Host "Service [$($Service.name):$($Service.username)] correct username? Y/N") -match "N"){
                    $ServiceUserName = $(Read-Host "Service User Name")
                }
                else{
                    $ServiceUserName = $Service.username
                }
                $UriExtension = "?action=add&active=1&service_id=$($Service.id)&shared=false&username=$($ServiceUserName)"
                Write-Host "Adding $($Service.name)"
            }
            Invoke-AwsApiCall -Uri ($Uri + $UriExtension) -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $null -ContentType application/json -Method Post
        }
    }

    DisableDealerMeServices(){
        . \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1
        #DMe Keys
        $AWSKey = Get-Content "\\internal.contoso.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON
        #Get DealerMe ID and list of user services
        $Uri = "https://api.contoso.com/user?email=$($this.UserPrincipalName)&include=services"
        $DealerMeUser =  (Invoke-AwsApiCall -Uri $Uri -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey)).data
        #Services are a sub-object so expand to get details, rename users service id to not clash with service's id
        $DealerMeUserServices = $DealerMeUser.services.data | Select username,@{n='pivot_id';e={$_.id}} -ExpandProperty service
        $Uri = "https://api.contoso.com/user/$($DealerMeUser.id)/services"
        Write-Host "Services:" -ForegroundColor Cyan
        foreach ($Service in $DealerMeUserServices){
            Write-Host $Service.name : $Service.username -ForegroundColor Cyan
        }
        pause
        #individual calls for each service.
        foreach ($Service in $DealerMeUserServices){
            #if service already exists for user then update it
            Write-Host "`n`nService: $($Service.name): $($Service.username)" -ForegroundColor Yellow
            if($(Read-Host ("Did you disable this service? Y/N")) -match "y"){
                $Service_Assignment_ID = $Service.pivot_id
                $UriExtension = "?action=update&active=0&service_assignment_id=$($Service_Assignment_ID)&service_id=$($Service.id)&shared=false&username=$($Service.username)"
                Write-Host "Updating $($Service.name)"
                $Result = Invoke-AwsApiCall -Uri ($Uri + $UriExtension) -ApiKey $($AWSKey.apiKey) -AccessKeyID $($AWSKey.accessKeyID) -SecretAccessKey $($AWSKey.secretAccessKey) -RequestPayload $null -ContentType application/json -Method Post
            }
        }
    }

    [string] AssignAzureLicense(){
        Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
        Catch { Connect-AzureAD }
        $License_Choice = $null
        $License_Sku = $null
        $SetAzureLicenseSuccess = $null
        $AzureLicense = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
        Write-Host "$($this.Title) = $($this.License)"
        Do{
            $License_Choice = Read-Host ("1. E3 License `n2. Business Essentials`n3. Exchange Standard`nPlease enter Number")
        }
        Until($License_Choice -match "1|2|3")
        if($License_Choice -eq "1"){$License_Sku = "ENTERPRISEPACK"}
        elseif($License_Choice -eq "2"){$License_Sku = "O365_BUSINESS_ESSENTIALS"}
        elseif($License_Choice -eq "3"){$License_Sku = "EXCHANGESTANDARD"}
        $AzureLicense.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $License_Sku -EQ).SkuID
        $AzureLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        $AzureLicenses.AddLicenses = $AzureLicense
        #This can fail while waiting for O365 to create user, so give option to try again
        Do{
            Try {
                Get-AzureADUser -ObjectId "$($this.UserPrincipalName)"
                Set-AzureADUser -ObjectId "$($this.UserPrincipalName)" -UsageLocation "US"
                Set-AzureADUserLicense -ObjectId "$($this.UserPrincipalName)" -AssignedLicenses $AzureLicenses -Verbose
                $SetAzureLicenseSuccess = "Yes" 
                }
            Catch {
                Write-Host "Failed:`n$($Error[0])"
                if($(Read-Host "Try Again? Y/N?") -match "N"){
                    $SetAzureLicenseSuccess = "Cancel"
                }
            }
        }
        Until($SetAzureLicenseSuccess -match "Yes|Cancel")
        Return $License_Sku
    }

    RemoveAzureLicense(){
        Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
        Catch { Connect-AzureAD }
        $SetAzureLicenseSuccess = $null
        $Azurelicense = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
        $AzurelicenseDetail = Get-AzureADUserLicenseDetail -ObjectId $($this.UserPrincipalName)
        $Azurelicense.SkuId = $AzurelicenseDetail.SkuId
        $Azurelicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        $Azurelicenses.AddLicenses = @()
        $Azurelicenses.RemoveLicenses = $azurelicense.SkuId
        Do{
            Try {
                Write-Host "Removing $($AzurelicenseDetail.SkuPartNumber)"
                Set-AzureADUserLicense -ObjectId "$($this.UserPrincipalName)" -AssignedLicenses $Azurelicenses -Verbose
                $SetAzureLicenseSuccess = "Yes" 
                }
            Catch {
                Write-Host "Failed:`n$($Error[0])"
                if($(Read-Host "Try Again? Y/N?") -match "N"){
                    $SetAzureLicenseSuccess = "Cancel"
                }
            }
        }
        Until($SetAzureLicenseSuccess -match "Yes|Cancel")
    }

    AddAzureGroups(){
        Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
        Catch { Connect-AzureAD }

        $thisObjectID = (Get-AzureADUser -ObjectId $this.UserPrincipalName).ObjectID
        if ($(Get-AzureADGroupMember -ObjectId "b616d33c-57dc-4e9c-8a47-0a6b9732dd4b") -notcontains $thisObjectID){
            Write-Host "Adding Inventory channel"
            Add-AzureADGroupMember -ObjectId "b616d33c-57dc-4e9c-8a47-0a6b9732dd4b" -RefObjectId $thisObjectID -Verbose -ErrorAction SilentlyContinue
        }

        if($($this.Title) -eq "Sales Department" -AND $(Get-AzureADGroupMember -ObjectId "99f211fc-bae1-41ae-bb1f-2db2b755b5e9") -notcontains $thisObjectID){
            Write-Host "Adding Sales Rep Team"
            Add-AzureADGroupMember -ObjectId "99f211fc-bae1-41ae-bb1f-2db2b755b5e9" -RefObjectId $thisObjectID -Verbose -ErrorAction SilentlyContinue
        }
        if($($this.Title) -eq "Sales Managers" -AND $(Get-AzureADGroupMember -ObjectId "eafb6a93-27b7-42c3-867c-c0cada0a377b") -notcontains $thisObjectID){
            Write-Host "Adding Sales Manager Team"
            Add-AzureADGroupMember -ObjectId "eafb6a93-27b7-42c3-867c-c0cada0a377b" -RefObjectId $thisObjectID -Verbose -ErrorAction SilentlyContinue
        }
        if($($this.Title) -match "Finance" -AND $(Get-AzureADGroupMember -ObjectId "99f211fc-bae1-41ae-bb1f-2db2b755b5e9") -notcontains $thisObjectID){
            Write-Host "Adding Finance Team"
            Add-AzureADGroupMember -ObjectId "99f211fc-bae1-41ae-bb1f-2db2b755b5e9" -RefObjectId $thisObjectID -Verbose -ErrorAction SilentlyContinue
        }
    }

    RemoveAzureGroups(){
        Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
        Catch { Connect-AzureAD }
        $AzureUserId = (Get-AzureADuser -ObjectId $($this.UserPrincipalName)).ObjectId
        $AzureGroups = (Get-AzureADUserMembership -ObjectId $AzureUserId)
        Foreach ($AzureGroup in $AzureGroups){
            Write-Host "Removing $($AzureGroup.DisplayName)"
            Remove-AzureADGroupMember -ObjectId $AzureGroup.ObjectId -MemberId $AzureUserId -Verbose
        }
    }

}
