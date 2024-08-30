#Check Windows activation status
#Link: https://learn.microsoft.com/en-us/previous-versions/windows/desktop/sppwmi/softwarelicensingproduct
#0: Unlicensed
#1: Licensed
#2: Out of tolerance grace
#3: Out of the box grace
#4: Non-genuine grace
#5: Notification
#6: Extended grace

$TimeFormat = 'MM-dd-yyyy'

#--------

#Possible status
$StatusPrefix = @(
    'OK: ','WARNING: ','CRITICAL: '
)

#Get activation info
$ActivationInfo = (Get-WmiObject -Query 'SELECT * FROM SoftwareLicensingProduct WHERE Name LIKE "%Windows%" AND PartialProductKey <> null')
$ActivationStatus = $ActivationInfo.LicenseStatus

#DateTime conversions
function ConvertDate {
    param (
        $Date
    )
    $Error.Clear()
    if ($Date -match "(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})") {
        $Year = [int]$matches[1]
        $Month = [int]$matches[2]
        $Day = [int]$matches[3]
        $Hour = [int]$matches[4]
        $Minute = [int]$matches[5]
        $Second = [int]$matches[6]
        $DateTime = New-Object DateTime($Year,$Month,$Day,$Hour,$Minute,$Second)
        if ($Error.Count -gt 0) {
            [string]$DateTimeReturn = 'Error converting to date format'
            $LASTEXITCODE = 2
        } else {
            [string]$DateTimeReturn = $DateTime.ToString($TimeFormat)
            if ($DateTimeReturn -eq '01-01-1601') {
                [string]$DateTimeReturn = 'Eternity'
            }
        }
    } else {
        [string]$DateTimeReturn = 'Invalid date format'
        $LASTEXITCODE = 2
    }
    $DateTimeReturn
}

function AddMinutesToDate {
    param (
        $AddMinutes
    )
    $Error.Clear()
    if (($AddMinutes.ToString().Length -gt 8) -or ($AddMinutes -eq '-0')) {
        [string]$DateTimeReturn = 'Eternity'
    } else {
        $Date = Get-Date
        $Date = $Date.AddMinutes($AddMinutes)
        [string]$DateTimeReturn = $Date.ToString($TimeFormat)
        if ($Error.Count -gt 0) {
            [string]$DateTimeReturn = 'Error converting to date format'
        }
    }
    $DateTimeReturn
}

if ($ActivationStatus.Count -gt 1) {
    $StatusMessage = 'More than 1 Windows product detected'
    $LASTEXITCODE = 3
}
if ($ActivationStatus.Count -lt 1) {
    $StatusMessage = 'Did not find any license info'
    $LASTEXITCODE = 3
}
if ($ActivationInfo.GenuineStatus -ne 0) {
    $StatusMessage = 'Windows is not genuine'
    $LASTEXITCODE = 2
}

#Set status message
if (($LASTEXITCODE -eq 0) -or ($StatusMessage = 'Windows is not genuine')) {
    switch ($ActivationStatus) {
        0 {
            $StatusMessage = "Unlicensed"
            $LASTEXITCODE = 2
        }
        1 {
            $StatusMessage = 'Licensed'
            $LASTEXITCODE = 0
        }
        2 {
            $StatusMessage = 'Out of grace tolerance'
            $LASTEXITCODE = 2
        }
        3 {
            $StatusMessage = 'Out of box grace'
            $LASTEXITCODE = 2
        }
        4 {
            $StatusMessage = 'Non-genuine grace'
            $LASTEXITCODE = 2
        }
        5 {
            $StatusMessage = 'Notification'
            $LASTEXITCODE = 1
        }
        6 {
            $StatusMessage = 'Extended grace'
            $LASTEXITCODE = 1
        }
    }
}

#Report
#------

if ($ActivationInfo.GenuineStatus -ne 0) {
    $LASTEXITCODE = 2
}
$Status = $StatusPrefix[$LASTEXITCODE] + $StatusMessage
Write-Output $Status
if ($LASTEXITCODE -ne 3) {
Write-Output "License Info
------------
Name:              $($ActivationInfo.Name)
Description:       $($ActivationInfo.Description)
License Family:    $($ActivationInfo.LicenseFamily)
Channel:           $($ActivationInfo.ProductKeyChannel)
Partial Key:       $($ActivationInfo.PartialProductKey)
Evaluation End:    $(ConvertDate $ActivationInfo.EvaluationEndDate)
Extended Grace:    $(AddMinutesToDate $ActivationInfo.ExtendedGrace)
Genuine Status:    $(if ($ActivationInfo.GenuineStatus -eq 0) {$true} else {$false})
Grace Period Ends: $(AddMinutesToDate $ActivationInfo.GracePeriodRemaining)"
}

exit $LASTEXITCODE
