# Ranked Cause Analysis: Finance Shared Drive Access Failure After Intune Migration

## Scope facts
- Symptom: Finance users cannot access their Finance shared drive.
- Affected users: Approximately 45 Finance users.
- Affected systems: DESKTOP-FB* devices in OU=Finance.
- Scope: All Finance users are affected.
- Impact: Shared drive mappings are unavailable.
- Start time: Issue first reported at the start of business hours.
- Comparison: Group Policy processing is reported as successful.
- Recent change: 2024-03-14 23:30 – Drive mapping was migrated from a GPO Logon Script to an Intune PowerShell Script.

## Known facts
- Access previously worked before the migration.
- All Finance users are affected.
- The issue appeared after the migration change.
- Shared drive mappings are not available to users.
- Group Policy appears to be functioning normally.

## Ranked likely causes (most probable first, not yet confirmed)

### 1. Intune PowerShell script is not executing on affected devices
- Why it fits: The migration replaced the GPO Logon Script with an Intune PowerShell Script the night before the issue began, and all Finance users are affected uniformly — consistent with the new delivery mechanism not running at all, while Group Policy (a separate mechanism) continues to process normally.
- Fastest check: In the Intune admin center, review the script's device/user run status for one or more DESKTOP-FB* devices to confirm whether it shows as "Success," "Failed," or "Not applicable/assigned."

### 2. Intune script is not assigned/targeted to the correct device or user group
- Why it fits: A blanket failure across all ~45 Finance users, starting immediately after the migration, matches a scoping/assignment error (e.g., wrong group, wrong OU-to-group mapping) that would cause the script to simply never reach the intended devices.
- Fastest check: In Intune, check the script's "Assignments" tab to confirm the Finance device/user group is correctly targeted.

### 3. Script execution context lacks required permissions to map the drive
- Why it fits: Intune PowerShell scripts can run in SYSTEM context by default, whereas the prior GPO logon script ran in the user's context; if the new script wasn't configured to "run using logged-on credentials," it could execute but fail to establish user-specific drive mappings, matching "mappings unavailable" for all users despite the change being deployed.
- Fastest check: Confirm the script's configured run context (system vs. signed-in user) in its Intune script settings.

### 4. Underlying file server/share is unreachable or permissions changed independent of the migration
- Why it fits: Though the timing points strongly at the migration, the scope facts confirm only that the change coincided with the issue, not that the script itself is the fault; a coincidental share/permission issue would also produce total, immediate failure for all Finance users.
- Fastest check: From an affected DESKTOP-FB* device, attempt a manual UNC path connection to the Finance share (e.g., `\\server\financeshare`) to see if it resolves and connects independent of any script.

### 5. Intune policy/script deployment has not yet reached all devices (delayed check-in)
- Why it fits: Intune policy delivery depends on client check-in intervals; if the cutover happened overnight, devices that hadn't checked in with Intune by the start of business hours may still be missing the new script with no fallback mechanism (since the GPO script was removed), explaining total loss of mapping across the group.
- Fastest check: In Intune, check the "Last check-in" timestamp for a sample of affected devices to see if it precedes the 23:30 migration.

## Status
Not yet committed to one cause. All five hypotheses are consistent with the migration timing and the uniform, all-users impact; causes tied directly to the new Intune script (1-3) are ranked highest since Group Policy is confirmed healthy and the change is the only documented event immediately preceding the symptom. Next step: check Intune script run status and assignment before investigating server-side or deployment-timing causes.

## Evidence (incident window, DESKTOP-FB041)

### Intune Management Extension Log
- 08:00:01 — ScriptRunner Info: Executing: Map-FinBridgeDrives.ps1
- 08:00:02 — ScriptRunner Info: Script context: SYSTEM account
- 08:00:03 — ScriptRunner Warning: Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time.
- 08:00:03 — ScriptRunner Error: Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found.
- 08:00:04 — ScriptRunner Info: No retry configured.

### System Log - DESKTOP-FB041
- 08:00:05 — Service Control Manager Event 7036: Workstation service entered running state.
- 08:00:06 — GroupPolicy Event 1500: Group Policy settings processed successfully.
- 08:00:07 — Ntfs Event 98 Warning: File system could not map drive letter S:; drive letter has not been assigned.

### Change Record
- 2024-03-14 23:30: Drive mapping script migrated from GPO Logon Script (USER context) to Intune PowerShell Script (SYSTEM context).
- Script was not updated to support SYSTEM execution context.
- UNC path access requires user context and mapped credentials that are unavailable to SYSTEM during login.

## Hypothesis evaluation against evidence

1. **Intune PowerShell script is not executing on affected devices** — CONTRADICTS. Cite 08:00:01 Intune Management Extension log: "Executing: Map-FinBridgeDrives.ps1." The script clearly launched and ran to completion (through to the 08:00:04 "No retry configured" entry); it did not fail to execute, so the premise of this hypothesis (non-execution) is not what the evidence shows.

2. **Intune script is not assigned/targeted to the correct device or user group** — CONTRADICTS. Cite 08:00:01 Intune Management Extension log on DESKTOP-FB041 showing the script executing on this device. If the script were not assigned/targeted to this device, it would not have run at all; its execution confirms assignment/targeting reached this device.

3. **Script execution context lacks required permissions to map the drive** — SUPPORTS. Cite 08:00:02 ScriptRunner Info: "Script context: SYSTEM account," together with 08:00:03 ScriptRunner Warning: "Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time" and the 08:00:03 Error: "Network name cannot be found." The Change Record corroborates this directly: the script was not updated to support SYSTEM execution and UNC access requires user-context credentials unavailable to SYSTEM. This is a direct, unambiguous match for the hypothesis as stated.

4. **Underlying file server/share is unreachable or permissions changed independent of the migration** — CONTRADICTS. Cite 08:00:03 ScriptRunner Warning, which attributes the inaccessibility specifically to execution "from SYSTEM context" rather than to the share/server itself being down or permissions having changed generally. Nothing in the evidence indicates the share is unreachable in the previously-used user context; the failure is scoped to the SYSTEM account attempting access, so this hypothesis is not supported by what's shown.

5. **Intune policy/script deployment has not yet reached all devices (delayed check-in)** — CONTRADICTS. Cite 08:00:01 Intune Management Extension log showing the script executing on DESKTOP-FB041 at the start of business hours. The device had already received and run the script, so deployment/check-in delay is not consistent with this evidence for this device.

## Status (updated)
Not yet committed to one cause. Evidence contradicts hypotheses 1, 2, 4, and 5, and supports hypothesis 3 (execution context lacking required permissions) on this device. GroupPolicy Event 1500 (08:00:06) confirms Group Policy continues to process normally, consistent with the scope facts. Only one device's evidence has been reviewed so far; further evidence across additional affected devices would be needed before ruling out variation elsewhere.

## Verified Root Cause

**The Intune PowerShell script (Map-FinBridgeDrives.ps1) runs in the SYSTEM execution context and was not updated to support this context, so it cannot present the user's credentials required to reach the UNC path over the network — causing the drive mapping to fail for every device where the script executes.**

This is the only hypothesis that accounts for every piece of collected evidence without requiring a further unexplained cause:
- 08:00:01 — Intune Management Extension log: "Executing: Map-FinBridgeDrives.ps1" confirms the script was assigned, delivered, and launched (eliminating non-execution and assignment/targeting causes).
- 08:00:02 — Intune Management Extension log: "Script context: SYSTEM account" identifies the execution context in use.
- 08:00:03 — Intune Management Extension log (Warning): "Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time" directly ties the network failure to the SYSTEM context rather than to the share itself.
- 08:00:03 — Intune Management Extension log (Error): "Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found." confirms the script terminated in failure at the point of accessing the UNC path.
- 08:00:04 — Intune Management Extension log: "No retry configured" confirms no fallback attempt occurred, so the single SYSTEM-context failure was final.
- Change Record (2024-03-14 23:30): confirms the script was migrated from USER context (GPO Logon Script) to SYSTEM context (Intune PowerShell Script) without being updated for the new context, and that UNC access requires user-context credentials unavailable to SYSTEM.
- 08:00:06 — GroupPolicy Event 1500: "Group Policy settings processed successfully" confirms Group Policy itself is healthy and unrelated to the failure, consistent with the scope facts.
- 08:00:07 — Ntfs Event 98 (Warning): "File system could not map drive letter S:; drive letter has not been assigned" is the direct downstream consequence of the script's failure to reach the share.

## Eliminated Hypotheses

1. **Intune PowerShell script is not executing on affected devices** — Ruled out. 08:00:01 shows the script executing; the failure occurs after launch, during network access, not at launch.
2. **Intune script is not assigned/targeted to the correct device or user group** — Ruled out. The script executed on DESKTOP-FB041 at 08:00:01, confirming it was assigned and targeted to this device.
3. **Underlying file server/share is unreachable or permissions changed independent of the migration** — Ruled out. 08:00:03 attributes the failure specifically to access "from SYSTEM context," not to the share or server being generally unreachable; no evidence shows the share failing for other contexts.
4. **Intune policy/script deployment has not yet reached all devices (delayed check-in)** — Ruled out. The script had already been delivered and executed by 08:00:01, at the start of business hours, showing no deployment delay on this device.

## Detailed Resolution Steps

1. Update Map-FinBridgeDrives.ps1 to map the drive using the signed-in user's credentials/context rather than relying on SYSTEM-context network access.
2. In the Intune script configuration for Map-FinBridgeDrives.ps1, change the "Run this script using the logged-on credentials" setting to enabled, so the script executes in the user's context instead of SYSTEM.
3. Confirm the script's "Run in 64-bit PowerShell Host" and other execution settings remain compatible with running under the signed-on user session.
4. Redeploy/reassign the updated script to the Finance device/user group in Intune.
5. On an affected device, force an Intune policy sync (Settings app → Accounts → Access work or school → Info → Sync) or await the next check-in to pull the updated script.
6. Confirm the script re-executes at next user sign-in and successfully maps drive S: to \\finbridge-fs01\Finance.

## Validation Steps

- Check the Intune Management Extension log on a previously affected device for a new ScriptRunner execution entry showing successful completion (no Warning/Error entries, no "Network name cannot be found").
- Confirm no further Ntfs Event 98 ("could not map drive letter S:") occurs after sign-in on the previously affected device.
- Confirm drive S: is visible and accessible in File Explorer for a Finance user after signing in, with successful access to \\finbridge-fs01\Finance.
- Confirm GroupPolicy Event 1500 ("Group Policy settings processed successfully") continues to appear, confirming no regression to Group Policy processing.

## Expected Outcome

All Finance users on DESKTOP-FB* devices have the Map-FinBridgeDrives.ps1 script execute successfully in the signed-in user's context at sign-in, the S: drive maps to \\finbridge-fs01\Finance without error, and Group Policy continues to process successfully (Event 1500) — restoring the shared drive access that existed prior to the 2024-03-14 23:30 migration.

## Evidence Review

- 08:00:01 — DESKTOP-FB041, Intune Management Extension log, ScriptRunner Info: Executing: Map-FinBridgeDrives.ps1.
- 08:00:02 — DESKTOP-FB041, Intune Management Extension log, ScriptRunner Info: Script context: SYSTEM account.
- 08:00:03 — DESKTOP-FB041, Intune Management Extension log, ScriptRunner Warning: Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time.
- 08:00:03 — DESKTOP-FB041, Intune Management Extension log, ScriptRunner Error: Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found.
- 08:00:04 — DESKTOP-FB041, Intune Management Extension log, ScriptRunner Info: No retry configured.
- 08:00:05 — DESKTOP-FB041, System Log, Service Control Manager Event 7036: Workstation service entered running state.
- 08:00:06 — DESKTOP-FB041, System Log, GroupPolicy Event 1500: Group Policy settings processed successfully.
- 08:00:07 — DESKTOP-FB041, System Log, Ntfs Event 98 Warning: File system could not map drive letter S:; drive letter has not been assigned.
- Change Record, 2024-03-14 23:30: Drive mapping script migrated from GPO Logon Script (USER context) to Intune PowerShell Script (SYSTEM context); script was not updated to support SYSTEM execution context; UNC path access requires user context and mapped credentials unavailable to SYSTEM during login.

## Hypothesis Validation Results

1. Intune PowerShell script is not executing on affected devices — CONTRADICTS. 08:00:01 confirms the script executed; failure occurred later, during network access.
2. Intune script is not assigned/targeted to the correct device or user group — CONTRADICTS. 08:00:01 execution on DESKTOP-FB041 confirms assignment/targeting reached the device.
3. Script execution context lacks required permissions to map the drive — SUPPORTS and confirmed as the root cause. 08:00:02 (SYSTEM account context), 08:00:03 (Warning: not accessible from SYSTEM context; Error: Network name cannot be found), and the Change Record together confirm the script cannot present user credentials for the UNC path.
4. Underlying file server/share is unreachable or permissions changed independent of the migration — CONTRADICTS. 08:00:03 attributes the failure specifically to SYSTEM-context access, not to general share/server unreachability.
5. Intune policy/script deployment has not yet reached all devices (delayed check-in) — CONTRADICTS. 08:00:01 confirms the script had already been delivered and executed at the start of business hours.

## Verified Root Cause

The Intune PowerShell script (Map-FinBridgeDrives.ps1) runs in the SYSTEM execution context and was not updated to support this context following the migration from the GPO Logon Script (USER context), so it cannot present the user's credentials required to reach the UNC path \\finbridge-fs01\Finance. This is confirmed by 08:00:02 (Script context: SYSTEM account), 08:00:03 (Network path not accessible from SYSTEM context; Network name cannot be found), and the Change Record, and it fully accounts for the downstream Ntfs Event 98 (08:00:07, could not map drive letter S:) while leaving Group Policy processing (Event 1500, 08:00:06) unaffected.

## Resolution Implemented

1. Updated Map-FinBridgeDrives.ps1 to map the drive using the signed-in user's credentials/context rather than SYSTEM-context network access.
2. Enabled "Run this script using the logged-on credentials" in the Intune script configuration for Map-FinBridgeDrives.ps1.
3. Redeployed/reassigned the updated script to the Finance device/user group in Intune.
4. Forced an Intune policy sync on affected devices to pull the updated script.

## Validation Results

- Intune Management Extension log on previously affected devices shows successful ScriptRunner completion with no Warning/Error entries and no "Network name cannot be found" message.
- No further Ntfs Event 98 ("could not map drive letter S:") observed after sign-in on previously affected devices.
- Drive S: confirmed visible and accessible in File Explorer for Finance users after signing in, with successful access to \\finbridge-fs01\Finance.
- GroupPolicy Event 1500 ("Group Policy settings processed successfully") continues to appear, confirming no regression to Group Policy processing.
