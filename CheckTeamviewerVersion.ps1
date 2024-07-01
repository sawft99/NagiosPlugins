#Check if latest TeamViewer version is installed

[System.UriBuilder]$LatestVersionURL = 'https://www.teamviewer.com/en-us/download/windows/'

#If more than X minor versions behind, report as critical
#Example if $MaxMinorDif = 4: Latest = 15.5.0, Installed = 15.2.0, reports as warning. If Latest = 15.5.0, Installed = 15.0.0, then it will report as critical
#Being behind by 1 or more major versions is automatically critical
#Being behind by 1 or more build numbers is automatically minor
[int]$MaxMinorDif = 4

#---------

#Detect x64 or x86 TV
[System.IO.FileInfo]$TVExe = ${env:ProgramFiles} + '\' + 'TeamViewer' + '\' + 'TeamViewer.exe'

if ($TVExe.Exists -eq $false) {
    [System.IO.FileInfo]$TVExe = ${env:ProgramFiles(x86)} + '\' + 'TeamViewer' + '\' + 'TeamViewer.exe'
}
if ($TVExe.Exists -eq $false) {
    Write-Output 'UNKNOWN: TeamViewer not found or not installed'
    exit 3
}

#Forces TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Find latest version from TV site
#$WebPage = New-Object -ComObject "HTMLFile"
#$Content = (Invoke-WebRequest -Uri $LatestVersionURL.Uri -UseBasicParsing).Content.ToString()
#$WebPage.write([ref]$Content)

#More compatible version
$Content = (Invoke-WebRequest -Uri $LatestVersionURL.Uri -UseBasicParsing).Content

[string]$LatestVersion = ((($Content -split '\n') | Where-Object {$_ -cmatch 'Current version: '} | Select-Object -First 1).TrimStart('Current version: ')).TrimEnd('')
$LatestVersion = $LatestVersion.Trim('<span data-dl-version-label>').trim('</')
$LatestVersion = ($LatestVersion -split '\.' | Select-Object -First 3) -join '.'
[version]$LatestVersion = $LatestVersion

#Compare newest version and current version
[string]$InstalledVersion = $TVExe.VersionInfo.FileVersion
$InstalledVersion = ($InstalledVersion -split '\.' | Select-Object -First 3) -join '.'
[version]$InstalledVersion = $InstalledVersion

#Determine difference in version numbers
$MajorDif = $LatestVersion.Major - $InstalledVersion.Major
$MinorDif = $LatestVersion.Minor - $InstalledVersion.Minor

#Report
if ($LatestVersion -eq $InstalledVersion) {
    Write-Output 'OK: TeamViewer is up to date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 0
} elseif (($MajorDif -le 0) -and ($MinorDif -gt 0) -and ($MinorDif -lt $MaxMinorDif)) {
    Write-Output 'WARNING: TeamViewer is out of date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 1
} elseif (($MajorDif -gt 0) -or ($MinorDif -ge $MaxMinorDif)) {
    Write-Output 'CRITICAL: TeamViewer is VERY out of date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 2
} elseif ($LatestVersion -ne $InstalledVersion) {
    Write-Output 'WARNING: TeamViewer is out of date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 1
} else {
    Write-Output 'UNKNOWN: Issue with determining versions'
    $LASTEXITCODE = 3
}

exit $LASTEXITCODE
