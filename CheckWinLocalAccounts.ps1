# Check for 
#   - User accounts and report any missing or extra ones
#   - User accounts that shouldn't be local admin or are missing from the local admin group
#   - User accounts that should and should not be enabled
# This will not do recursion on groups
# For example, GroupB is in the Administrators group. GroupB will not be enumerated to check for each individual user
# The script will deal only with a local or domain user or group that is a direct member of the Administrators group

$ComputerName = (Get-ComputerInfo -Property CsDNSHostName).CsDNSHostName
$Domain = (Get-ADDomain).NetBIOSName
$ShouldBeLocalAccounts = @(
    'Administrator',
    'DefaultAccount',
    'Guest',
    'WDAGUtilityAccount',
    'OtherAdmin'
)
$ShouldBeEnabledAccounts = @(
    'OtherAdmin'
)
# Group names also work for the $ShouldBeAdminAccounts variable
# It includes the $ComputerName and $Domain variables in front because the get command for local groups returns user accounts with the domain or computername in front
$ShouldBeAdminAccounts = @(
    "$ComputerName\Administrator",
    "$ComputerName\OtherAdmin",
    "$Domain\Domain Admins"
)
$AllLocalUsers = Get-LocalUser | Select-Object -Property *

#-------------

Clear-Host

# Get local account info

$ShouldNotBeLocalAccounts = $AllLocalUsers | Where-Object {$_.Name -notin $ShouldBeLocalAccounts}
$MissingLocalAccounts = $ShouldBeLocalAccounts | Where-Object {$_ -notin $AllLocalUsers.Name}

# Get enabled info

$ShouldNotBeEnabledAccounts = $AllLocalUsers | Where-Object -Property Enabled -eq $true | Where-Object -Property Name -notin $ShouldBeEnabledAccounts
$MissingEnabledAccounts = $AllLocalUsers | Where-Object -Property Enabled -eq $false | Where-Object -Property Name -in $ShouldBeEnabledAccounts

# Get admin info

$Admins = Get-LocalGroupMember 'Administrators' | Select-Object -Property *
$ShouldNotBeAdmins = $Admins | Where-Object {$_.Name -notin $ShouldBeAdminAccounts}
$MissingAdminAccounts = $ShouldBeAdminAccounts | Where-Object {$_ -notin $Admins.Name}

# Report

if ($ShouldNotBeAdmins.count -gt 0) {
    Write-Output 'CRITICAL: Some accounts that should NOT be admins are'
    $Output = 'Accounts: '
    $Output += $ShouldNotBeAdmins.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE = 2
} elseif ($MissingAdminAccounts.count -gt 0) {
    Write-Output 'CRITICAL: Some accounts that SHOULD be admins are not'
    $Output = 'Accounts: '
    $Output += $MissingAdminAccounts.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE = 2
} elseif ($ShouldNotBeLocalAccounts.count -gt 0) {
    Write-Output 'WARNING: There are additional local accounts'
    $Output = 'Accounts: '
    $Output += $ShouldNotBeLocalAccounts.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE = 1
} elseif ($MissingLocalAccounts.count -gt 0) {
    Write-Output 'WARNING: There are missing local accounts'
    $Output = 'Accounts: '
    $Output += $MissingLocalAccounts.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE
} elseif ($ShouldNotBeEnabledAccounts.count -gt 0) {
    Write-Output 'WARNING: Some accounts that should NOT be enabled are'
    $Output = 'Accounts: '
    $Output += $ShouldNotBeEnabledAccounts.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE = 1
} elseif ($MissingEnabledAccounts.count -gt 0) {
    Write-Output 'WARNING: Some accounts that SHOULD be enabled are not'
    $Output = 'Accounts: '
    $Output += $MissingEnabledAccounts.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE = 1
} else {
    Write-Output 'OK: All accounts and groups are as they should be'
    $Output = 'Local accounts:   '
    $Output += $AllLocalUsers.Name -join ', '
    Write-Output $Output
    $Output = 'Enabled accounts: '
    $Output += ($AllLocalUsers | Where-Object -Property Enabled -eq $true).Name -join ', '
    Write-Output $Output
    $Output = 'Admin accounts:   '
    $Output += $Admins.Name -join ', '
    Write-Output $Output
    $LASTEXITCODE = 0
}

exit $LASTEXITCODE
