param(
    [switch] $noexport = $false, # we export results to csv by default
    [string] $path = "",
    [switch] $help = $false,
    [switch] $verbose = $false,
    [switch] $quiet = $false, 
    [string] $limit = "",
    [string] $user = "",
    [switch] $deny = $false
)

# edit these options to your needs
$global:company_name           = ""
$global:deny_access_group_name = ""
$global:deny_access_group_id   = ""
$global:stats_csv_name         = "$(get-date -f yyyy-MM-dd_HHmmss)_stats_export.csv"
$global:weak_csv_name          = "$(get-date -f yyyy-MM-dd_HHmmss)_weak_users_export.csv"

$StartTime = Get-Date 

# Import Module
Try {
	Import-Module $PSScriptRoot\functions.PSM1 -ErrorAction Stop -Force
	Import-Module $PSScriptRoot\util.PSM1 -ErrorAction Stop -Force
    Register-Options $PSBoundParameters
    Write-OK "Successfully imported Module [ functions.PSM1 ]"   
    Write-OK "Successfully imported Module [ util.PSM1      ]"   
    if ($PSBoundParameters.Count -eq 0) {
        Write-Warn "No parameters provided, see '-help'"
        exit
    }
} Catch {
	$ErrorMessage = $_.Exception.Message
    $s = "[!] ---------------------------------"
    Write-Host $s -ForegroundColor Red
    Write-Host "[!] $ErrorMessage" -ForegroundColor Red
    Write-Host $s -ForegroundColor Red
	exit
}

# graph api connection
$auth = Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "UserAuthenticationMethod.Read.All"
if ($auth) {
    Write-OK "Connection to Microsoft Graph was successful."
} else {
    Write-Err "Connection to Microsoft Graph failed."
}

# get the users
$users = Get-FilteredUsers $user
if ($users) {
    Write-OK "Successfully retrieved Users."
} else {
    Write-Err "Failed to retrieve Users."
}

# get the users group MFA information
$userGroupMFAInfo = Get-UsersGroupMFAInfo $users
if ($userGroupMFAInfo) {
    Write-OK "Successfully retrieved User and Group Information."
} else {
    Write-Err "Failed to retrieve User and Group Information."
}

# get a subset of 'weak' users
$weakUsers = Get-WeakUsers $userGroupMFAInfo
if ($weakUsers.Count -gt 0) {
    Write-Warn "Found [ $($weakUsers.Count) ] weak users"
    Write-Warn "Percentage of weak users: [ $([math]::Round(($weakUsers.Count / $users.Count) * 100, 2)) % ]"
    if ($verbose) { 
        Show-WeakUsers $weakUsers
    }
    Export-Results $weakUsers $global:weak_csv_name
    Deny-Users $weakUsers
} else {
    Write-OK "No weak users found in sample."
    if ($deny) {
        Write-Ok "Ignoring '-deny' option"
    }
} 

# get the actual statistics
$stats = Get-UsersMFAStatistics $userGroupMFAInfo
if ($stats) {
    Show-UsersMFAStatistics $stats
    Write-OK "Successfully processed all stats."
    Export-Results $stats $global:stats_csv_name
} else {
    Write-Err "Failed to process stats."
}

$RunTime = New-TimeSpan -Start $StartTime -End (get-date) 
Write-OK "Runtime : [$($RunTime.Hours):$($RunTime.Minutes):$($RunTime.Seconds).$($RunTime.Milliseconds)]"
