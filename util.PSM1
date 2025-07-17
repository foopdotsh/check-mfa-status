# parsing logic is super messy due to mixing definitions and declarations of globals
function Register-Options {
    param (
        [hashtable]$cmdletArgs
    )

    if ($cmdletArgs['help']) {
        Show-HelpText
        exit
    }

    # Validate conflicting options
    if ($cmdletArgs['limit'] -and $cmdletArgs['user']) {
        Write-Err "unable to use -limit and -user options together"
    }

    if ($cmdletArgs['quiet'] -and ($cmdletArgs['deny'] -or $cmdletArgs['noexport'] -or $cmdletArgs['verbose'])) {
        Write-Err "conflicting options: -quiet cannot be used with -deny, -noexport, or -verbose"
    }

    # Output control
    $global:deny        = [bool]$cmdletArgs['deny']
    $global:enablePrint = -not $cmdletArgs['quiet']
    $global:verbose     = [bool]$cmdletArgs['verbose']
    $global:noexport    = [bool]$cmdletArgs['noexport']

    # File path for exports
    if ($cmdletArgs['path']) {
        if ($global:noexport) {
            Write-Err "unable to use -path option with -noexport"
        }
        $global:file_path = $cmdletArgs['path']

        if (-not (Confirm-DirectoryAccess -file_path $global:file_path)) {
            Write-Err "No write access to directory: $global:file_path"
        }
    } else {
        $global:file_path = $PSScriptRoot
        if (-not (Confirm-DirectoryAccess -file_path $global:file_path)) {
            Write-Err "No write access to current working dir : $global:file_path"
        }
    }

    # User and limit logic
    if ($cmdletArgs['user']) {
        if ($cmdletArgs['limit']) {
            Write-Err "unable to use -user and -limit options together"
        }
        $global:user = $cmdletArgs['user']
    }

    if ($cmdletArgs['limit']) {
        $limitValue = $cmdletArgs['limit']

        if ($limitValue -eq "all") {
            $global:user_limit = "all"
        }elseif ($limitValue -is [string] -and $limitValue -match '^\d+$') {
            $limitInt = [int]$limitValue
            if ($limitInt -ge 1 -and $limitInt -le 999) {
                $global:user_limit = $limitInt
            } else {
                Write-Err "Invalid value for -limit. It must be a number between 1 and 999 or 'all'"
            }
        } else {
            Write-Err "Invalid value for -limit. It must be a number between 1 and 999 or 'all'"
        }
    }

    # Lets goooo
    Show-AsciiArt
}


function Show-AsciiArt {
    if ($global:enablePrint) {
    $s = @"
    __  ____________       _____ __        __                ________              __            
   /  |/  / ____/   |     / ___// /_____ _/ /___  _______   / ____/ /_  ___  _____/ /_____  _____
  / /|_/ / /_  / /| |     \__ \/ __/ __ `/ __ / / / / ___/  / /   / __ \/ _ \/ ___/ //_/ _ \/ ___/
 / /  / / __/ / ___ |    ___/ / /_/ /_/ / /_/ /_/ (__  )  / /___/ / / /  __/ /__/ ,< /  __/ /    
/_/  /_/_/   /_/  |_|   /____/\__/\__,_/\__/\__,_/____/   \____/_/ /_/\___/\___/_/|_|\___/_/     
                                                                                                 
"@
    Get-Funky $s
    }
}

function Get-Funky{
    param([string]$Text)

    $rainbowColors = @(
        [System.ConsoleColor]::Red,
        [System.ConsoleColor]::Yellow,
        [System.ConsoleColor]::Green,
        [System.ConsoleColor]::Cyan,
        [System.ConsoleColor]::Blue,
        [System.ConsoleColor]::Magenta
    )

    $Text.ToCharArray() | ForEach-Object{
        switch -Regex ($_){
            "`r"{
                break
            }
            "`n"{
                Write-Host ""
                break
            }
            "[^ ]"{
                $writeHostOptions = @{
                    ForegroundColor = $rainbowColors | get-random
                    NoNewLine = $true
                }
                Write-Host $_ @writeHostOptions 
                break
            }
            " " {
                Write-Host " " -NoNewline
            }

        } 
    }
    Write-Host ""
}

function Write-Out([string]$msg, [string]$color)
{
    if ($global:enablePrint) {
        Write-Host $msg -ForegroundColor $color
    }
}

function Write-OK([string]$msg)
{
    Write-Out "[!] $msg" "Green"
}

function Write-Warn([string]$msg)
{
    Write-Out "[!] $msg" "Yellow"
}

function Write-Info([string]$msg)
{
    Write-Out "[>]`t$msg" "Blue"
}

function Write-Msg([string]$msg)
{
    Write-Out "[+] $msg" "Magenta"
}

function Write-Err([string]$msg)
{
    Write-Out "[x] $msg" "Red"
    exit
}

function Show-HelpText
{
    Write-Msg "+-------------------------------------------------------------------------------------------------------+"
    Write-Msg "| Usage: .\StatusChecker.ps1 -option <argument>                                                         |"
    Write-Msg "+-----------------------+-------------------------------------------------------------------------------+"
    Write-Msg "| -path <path>          | override the default filepath (which is the current working directory)        |"
    Write-Msg "| -verbose              | print all details                                                             |"
    Write-Msg "| -quiet                | print no output to console                                                    |"
    Write-Msg "| -limit <int|string>   | specify how many users to get, range from [1-999], accepts 'all'              |"   
    Write-Msg "| -user <string>        | specify a user to check                                                       |"
    Write-Msg "| -noexport             | only display results to terminal, does not dump CSV data                      |" 
    Write-Msg "| -help                 | show this helptext and exit                                                   |"
    Write-Msg "| -deny                 | add the weak users to the deny access group                                   |"
    Write-Msg "+-----------------------+-------------------------------------------------------------------------------+"
    Write-Msg "|                                                                                                       |"
    Write-Msg "| - Examples                                                                                            |"
    Write-Msg "|                                                                                                       |"
    Write-Msg "| .\StatusChecker.ps1 -user 'firstname.lastname@example.com' -verbose                                   |"
    Write-Msg "| .\StatusChecker.ps1 -limit 25 -verbose -deny                                                          |"
    Write-Msg "| .\StatusChecker.ps1 -quiet -limit all -path 'C:\Users\user\dump'                                      |"
    Write-Msg "| .\StatusChecker.ps1 -limit 100 -noexport                                                              |"
    Write-Msg "|                                                                                                       |"
    Write-Msg "+-------------------------------------------------------------------------------------------------------+"
}

function Confirm-DirectoryAccess
{
    param (
        [string]$file_path
    )

    if (-not (Test-Path -Path $file_path)) {
        Write-Err "Directory/File does not exist: $file_path"
    }

    try {
        $acl = Get-Acl -Path $file_path
        $accessRules = $acl.Access | Where-Object { $_.IdentityReference -eq "$($env:USERDOMAIN)\$($env:USERNAME)" }
        if ($accessRules) {
            return $true;
        } else {
            return $false;
        }
    } catch {
        Write-Err "Error checking directory access: $_"
        return $false;  
    }
}

function Export-Results { 
    param (
        [array]$data,
        [string]$csv_name
    )

    if ($global:noexport) {
        Write-Warn "Skipping export due to -noexport flag."
        return
    }   

    $dumpPath = Join-Path -Path "$global:file_path" -ChildPath $csv_name
    Write-Info "Exporting data : [ $dumpPath ]"

    try {
        # Check if the directory exists
        $directory = [System.IO.Path]::GetDirectoryName($file_path)
        if (-not (Test-Path -Path $directory)) {
            throw "Directory/File does not exist: $directory"
        }

        # Export to CSV
        $data | Export-Csv -Path "$dumpPath" -NoTypeInformation
    } catch {
        Write-Err "Failed to export to CSV: $_"
    }
}

function Show-UserDataObjUserMfa {
    param (
        [Object]$data
    )

    Write-Info "--------------------------+"
    Write-Info "User - DisplayName        | $($data.DisplayName)"
    Write-Info "User - UserPrincipalName  | $($data.UserPrincipalName)"
    Write-Info "User - Id                 | $($data.Id)"
    if ($data.DenyGroup -ne $False) {
        Write-Info "MFA  - Deny Portal Access | True"
    } else {
        Write-Info "MFA  - Deny Portal Access | False"
    }
    Write-Info "MFA  - Count              | $($data.MfaCount)"

    foreach ($e in $data.Mfa) {
        $short = Convert-MethodTypeToShortName -methodType $e.MethodType
        $methodlist += $short + " "
    }
    Write-Info "MFA  - Methods            | $methodlist"
}

function Show-UserDataObjUser {
    param (
        [Object]$data
    )

    Write-Warn "-------------------+"
    Write-Warn " DisplayName       | $($data.DisplayName)"
    Write-Warn " UserPrincipalName | $($data.UserPrincipalName)"
    Write-Warn " Id                | $($data.Id)"
}

function Show-ConsentHeader {
    Write-Out "[>] -------------------------------------------------- [<]" "Red" 
    Write-Out "[>]        This option might break something !         [<]" "Red" 
    Write-Out "[>] -------------------------------------------------- [<]" "Red" 
    Write-Out "[>]  By adding accounts found by this tool to a        [<]" "Red" 
    Write-Out "[>]  'deny access group' you will prevent them from    [<]" "Red" 
    Write-Out "[>]  accessing cloud resources.                        [<]" "Red" 
    Write-Out "[>]                                                    [<]" "Red" 
    Write-Out "[>]  + This will only affect 'weak' users              [<]" "Red" 
    Write-Out "[>]                                                    [<]" "Red" 
    Write-Out "[>]  + Make sure you are positively aware of the       [<]" "Red"
    Write-Out "[>]    number of 'weak' users found by this tool       [<]" "Red" 
    Write-Out "[>]    before answering 'y' to the following prompt    [<]" "Red" 
    Write-Out "[>] -------------------------------------------------- [<]" "Red" 
    Write-Out "[>]          Do you want to continue? (y/n)            [<]" "Blue"
    Write-Host ""
    Write-Host ""
}

function Test-UserConsent {
    Show-ConsentHeader
    $attemptCount = 0
    $maxAttempts = 3
    while ($attemptCount -lt $maxAttempts) {
        $input = Read-Host "Do you want to continue? (y/n)"
        switch ($input.ToLower()) {
            'y' {
                Write-Ok "You chose : 'Yes'"
                return $true
            }
            'n' {
                Write-Ok "You chose : 'No'"
                return $false
            }
            default {
                Write-Warn "Invalid input. Press 'y' or 'n'"
                $attemptCount++
                Write-Warn "Attempt [ $attemptCount | $maxAttempts ]"
            }
        }
    }
    Write-Info "Maximum attempts reached. Defaulting to 'No'"
    return $false
}
