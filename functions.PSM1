function Get-MethodNames
{
    $methodNames = @()

    $methodNames += [PSCustomObject]@{
        ShortName = "E-Mail"
        MethodName = "#microsoft.graph.emailAuthenticationMethod"
        Description = "A user can use an email address as part of the Self-Service Password Reset (SSPR) process."
    },
    [PSCustomObject]@{
        ShortName = "FIDO2"
        MethodName = "#microsoft.graph.fido2AuthenticationMethod"
        Description = "A user can use a FIDO2 security key to sign-in to Microsoft Entra ID."
    },
    [PSCustomObject]@{
        ShortName = "Mobile-App"
        MethodName = "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"
        Description = "A user can use Microsoft Authenticator app to sign-in or perform multi-factor authentication to Microsoft Entra ID."
    },
    [PSCustomObject]@{
        ShortName = "Password"
        MethodName = "#microsoft.graph.passwordAuthenticationMethod"
        Description = "A password is currently the default primary authentication method in Microsoft Entra ID."
    },
    [PSCustomObject]@{
        ShortName = "Phone"
        MethodName = "#microsoft.graph.phoneAuthenticationMethod"
        Description = "A user can use a phone to authenticate using SMS or voice calls as allowed by policy."
    },
    [PSCustomObject]@{
        ShortName = "OAuth"
        MethodName = "#microsoft.graph.softwareOathAuthenticationMethod"
        Description = "Allow users to perform multifactor authentication using an application that supports the OATH TOTP specification and provides a one-time code."
    },
    [PSCustomObject]@{
        ShortName = "Temporary-Access-Pass"
        MethodName = "#microsoft.graph.temporaryAccessPassAuthenticationMethod"
        Description = "A time-limited passcode that serves as a strong credential and allows onboarding of passwordless credentials."
    },
    [PSCustomObject]@{
        ShortName = "Windows-Hello-for-Business"
        MethodName = "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod"
        Description = "A user can use Windows Hello for Business to sign-in to Microsoft Entra ID."
    }

    return $methodNames
}

function Convert-MethodTypeToShortName {
    param (
        [string]$methodType
    )

    $methodNames = Get-MethodNames

    foreach ($method in $methodNames) {
        if ($method.MethodName -eq $methodType) {
            return $method.ShortName
        }
    }

    return "<None>"
}   

# get only users we are interested in
function Get-FilteredUsers {
    param (
        [string]$user_upn
    )  

    if ($user_upn) {
        $filter = "UserPrincipalName eq '$user_upn'"
    } else {
        $filter = $null
    }

    # only return enabled users and filter to reduce query time
    # Get-MgUser's filter are insufficient for our needs so we need to filter locally
    try {
        # make this more elegant
        if ($global:user_limit -eq "all") {
            $users = Get-MgUser -Property Id,
                                UserPrincipalName,
                                DisplayName,
                                AccountEnabled,
                                CompanyName,
                                UserType,
                                OnPremisesSyncEnabled -All 
        } else {
            $users = Get-MgUser -Property Id,
                                 UserPrincipalName,
                                 DisplayName,
                                 AccountEnabled,
                                 CompanyName,
                                 UserType,
                                 OnPremisesSyncEnabled -Filter $filter -Top $global:user_limit
        }

        Write-Info "Retrieved [ $($users.Count) ] users"

        $filteredUsers = $users | Where-Object {
            $_.AccountEnabled        -eq $true                  -and 
            $_.UserType              -eq "Member"               -and 
            $_.OnPremisesSyncEnabled -eq $true                  -and 
            $_.CompanyName           -eq "$global:company_name" 
        }

        Write-Info "Filtered down to [ $($filteredUsers.Count) ] users"
    } catch {
        Write-Err "Exception in Get-MgUser: $_"
    }

    return $filteredUsers
}

# show stats
function Show-UsersMFAStatistics {
    param (
        [array]$stats
    )

    $strongMfaSetCount = 0
    $UserStats = [PSCustomObject]@{
        Email =         [PSCustomObject]@{count = 0; percent = 0; }
        Fido2 =         [PSCustomObject]@{count = 0; percent = 0; }
        Authenticator = [PSCustomObject]@{count = 0; percent = 0; }
        Password =      [PSCustomObject]@{count = 0; percent = 0; }
        Phone =         [PSCustomObject]@{count = 0; percent = 0; }
        Oauth =         [PSCustomObject]@{count = 0; percent = 0; }
        AccessPass =    [PSCustomObject]@{count = 0; percent = 0; }
        WindowsHello =  [PSCustomObject]@{count = 0; percent = 0; }
        None =          [PSCustomObject]@{count = 0; percent = 0; }
    }

    foreach ($user in $stats) {
        $strongMfaSet = $false

        if ($user.Email -gt 0) {
            $UserStats.Email.count++
            $UserStats.Email.percent = [math]::Round( ($UserStats.Email.count * 100) / $stats.Length, 2)
        }
        if ($user.Password -gt 0) {
            $UserStats.Password.count++
            $UserStats.Password.percent = [math]::Round( ($UserStats.Password.count * 100) / $stats.Length, 2)
        }
        if ($user.Phone -gt 0) {
            $UserStats.Phone.count++
            $UserStats.Phone.percent = [math]::Round( ($UserStats.Phone.count * 100) / $stats.Length, 2)
        }
        if ($user.Fido2 -gt 0) {
            $strongMfaSet = $true
            $UserStats.Fido2.count++
            $UserStats.Fido2.percent = [math]::Round( ($UserStats.Fido2.count * 100) / $stats.Length, 2)
        }
        if ($user.Authenticator -gt 0) {
            $strongMfaSet = $true
            $UserStats.Authenticator.count++
            $UserStats.Authenticator.percent = [math]::Round( ($UserStats.Authenticator.count * 100) / $stats.Length, 2)
        }
        if ($user.Oauth -gt 0) {
            $strongMfaSet = $true
            $UserStats.Oauth.count++
            $UserStats.Oauth.percent = [math]::Round( ($UserStats.Oauth.count * 100) / $stats.Length, 2)
        }
        if ($user.AccessPass -gt 0) {
            $strongMfaSet = $true
            $UserStats.AccessPass.count++
            $UserStats.AccessPass.percent = [math]::Round( ($UserStats.AccessPass.count * 100) / $stats.Length, 2)
        }
        if ($user.WindowsHello -gt 0) {
            $strongMfaSet = $true
            $UserStats.WindowsHello.count++
            $UserStats.WindowsHello.percent = [math]::Round( ($UserStats.WindowsHello.count * 100) / $stats.Length, 2)
        }
        if ($user.None -gt 0) {
            $UserStats.None.count++
            $UserStats.None.percent = [math]::Round( ($UserStats.None.count * 100) / $stats.Length, 2)
        }

        if ($strongMfaSet) {
            $strongMfaSetCount++
        }
    }

    $strongMfaSetPercent = [math]::Round( ($strongMfaSetCount * 100) / $stats.Length, 2)

    Write-Msg "+-----------------------------------------------+"
    $formatStringHeader = "| MFA Statistic                                 |"
    $fs = $formatStringHeader -f $stats.Length
    Write-Msg $fs
    Write-Msg "+-----------------------+----------+------------+"
    Write-Msg "| Method                |   Users  |   Percent  |"
    Write-Msg "+-----------------------+----------+------------+"
    $formatStringEntry = "| - {0,-14}      | {1,8} | {2,8} % |"
    foreach ($e in $UserStats.PSObject.Properties) {
        if ($e.Value.Count -eq 0) {
            continue
        }
        $s = $formatStringEntry -f $e.Name, $e.Value.count, $e.Value.percent
        Write-Msg $s
    }
    Write-Msg "+-----------------------+----------+------------+"
    $s = "Users with strong MFA"
    $formatStringUsers = "| {0,-14} | {1,8} | {2,8} % |"
    $fs = $formatStringUsers -f $s, $strongMfaSetCount, $strongMfaSetPercent
    Write-Msg $fs
    Write-Msg "+-----------------------+----------+------------+"
}

# compute the stats for the users
function Get-UsersMFAStatistics {
    param (
        [array]$userInfo
    )

    $user_stats = @()
    foreach ($user in $userInfo) {
        # per user counters to get more precise data
        $user_mfa_counter = [PSCustomObject]@{
            Email = 0
            Fido2 = 0
            Authenticator = 0
            Password = 0
            Phone = 0
            Oauth = 0
            AccessPass = 0
            WindowsHello = 0
            None = 0
            DenyGroup = $False
        }

        # all mfa methods for user
        foreach ($mfaMethod in $user.Mfa) {

            # Increment the per-user counter based on the method type
            switch ($mfaMethod.MethodType) {
                "#microsoft.graph.emailAuthenticationMethod" { 
                    $user_mfa_counter.Email++
                }
                "#microsoft.graph.fido2AuthenticationMethod" { 
                    $user_mfa_counter.Fido2++
                }  
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" { 
                    $user_mfa_counter.Authenticator++
                }
                "#microsoft.graph.passwordAuthenticationMethod" {
                    $user_mfa_counter.Password++
                }
                "#microsoft.graph.phoneAuthenticationMethod" { 
                    $user_mfa_counter.Phone++
                }
                "#microsoft.graph.softwareOathAuthenticationMethod" {
                    $user_mfa_counter.Oauth++
                }
                "#microsoft.graph.temporaryAccessPassAuthenticationMethod" { 
                    $user_mfa_counter.AccessPass++
                }
                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    $user_mfa_counter.WindowsHello++   
                }
                "" {
                    $user_mfa_counter.None++
                }   
            }
        }
        $user_mfa_counter.DenyGroup = $user.DenyGroup
        $user_stats += $user_mfa_counter
    }

    return $user_stats
}

# get deny group and raw mfa data for each user
# return user and group details in list with nested custom objects
function Get-UsersGroupMFAInfo {
    param (
        [array]$users
    )  

    $userInfo = @() # the list of objects we return

    $processedUsers = 1
    $totalUsers = $users.Count

    foreach ($user in $users)
    {
        if (-not $global:verbose) {
            Write-Info "Processing user [ $processedUsers | $totalUsers ]"
        }

        $data = Get-GraphUserMfaDenyAccessData $user.Id                        

        $obj = [PSCustomObject]@{
            Id                = $user.Id
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            DenyGroup         = $data.DenyGroup
            MfaCount          = $data.MfaCount
            Mfa               = $data.MfaMethods
        }

        if ($global:verbose) {
            Show-UserDataObjUserMfa $obj
        }

        $processedUsers += 1
        $userInfo += $obj
    }

    return $userInfo
}

# get the deny group info and mfa methods for a user
function Get-GraphUserMfaDenyAccessData {
    param (
        [string]$userId
    )

    $mfa = @()

    $obj = [PSCustomObject]@{
        MfaMethods = $null
        MfaCount = 0
        DenyGroup = $False
    }

    try {
        $group = Get-MgUserMemberOf -UserId $userId | Where-Object { $_.Id -eq $global:deny_access_group_id }
        $mfaMethods = Get-MgUserAuthenticationMethod -UserId $userId

        foreach ($mfaMethod in $mfaMethods) {
            $mfa += [PSCustomObject]@{
                Id          = $mfaMethod.Id
                MethodType  = $mfaMethod.AdditionalProperties["@odata.type"]
            }
            $obj.MfaCount++
        }

        $obj.MfaMethods = $mfa

        if ($group -ne $null) {
            $obj.DenyGroup = $True
        }
    } catch [System.Exception]{
        Write-Warn "Exception : $_"
        Write-Err "Error receiving Data for user [ $($userId) ]"
    }

    return $obj
}

# show the user data 
function Show-WeakUsers {
    param (
        [array]$weakUsers
    )

    foreach ($user in $weakUsers) {
        Show-UserDataObjUser $user
    }
}

# checks each user for a weak state
# only returnes a true/false answer
# depending on the MFA state of the user
function Test-UserWeakness {
    param (
        [PSCustomObject]$user
    )

    # if user is in deny group, they cannot login
    if ($user.DenyGroup -eq $true) {
        return $false
    }

    # if user has no mfa methods
    if ($user.MfaCount -eq 0) {
        Write-Warn "No MFA detected for [ $($user.DisplayName) ]"
        return $true
    }

    # User has only password set and is not in the deny group,
    # then someone with PW access could login and add their own MFA
    if ($user.mfa.MethodType -eq "#microsoft.graph.passwordAuthenticationMethod" -and $user.MfaCount -eq 1) {
        return $true
    }

    return $false
}

# from the pool of users, get those
# which are considered weak to due 
# their mfa state
function Get-WeakUsers {
    param (
        [array]$data
    )

    $weakUsers = @()

    foreach ($user in $data) {
        if (Test-UserWeakness -user $user) {
            $weakUsers += $user
        }   
    }

    # Without the comma, PowerShell might "unwrap" the array if it contains only one item, returning just the object instead of an array.
    return ,$weakUsers  
}

# deny users by adding them to the deny group
# this is a potentially destructive operation, so be careful
function Deny-Users {
    param (
        [array]$weakUsers
    )

    # highway to danger zone
    if ($global:deny) {
        Write-Warn "Adding [ $($weakUsers.Count) ] weak users to deny access group [ $global:deny_access_group_id ]:[ $global:deny_access_group_name ]"
        $check = Test-UserConsent

        if ($check -eq $true) {
            foreach ($user in $weakUsers) {
                Write-Info "Adding to Deny Group [ $($user.UserPrincipalName) ]"
                $obj = Get-ADUser -Filter "UserPrincipalName -eq '$($user.UserPrincipalName)'"
                Add-ADGroupMember -Identity $global:deny_access_group_name -Members $obj.SamAccountName
            }

            Write-Ok "All weak users have been processed."
        }
    } 
}