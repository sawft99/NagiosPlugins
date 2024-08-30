#Checks for last time Windows updates were installed/ran
#Warning: This installs NuGet and PSWindowsUpdate if they are not present
#Security Intel Updates: https://www.microsoft.com/en-us/wdsi/definitions/antimalware-definition-release-notes
#MS Catalogue: https://www.catalog.update.microsoft.com/home.aspx

[int]$CriticalDays = $args[0]
[int]$WarningDays = $args[1]
#Show Defender and AV definition updates in output ($true of $false)
$IncludeAVOutput = $args[2]
#Count Defender and AV definition updates as Windows updates ($true or $false)
$CountAV = $args[3]
#Only show X number of updates in output
$OnlyShow = $args[4]

#-----------------------------

#Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    if ((($IncludeAVOutput -ne $false) -and ($IncludeAVOutput -ne $true)) -or (($CountAV -ne $false) -and ($CountAV -ne $true))) {
        $ErrorMsg = 'UNKNOWN: $IncludeAVOutput and $CountAV needs to be "true" or "false"'
        $LASTEXITCODE = 3
        throw
    }
    try {
        #Check for $CriticalDays and $WarningDays to be valid numbers
        if (($CriticalDays -notin 1..365) -or ($WarningDays -notin 1..365)) {
            $ErrorMsg = 'UNKNOWN: Provide a number between 1 and 365'
            $LASTEXITCODE = 3
            throw
        } else {
            [int]$CriticalDays = $CriticalDays
            [int]$WarningDays = $WarningDays
            #Set max age in days to look back for updates
            $MaxDate = (Get-Date).AddDays(-$CriticalDays)
        }
    } catch {
        throw
    }
    try {
        #Check for and install PSWindowsUpdateModule and NuGet if needed
        $ModuleExist = (Get-Module -ListAvailable -Name PSWindowsUpdate).Count
        $NuGetExist = Get-PackageProvider | Where-Object -Property Name -eq 'NuGet'
        if ($null -eq $NuGetExist) {
            Install-PackageProvider -Name 'NuGet' -Force -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            $NuGetExist = Get-PackageProvider | Where-Object -Property Name -eq 'NuGet'
            if ($null -eq $NuGetExist) {
                $ErrorMsg = 'CRITICAL: Could not install NuGet for some reason'
                $LASTEXITCODE = 2
                throw
            }
        }
        if ($ModuleExist -lt 1) {
            Install-Module -Name PSWindowsUpdate -Force
            $ModuleExist = (Get-Module -ListAvailable -Name PSWindowsUpdate).Count
            if ($ModuleExist -lt 1) {
                $ErrorMsg = 'CRITICAL: Could not install PSWindowsUpdate module'
                $LASTEXITCODE = 2
                throw
            }
        }
    } catch {
        throw
    }

    #-----------------------------

    try {
        #Get only Windows based updates
        $WindowsUpdates = Get-HotFix | Select-Object -Property HotFixID,Description,InstalledBy,InstalledOn | Sort-Object -Property InstalledOn -Descending -ErrorAction SilentlyContinue
        if ($null -eq $WindowsUpdates) {
            $ErrorMsg = 'CRITICAL: No updates found'
            $LASTEXITCODE = 2
            throw
        }
    } catch {
        throw
    }

    #Find difference in days between latest Windows update and specified thresholds
    $LastWindowsInstallDif = ((Get-Date) - ($WindowsUpdates)[0].InstalledOn).Days

    #Check if warning limit reached for Windows updates
    if (($LastWindowsInstallDif -ge $WarningDays) -and ($LastWindowsInstallDif -lt $CriticalDays)) {
        $WindowsUpdatesWarningThreshold = $true
    } else {
        $WindowsUpdatesWarningThreshold = $false
    }

    #Check if critical limit reached for Windows updates
    if ($LastWindowsInstallDif -ge $CriticalDays) {
        $WindowsUpdatesCriticalThreshold = $true
    } else {
        $WindowsUpdatesCriticalThreshold = $false
    }

    #-----------------------------

    #Get all types of updates
    try {
        $AllUpdates = Get-WUHistory -Last $OnlyShow -MaxDate $MaxDate -WarningAction SilentlyContinue | Select-Object -Property * | Sort-Object -Property Date -Descending
        $AllUpdates = $AllUpdates | Select-Object -Property Title,Date,KB,Result
        #Get Defender updates
        if (($CountAV -eq $true) -or ($IncludeAVOutput -eq $true)) {
            $DefenderAndAVUpdates = $AllUpdates | Where-Object {($_.Title -Match 'Microsoft Defender') -or ($_.Title -Match 'Windows Security platform')} | Sort-Object -Property Date -Descending
            if (($null -ne $DefenderAndAVUpdates)) {
                $DefenderAndAVUpdatesDiff = ((Get-Date) - $DefenderAndAVUpdates[0].Date).Days
                if ($CountAV -eq $true) {
                    if ($DefenderAndAVUpdatesDiff -gt $WarningDays) {
                        $DefenderAndAVUpdatesWarningThreshold = $true
                    } else {
                        $DefenderAndAVUpdatesWarningThreshold = $false
                    }
                    if ($DefenderAndAVUpdatesDiff -gt $CriticalDays) {
                        $DefenderAndAVUpdatesCriticalThreshold = $true
                    } else {
                        $DefenderAndAVUpdatesCriticalThreshold = $false
                    }
                } else {
                    $DefenderAndAVUpdatesWarningThreshold = $false
                    $DefenderAndAVUpdatesCriticalThreshold = $false
                }
            } else {
                $DefenderAndAVUpdates = "No updates related to Defender in the past $CriticalDays days"
            }
            if ($CountAV -eq $true) {
                $LastWindowsInstallDif = $DefenderAndAVUpdatesDiff
            }
        }
    } catch {
        throw
    }

    #-----------------------------

    #Find when last check for Winodws updates was
    [datetime]$LastWindowsUpdateCheck = (Get-WULastResults -WarningAction SilentlyContinue).LastSearchSuccessDate
    [datetime]$UTCTime = [datetime]::UtcNow
    [datetime]$LocalTime = Get-Date
    #Convert to computers local time
    $TimeZoneDiff = $LocalTime.TimeOfDay.Hours - $UTCTime.TimeOfDay.Hours
    $LastWindowsUpdateCheck = $LastWindowsUpdateCheck.AddHours($TimeZoneDiff)
    $LastWindowsUpdateCheckDiff = (Get-Date) - $LastWindowsUpdateCheck
    if ($LastWindowsUpdateCheckDiff -gt $WarningDays) {
        $LastWindowsUpdateCheckWarningThreshold = $true
    } else {
        $LastWindowsUpdateCheckWarningThreshold = $false
    } if ($LastWindowsUpdateCheckDiff -gt $CriticalDays) {
        $LastWindowsUpdateCheckCriticalThreshold = $true
    } else {
        $LastWindowsUpdateCheckCriticalThreshold = $false
    }
    $LastWindowsUpdateCheckString = $LastWindowsUpdateCheck.ToShortDateString() + ' - ' + $LastWindowsUpdateCheck.ToShortTimeString()

    #-----------------------------

    $MpcCommandTest = $null -eq (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)
    if ($MpcCommandTest -eq $false) {
        $DefenderSignatureVersion = Get-MpComputerStatus -ErrorAction SilentlyContinue | Select-Object -Property AntispywareSignatureVersion -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AntispywareSignatureVersion -ErrorAction SilentlyContinue
        if ($null -eq $DefenderSignatureVersion) {
            $DefenderSignatureVersion = 'No signatures present or Defender not enabled'
        }
    } else {
        $DefenderSignatureVersion = 'Get-MpComputerStatus command not supported'
    }

    #-----------------------------

    #Check if any warning levels
    if (($WindowsUpdatesWarningThreshold -eq $true) -or ($DefenderAndAVUpdatesWarningThreshold -eq $true) -or ($LastWindowsUpdateCheckWarningThreshold -eq $true)) {
        $AnyWarning = $true
        if ($WindowsUpdatesWarningThreshold -eq $false) {
            $AnyWarning = $false
        }
    } else {
        $AnyWarning = $false
    }
    #Check if any critical levels
    if (($WindowsUpdatesCriticalThreshold -eq $true) -or ($DefenderAndAVUpdatesCriticalThreshold -eq $true) -or ($LastWindowsUpdateCheckCriticalThreshold -eq $true)) {
        $AnyCritical = $true
        if ($WindowsUpdatesCriticalThreshold -eq $false) {
            $AnyCritical = $false
        }
    } else {
        $AnyCritical = $false
    }

    #-----------------------------

    #Set overall status
    if (($AnyWarning -eq $true) -or ($AnyCritical -eq $true)) {
        if ($AnyWarning -eq $true -and $AnyCritical -eq $false) {
            $OverallStatus = 'WARNING: '
            $LASTEXITCODE = 1
            if (($CountAV -eq $true) -and ($DefenderAndAVUpdatesWarningThreshold -eq $false)) {
                $OverallStatus = 'OK: '
                $LASTEXITCODE = 0
            }
        } else {
            $OverallStatus = 'CRITICAL: '
            $LASTEXITCODE = 2
            if (($CountAV -eq $true) -and ($DefenderAndAVUpdatesCriticalThreshold -eq $false)) {
                $OverallStatus = 'OK: '
                $LASTEXITCODE = 0
            }
        }
    } elseif (($AnyWarning -eq $false) -and ($AnyCritical -eq $false)) {
        $OverallStatus = 'OK: '
        $LASTEXITCODE = 0
    } else {
        $OverallStatus = 'UNKNOWN: '
        $LASTEXITCODE = 3
    }

    #--------------
    
    #Report
    try {
        if ($OverallStatus -eq 'WARNING: ') {
            $StatusString = $OverallStatus + "It has been $LastWindowsInstallDif days since Windows updates have been installed"
        } elseif ($OverallStatus -eq 'CRITICAL: ') {
            $StatusString = $OverallStatus + "It has been $LastWindowsInstallDif days since updates have been installed"
        } elseif ($OverallStatus -eq 'OK: ') {
            $StatusString = $OverallStatus + "Last update performed $LastWindowsInstallDif days ago"
        } else {
            $StatusString = $OverallStatus + 'Unknown issue'
            $ErrorMsg = $StatusString
            throw
        }
        Write-Output $StatusString
        Write-Output "Last Windows Update Check: $LastWindowsUpdateCheckString"
        Write-Output ''
        Write-Output 'Last Windows Update'
        Write-Output '==================='
        $UpdateOut = $WindowsUpdates | Select-Object -First $OnlyShow | Format-Table -Property HotFixID,InstalledOn,Description,InstalledBy -AutoSize -Wrap
        Write-Output $UpdateOut
        if (($CountAV -eq $true) -or ($IncludeAVOutput -eq $true)) {
            Write-Output 'Last Defender Update'
            Write-Output '===================='
            $DefenderOut = $DefenderAndAVUpdates | Format-Table -Property KB,Date,Result -AutoSize -Wrap
            Write-Output $DefenderOut
            Write-Output "Defender Signature Verison: $DefenderSignatureVersion"
        }
    } catch {
        $ErrorMsg = 'UNKNOWN: Unknown error occurred in reporting'
        $LASTEXITCODE = 3
        throw
    }
} catch {
    if ($null -eq $ErrorMsg) {
        $ErrorMsg = 'UNKNOWN: Unknown error occurred in script'
        $LASTEXITCODE = 3
    }
    Write-Output $ErrorMsg
}

#Exit
exit $LASTEXITCODE
