#Check each powershell plugin in the plugins folder to see when script signing cert will expire

$PluginsFolder = "$env:ProgramFiles\Nagios\NCPA\plugins"
#$PluginsFolder = 'C:\\Program Files\\Nagios\NCPA\\plugins'
$PowerShellExtensions = @('.ps1','.psm1','.psd1','.ps1xml','.pssc')
[int]$WarningThreshold = $args[0]
[int]$CriticalThreshold = $args[1]

#----------------

Clear-Host

if (($null -eq $WarningThreshold) -or (0 -eq $WarningThreshold)) {
    Write-Output 'WARNING threshold parameter not specified'
    $LASTEXITCODE = 3
    exit $LASTEXITCODE
}
if (($null -eq $CriticalThreshold) -or (0 -eq $CriticalThreshold)) {
    Write-Output 'CRITICAL threshold parameter not specified'
    $LASTEXITCODE = 3
    exit $LASTEXITCODE
}
if ($WarningThreshold -le $CriticalThreshold) {
    Write-Output "CRITICAL threshold ($($CriticalThreshold)) must be less than WARNING threshold ($($WarningThreshold))"
    $LASTEXITCODE = 3
    exit $LASTEXITCODE
}
if (!(Test-Path $PluginsFolder)) {
    Write-Output 'Unknown: Plugin folder not found'
    $LASTEXITCODE = 3
    exit $LASTEXITCODE
} else {
    $PluginFiles = Get-ChildItem $PluginsFolder | Where-Object {($_.Mode -eq '-a----') -and ($_.Extension -in $PowerShellExtensions)}
    if ($null -eq $PluginFiles) {
        $LASTEXITCODE = 3
    }
    $SignStatus = foreach ($Plugin in $PluginFiles) {
        Get-AuthenticodeSignature $Plugin.FullName
    }
}

$Time = Get-Date

$CertStatus = foreach ($Plugin in $SignStatus) {
    if ($null -ne $Plugin.SignerCertificate) {
        $WarningStatus = $Plugin.SignerCertificate.NotAfter.AddDays(-$WarningThreshold) -lt $Time
        $Plugin | Add-Member -MemberType NoteProperty -Name WarningStatus -Value $WarningStatus -Force
        $CriticalStatus = $Plugin.SignerCertificate.NotAfter.AddDays(-$CriticalThreshold) -lt $Time
        $Plugin | Add-Member -MemberType NoteProperty -Name CriticalStatus -Value $CriticalStatus -Force
        $ShortName = $Plugin.Path -split '\\' | Select-Object -Last 1
        $Plugin | Add-Member -MemberType NoteProperty -Name ShortName -Value $ShortName -Force
    } else {
        $ShortName = $Plugin.Path -split '\\' | Select-Object -Last 1
        $Plugin | Add-Member -MemberType NoteProperty -Name ShortName -Value $ShortName -Force
        $Plugin | Add-Member -MemberType NoteProperty -Name WarningStatus -Value $false -Force
        $Plugin | Add-Member -MemberType NoteProperty -Name CriticalStatus -Value $true -Force
    }
    $Plugin
}

$InvalidCerts = $CertStatus | Where-Object -Property Status -ne 'Valid'
if ($InvalidCerts.count -gt 0) {
    $LASTEXITCODE = 2
    Write-Output "CRITICAL: $($InvalidCerts.Count) plugin signatures are not valid"
    Write-Output ($InvalidCerts.ShortName -join ', ')
    exit $LASTEXITCODE
}

$WarningOnlyCerts = $CertStatus | Where-Object {($_.WarningStatus -eq $true) -and ($_.CriticalStatus -eq $false)} | Select-Object -Property ShortName,Path,WarningStatus
$CriticalOnlyCerts = $CertStatus | Where-Object {$_.CriticalStatus -eq $true} | Select-Object -Property ShortName,Path,CriticalStatus

if (($WarningOnlyCerts.Count -gt 0) -and $CriticalOnlyCerts.Count -lt 1) {
    $LASTEXITCODE = 1
    Write-Output "WARNING: $($WarningOnlyCerts.Count) plugin signatures are expiring in $WarningThreshold or less days"
    Write-Output ($WarningOnlyCerts.ShortName -join ', ')
} elseif ($CriticalOnlyCerts.Count -gt 0) {
    $LASTEXITCODE = 2
    Write-Output "CRITICAL: $($CriticalOnlyCerts.Count) plugin signatures are expiring in $CriticalThreshold or less days"
    Write-Output ($CriticalOnlyCerts.ShortName -join ', ')
    if ($WarningOnlyCerts.Count -gt 0) {
        Write-Output 'WARNING expiring plugins: '($WarningOnlyCerts.ShortName -join ', ')
    }
} elseif (($WarningOnlyCerts.Count -lt 1) -and ($CriticalOnlyCerts.Count -lt 1) -and ($PluginFiles.Count -gt 0)) {
    $LASTEXITCODE = 0
    Write-Output "OK: No plugin signatures are expiring in $WarningThreshold or less days"
    Write-Output 'Plugins:'($CertStatus.ShortName -join ', ')
} else {
    $LASTEXITCODE = 3
    Write-Output 'Unknown: No plugins in folder or unable to access folder'
}

exit $LASTEXITCODE
