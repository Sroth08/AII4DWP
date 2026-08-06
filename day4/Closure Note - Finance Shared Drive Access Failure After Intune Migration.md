Resolved.
Cause: The Intune PowerShell script (Map-FinBridgeDrives.ps1) that replaced the GPO Logon Script ran in the SYSTEM execution context following the 2024-03-14 23:30 migration, so it could not present the user credentials required to reach the Finance UNC path (\\finbridge-fs01\Finance), causing the shared drive mapping to fail for all Finance users.
Action: The script was updated to run using the signed-in user's credentials/context instead of SYSTEM, and the corrected script was redeployed to affected Finance devices via Intune.
Preventive: When migrating drive-mapping or similar logon mechanisms between execution contexts (e.g., GPO USER-context scripts to Intune SYSTEM-context scripts), explicitly verify and configure the required run context, and validate UNC/share access under the new script's actual execution context before full rollout.
Users confirmed working.
