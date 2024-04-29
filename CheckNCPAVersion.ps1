#Check for latest version of NCPA

[System.IO.FileInfo]$NCPAExe = $env:ProgramFiles + '\Nagios\NCPA\ncpa.exe'
[System.UriBuilder]$NCPAVersionURL = 'https://raw.githubusercontent.com/NagiosEnterprises/ncpa/master/VERSION'

#Forces TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$LatestVersion = ((Invoke-WebRequest $NCPAVersionURL.Uri -UseBasicParsing).Content).TrimEnd('')
$CurrentVersion = $NCPAExe.VersionInfo.ProductVersion

#------------------------

if (!(Test-Path $NCPAExe)) {
    Write-Output 'CRITICAL: NCPA not found'
    $LASTEXITCODE = 2
}

if ($CurrentVersion -eq $LatestVersion) {
    Write-Output 'OK: NCPA is up to date'
    Write-Output "Current verison is $CurrentVersion and the latest version is $LatestVersion"
    $LASTEXITCODE = 0
} elseif ($CurrentVersion -ne $LatestVersion) {
    Write-Output 'WARNING: NCPAis out of date'
    Write-Output "Current verison is $CurrentVersion and the latest version is $LatestVersion"
    $LASTEXITCODE = 1
} else {
    Write-Output 'UNKNOWN: Unknown issue'
    $LASTEXITCODE = 3
}

exit $LASTEXITCODE
