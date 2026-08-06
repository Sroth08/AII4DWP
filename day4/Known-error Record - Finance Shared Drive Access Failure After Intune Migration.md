# Known-error Record - Finance Shared Drive Access Failure After Intune Migration

Symptom: Finance users are unable to access their Finance shared drive; the S: drive mapping is unavailable following sign-in, with no fallback mapping present.

Cause: The Intune PowerShell script (Map-FinBridgeDrives.ps1) that replaced the GPO Logon Script runs in the SYSTEM execution context, which cannot present the signed-in user's credentials required to reach the UNC path \\finbridge-fs01\Finance, causing the drive mapping script to fail.

Scope: All Finance users (approximately 45) on DESKTOP-FB* devices in OU=Finance; Group Policy processing on these devices is unaffected.

Workaround: Manually connect to \\finbridge-fs01\Finance and map drive S: using the signed-in user's own credentials until the corrected script is deployed to the device.

Permanent Fix: The Map-FinBridgeDrives.ps1 script was updated to run using the signed-in user's credentials/context instead of SYSTEM, and the corrected script was redeployed to affected Finance devices via Intune.

How to Spot It:
- ScriptRunner log entries: Intune Management Extension log shows "Executing: Map-FinBridgeDrives.ps1" followed by "Script context: SYSTEM account."
- Intune Management Extension messages: Warning "Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time" and Info "No retry configured."
- Error messages: ScriptRunner Error "Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found."
- Event IDs: Ntfs Event 98 (Warning) "File system could not map drive letter S:; drive letter has not been assigned"; GroupPolicy Event 1500 continues to log successfully, confirming Group Policy is not the affected mechanism.
- Drive mapping failures: Drive letter S: is not assigned to the user's session after sign-in.
- Script execution context: Script context recorded as SYSTEM account rather than the signed-in user.
