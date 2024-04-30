# NagiosPlugins
Various Nagios plugins

| Plugin | Purpose | Arguments | Example |
| ------ | ------- | --------- | ------- |
| [CheckExpiredPSSignatures.ps1](./CheckExpiredPSSignatures.ps1) | Checks if any PS scripts in the plugin folder have a soon to expire, expired, invalid, or non-existent signature. Arguments represent the number of days left until a signature expires. Any invalid or expired signatures will be considered critical | Warning/Critical | `check_ncpa.py -t 'TOKEN' -P 5693 -M 'plugins/CheckScriptCertExperation.ps1/14/7'` |
| [CheckNCPAVersion/ps1](./CheckNCPAVersion.ps1) | Checks if current NCPA installed is up to date based on the latest gitub release | N/A | `check_ncpa.py -t 'TOKEN' -P 5693 -M 'plugins/CheckNCPAVersion.ps1'`
