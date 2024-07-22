#Checks for shutdown events and uptime

#Reference
#Event Log ID | Meaning
#41           | The system has rebooted without cleanly shutting down first
#1074         | The system has been shutdown properly by a user or process
#1076         | Follows after EventLog.Id ID 6008 and means that the first user with shutdown privileges logged on to the server after an unexpected restart or shutdown and specified the cause
#6005         | The EventLog.Id Log service was started. Indicates the system startup
#6006         | The EventLog.Id Log service was stopped. Indicates the proper system shutdown
#6008         | The previous system shutdown was unexpected
#6009         | The operating system version detected at the system startup
#6013         | The system uptime in seconds

[int32]$WarningUptime = $args[0] #Uptime in total hours. Example, if you want 3 days enter 72
[int32]$CriticalUptime = $args[1] #Uptime in total hours.
[int32]$MaxEventAge = $args[2] #Uptime in total hours. Don't look back more than X hours in the event log

#-----------------

#Validate input
if ($Error.Count -gt 0) {
    $LASTEXITCODE = 3
    Clear-Host
    Write-Output 'UNKNOWN: Use only Int32 numbers for the arguments'
    exit $LASTEXITCODE
}

#Reboot & Shutdown EventLog.Id IDs
$EventIDs = @(41,1074,1076,6005,6006,6008)

#Measure Uptime
$CurrentTime = Get-Date
$LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property LastBootUpTime).LastBootUpTime
$ActualUptime = $CurrentTime - $LastBoot
[int32]$ActualUptime = $ActualUptime.TotalHours
#$ActualUptime = (Get-Uptime).TotalHours #If PS7
$UptimeMessage = "Server has been up for $ActualUptime hours"

#Get events
$Events = Get-WinEvent -LogName system -Oldest | Where-Object -Property Id -in $EventIDs
$EventsFiltered = $Events | Where-Object {(($CurrentTime - $_.TimeCreated).TotalHours) -le $MaxEventAge} | Select-Object -Property *

#Reformat event info
$EventsReformat = foreach ($EventLog in $EventsFiltered) {
    $NewEvent = [PSCustomObject]@{
        Time  = $EventLog.TimeCreated
        ID    = $EventLog.Id
        Level = $EventLog.LevelDisplayName
        Container = $EventLog.ContainerLog
        ProviderName = $EventLog.ProviderName
        Log = $EventLog.LogName
        User = $EventLog.UserId.Value
        Message = $EventLog.Message
    }
    #Determine SID type
    if ($null -ne $EventLog.UserId) {
        $SIDID1 = (($EventLog.UserId.Value.ToString()) -split '-')[3]
        $SIDTest1 = $SIDID1 -in 0..20
    }
    #Test for Get-ADUser abilities. Will reports AD user if able
    $ADUserAbility = (Get-Command Get-ADUser -ErrorAction SilentlyContinue).count -gt 0
    if ($null -eq $EventLog.UserId) {
        $NewEvent.User = 'None/Unknown'
    } elseif ($SIDTest1 -eq $false) {
        if ($ADUserAbility -eq $true) {
            $NewEvent.User = (Get-ADUser -identity $EventLog.UserId).SamAccountName
        } else {
            $NewEvent.User = $NewEvent.User.ToString() + ' (Undetermined AD account)'
        }
    } else {
        if ($EventLog.UserId -eq 'S-1-5-19') {
            $NewEvent.User = 'NT Authority (LocalService)'
        } elseif ($EventLog.UserId -eq 'S-1-5-18') {
            $NewEvent.User = 'System'
        } else {
            $NewEvent.User = $NewEvent.User.ToString() + ' (Undetermined local account)'
        }
    }
    $NewEvent
}

#Get counts of event level types
$CriticalCount = ($EventsReformat | Where-Object -Property Level -EQ 'Critical')
if (($null -ne $CriticalCount) -and ($null -eq $CriticalCount.Count)) {
    $CriticalCount = 1
} else {
    $CriticalCount = $CriticalCount.Count
}
$ErrorCount = ($EventsReformat | Where-Object -Property Level -EQ 'Error')
if (($null -ne $ErrorCount) -and ($null -eq $ErrorCount.Count)) {
    $ErrorCount = 1
} else {
    $ErrorCount = $ErrorCount.Count
}
$WarningCount = ($EventsReformat | Where-Object -Property Level -EQ 'Warning')
if (($null -ne $WarningCount) -and ($null -eq $WarningCount.Count)) {
    $WarningCount = 1
} else {
    $WarningCount = $WarningCount.Count
}
$InfoCount = ($EventsReformat | Where-Object -Property Level -EQ 'Information')
if (($null -ne $InfoCount) -and ($null -eq $InfoCount.Count)) {
    $InfoCount = 1
} else {
    $InfoCount = $InfoCount.Count
}
$RebootEventCount = $CriticalCount + $ErrorCount + $WarningCount + $InfoCount

#Set exit depending on types of events found
if (($CriticalCount -gt 0) -or ($ErrorCount -gt 0)) {
    $LASTEXITCODE = 2
} elseif ($WarningCount -gt 0) {
    $LASTEXITCODE = 1
} elseif ($InfoCount -gt 0) {
    $LASTEXITCODE = 0
} elseif ($RebootEventCount -lt 1) {
    $LASTEXITCODE = 0
} else {
    $LASTEXITCODE = 3
}

#Adjust exit code based on uptime
if ($ActualUptime -lt $WarningUptime) {
    $LASTEXITCODE = 1
    if (($CriticalCount -gt 0) -or ($ErrorCount -gt 0)) {
        $LASTEXITCODE = 2
    }
    if ($ActualUptime -lt $CriticalUptime) {
        $LASTEXITCODE = 2
    }
} elseif ($ActualUptime -ge $WarningUptime) {
    $LASTEXITCODE = $LASTEXITCODE
} else {
    $LASTEXITCODE = 3
}

#Output
$UptimeMessage = $UptimeMessage + " with $RebootEventCount reboot events in the past $MaxEventAge hours"
if ($LASTEXITCODE -eq 0) {
    'OK: ' + $UptimeMessage
} elseif ($LASTEXITCODE -eq 1) {
    'WARNING: ' + $UptimeMessage
} elseif ($LASTEXITCODE -eq 2) {
    'CRITICAL: ' + $UptimeMessage
} else {
    'UNKNOWN: ' + $UptimeMessage
}

Write-Output "Warning trigger:  $WarningUptime hours"
Write-Output "Critical trigger: $CriticalUptime hours"
Write-Output "Max event age:    $MaxEventAge hours"

if ($Null -ne $EventsReformat) {
Write-Output '
=====
Events
====='
    Write-Output $EventsReformat
}
exit $LASTEXITCODE
