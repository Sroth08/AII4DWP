# Root Cause Analysis (RCA): Finance Shared Drive Access Failure After Intune Migration

## 1. Executive Summary
Following an overnight migration of the Finance drive-mapping mechanism from a GPO Logon Script (USER context) to an Intune PowerShell Script (SYSTEM context), approximately 45 Finance users were unable to access their Finance shared drive (S:) at the start of business hours. Investigation of Intune Management Extension logs, system logs, and the migration change record confirmed the new script executed but failed because it ran in the SYSTEM account context, which cannot present the user credentials required to reach the UNC path \\finbridge-fs01\Finance. The script was updated to run using the signed-on user's credentials and redeployed via Intune. Resolution was implemented and verified at 09:30 AM, with drive mappings, share access, and script execution confirmed restored for multiple Finance users.

## 2. Incident Overview
- **Symptom:** Finance users could not access their Finance shared drive.
- **Reported:** Start of business hours.
- **Resolution time:** 09:30 AM.
- **Trigger:** Migration of drive mapping delivery from a GPO Logon Script (USER context) to an Intune PowerShell Script (SYSTEM context), completed 2024-03-14 23:30.
- **Mechanism confirmed unaffected:** Group Policy processing (Event 1500 logged successfully).

## 3. Business Impact
- Approximately 45 Finance users were unable to access shared Finance drive resources at the start of the business day.
- Impact was limited to shared drive mapping availability (S: drive); Group Policy processing was confirmed unaffected.

## 4. Scope of Impact
- **Affected users:** Approximately 45 Finance users.
- **Affected systems:** DESKTOP-FB* devices in OU=Finance.
- **Scope:** All Finance users affected.
- **Unaffected mechanism:** Group Policy processing, confirmed successful (Event 1500).

## 5. Timeline of Events
| Time | Event |
|---|---|
| 2024-03-14 23:30 | Drive mapping migrated from GPO Logon Script (USER context) to Intune PowerShell Script (SYSTEM context); script not updated to support SYSTEM execution context. |
| 08:00:01 | Intune Management Extension: ScriptRunner begins executing Map-FinBridgeDrives.ps1. |
| 08:00:02 | ScriptRunner logs script context as SYSTEM account. |
| 08:00:03 | ScriptRunner Warning: network path \\finbridge-fs01\Finance not accessible from SYSTEM context. |
| 08:00:03 | ScriptRunner Error: script failed, exit code 1, "Network name cannot be found." |
| 08:00:04 | ScriptRunner logs no retry configured. |
| 08:00:05 | Service Control Manager Event 7036: Workstation service entered running state. |
| 08:00:06 | GroupPolicy Event 1500: Group Policy settings processed successfully. |
| 08:00:07 | Ntfs Event 98 (Warning): could not map drive letter S:, drive letter has not been assigned. |
| Start of business hours | Issue reported by Finance users; all Finance users affected. |
| 09:30 AM | Resolution implemented; verified results confirmed. |

## 6. Supporting Evidence

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

### Migration Change Record
- 2024-03-14 23:30: Drive mapping script migrated from GPO Logon Script (USER context) to Intune PowerShell Script (SYSTEM context).
- Script was not updated to support SYSTEM execution context.
- UNC path access requires user context and mapped credentials that are unavailable to SYSTEM during login.

## 7. Investigation Activities
- Reviewed scope facts and known facts describing the symptom, affected population, timing, and recent change.
- Developed five ranked hypotheses covering script execution, assignment/targeting, execution context, share/server health, and deployment timing.
- Collected and reviewed Intune Management Extension logs, system logs, and the migration change record for an affected device (DESKTOP-FB041).
- Evaluated each hypothesis individually against the collected evidence, citing specific log entries and timestamps.
- Identified the surviving hypothesis and confirmed it as the verified root cause.
- Implemented and validated the corresponding resolution.

## 8. Hypothesis Analysis
1. **Intune PowerShell script is not executing on affected devices** — CONTRADICTS. 08:00:01 confirms the script executed; failure occurred later, during network access, not at launch.
2. **Intune script is not assigned/targeted to the correct device or user group** — CONTRADICTS. 08:00:01 execution on DESKTOP-FB041 confirms assignment/targeting reached the device.
3. **Script execution context lacks required permissions to map the drive** — SUPPORTS and confirmed as the root cause. 08:00:02 (SYSTEM account context), 08:00:03 (Warning: not accessible from SYSTEM context; Error: Network name cannot be found), and the migration change record together confirm the script cannot present user credentials for the UNC path.
4. **Underlying file server/share is unreachable or permissions changed independent of the migration** — CONTRADICTS. 08:00:03 attributes the failure specifically to SYSTEM-context access, not to general share/server unreachability.
5. **Intune policy/script deployment has not yet reached all devices (delayed check-in)** — CONTRADICTS. 08:00:01 confirms the script had already been delivered and executed at the start of business hours.

## 9. Verified Root Cause
The Intune PowerShell script (Map-FinBridgeDrives.ps1) runs in the SYSTEM execution context and was not updated to support this context following the migration from the GPO Logon Script (USER context), so it cannot present the user's credentials required to reach the UNC path \\finbridge-fs01\Finance. This is confirmed by 08:00:02 (Script context: SYSTEM account), 08:00:03 (Network path not accessible from SYSTEM context; Network name cannot be found), and the migration change record, and it fully accounts for the downstream Ntfs Event 98 (08:00:07, could not map drive letter S:) while leaving Group Policy processing (Event 1500, 08:00:06) unaffected.

## 10. Resolution Activities
1. Updated Map-FinBridgeDrives.ps1 to map the drive using the signed-in user's credentials/context rather than SYSTEM-context network access.
2. Enabled "Run this script using the logged-on credentials" in the Intune script configuration for Map-FinBridgeDrives.ps1.
3. Redeployed/reassigned the updated script to the Finance device/user group in Intune.
4. Forced an Intune policy sync on affected devices to pull the updated script.
5. Resolution implemented at 09:30 AM.

## 11. Validation and Recovery Verification
Verified results confirmed at 09:30 AM:
- Finance shared drives are successfully mapped.
- Users can access \\finbridge-fs01\Finance.
- Drive letter S: is assigned correctly.
- No further script execution failures observed.
- Multiple Finance users confirmed access is restored.

## 12. 5 Why Analysis
**Problem Statement:** Finance users could not access their Finance shared drive at the start of business hours.

- **Why 1:** Why could Finance users not access the shared drive? Because drive letter S: was not assigned (Ntfs Event 98, 08:00:07).
- **Why 2:** Why was drive letter S: not assigned? Because the Map-FinBridgeDrives.ps1 script failed with "Network name cannot be found" (ScriptRunner Error, 08:00:03).
- **Why 3:** Why did the script fail to reach the network path? Because the network path \\finbridge-fs01\Finance was not accessible from the script's execution context (ScriptRunner Warning, 08:00:03).
- **Why 4:** Why was the network path not accessible from that context? Because the script ran under the SYSTEM account (ScriptRunner Info, 08:00:02), which does not carry the user's credentials needed for the UNC path.
- **Why 5:** Why did the script run under SYSTEM without user credentials? Because the migration from the GPO Logon Script (USER context) to the Intune PowerShell Script (SYSTEM context) on 2024-03-14 23:30 did not update the script to support the new execution context (Migration Change Record).

## 13. Preventive Actions
- When migrating logon/drive-mapping mechanisms between execution contexts (e.g., GPO USER-context scripts to Intune SYSTEM-context scripts), explicitly verify and configure the required run context before cutover.
- Include a pre-migration validation step that confirms UNC/share access succeeds under the new script's actual execution context prior to full rollout.
- Review other scripts migrated as part of the same change for the same USER-to-SYSTEM context assumption.

## 14. Lessons Learned
- A change that leaves Group Policy processing unaffected does not rule out related delivery mechanisms (Intune scripts) as the cause; each mechanism must be verified independently.
- Execution context (SYSTEM vs. signed-in user) is a critical, easily overlooked variable when migrating scripts that depend on network share access with user credentials.
- Intune Management Extension logs (script execution, context, and error detail) combined with system-level events (Ntfs Event 98) provided sufficient evidence to isolate the root cause without requiring assumptions beyond the data collected.
