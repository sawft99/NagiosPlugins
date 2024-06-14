#Checks if latest Wazuh agent is installed

[System.UriBuilder]$LatestVersionURL = 'https://github.com/wazuh/wazuh/releases/latest'
$WazuhVersionFile = ${env:ProgramFiles(x86)} + '\' + 'ossec-agent' + '\' + 'VERSION'
#If more than X minor versions behind, report as critical
#Example if $MaxMinorDif = 4: Latest = 4.8.0, Installed = 4.6.0, reports as warning. If Latest = 4.8.0, Installed = 4.1.0, then it will report as critical
#Being behind by 1 or more major versions is automatically returns CRITICAL
#Being behind by 1 or more build numbers is automatically returns WARNING
$MaxMinorDif = 4

#-----------

if (!(Test-Path $WazuhVersionFile)) {
    Write-Output 'UNKNOWN: Version file could not be found'
    $LASTEXITCODE = 3
    exit $LASTEXITCODE
}

#Forces TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Find latest version from Github
$WebPage = New-Object -ComObject "HTMLFile"
$Content = (Invoke-WebRequest -Uri $LatestVersionURL.Uri -UseBasicParsing).Content.ToString()
$WebPage.write([ref]$Content)
[string]$LatestVersion = ($WebPage.body.innerText -split '\n') | Where-Object {($_ -cmatch 'Wazuh v') -and ($_ -cmatch 'Latest')} | Select-Object -First 1
[version]$LatestVersion = ($LatestVersion -split ' ')[1].TrimStart('v')

#Find currently installed version
[version]$InstalledVersion = (Get-Content $WazuhVersionFile).TrimStart('v')

#Determine difference in version numbers
$MajorDif = $LatestVersion.Major - $InstalledVersion.Major
$MinorDif = $LatestVersion.Minor - $InstalledVersion.Minor

#Report
if ($LatestVersion -eq $InstalledVersion) {
    Write-Output 'OK: Agent is up to date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 0
} elseif (($MajorDif -le 0) -and ($MinorDif -gt 0) -and ($MinorDif -lt $MaxMinorDif)) {
    Write-Output 'WARNING: Agent is out of date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 1
} elseif (($MajorDif -gt 0) -or ($MinorDif -ge $MaxMinorDif)) {
    Write-Output 'CRITICAL: Agent is VERY out of date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 2
} elseif ($LatestVersion -gt $InstalledVersion) {
    Write-Output 'WARNING: Agent is out of date'
    Write-Output "Latest Version:  $LatestVersion"
    Write-Output "Current Version: $InstalledVersion"
    $LASTEXITCODE = 1
} else {
    Write-Output 'UNKNOWN: Issue with determining versions'
    $LASTEXITCODE = 3
}

exit $LASTEXITCODE
