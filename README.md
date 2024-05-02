# NagiosPlugins
Various Nagios plugins

## [CheckNCPAVersion.ps1](./CheckNCPAVersion.ps1)

- Checks if current NCPA installed is up to date based on the latest github release

### Arguments

- N/A

### Example

- `check_ncpa.py -t 'TOKEN' -P 5693 -M 'plugins/CheckNCPAVersion.ps1'`

## [CheckPSSignatures.ps1](./CheckPSSignatures.ps1)

- Checks if any PS scripts in the plugin folder have a soon to expire, expired, invalid, or non-existent signature. Arguments represent the number of days left until a signature expires. Any invalid or expired signatures will be considered critical

### Arguments

- WARNING: Threshold for the number of days left until a signature is considered soon to expire
- CRITICAL: Threshold for the number of days left until a signature is considered soon to expire

### Example

- `check_ncpa.py -t 'TOKEN' -P 5693 -M 'plugins/CheckScriptCertExperation.ps1/14/7'`
- This will send a warning alert when a signature is about to expire in 14 or less days and then change to critical when it expires in 7 or less days

## [CheckWinLocalAccounts.ps1](./CheckWinLocalAccounts.ps1)

- Checks if specified users & groups are present, enabled, and an administrator on a local PC
- Variables can be configured to specify each group
- **<ins>Currently not on Nagios Exchange</ins>**

### Arguments

- N/A

### Example

- `check_ncpa.py -t 'TOKEN' -P 5693 -M 'plugins/CheckWinLocalAccounts.ps1'`
