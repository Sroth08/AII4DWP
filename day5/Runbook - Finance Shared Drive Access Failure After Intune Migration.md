# Runbook: Finance Shared Drive Access Failure After Intune Migration

| Field | Value |
|---|---|
| Title | Runbook: Finance Shared Drive Access Failure After Intune Migration |
| Version | 1.0 |
| Date | 07/08/2026 |
| Author | Sourav Roth |
| Reviewed | Self |
| Status | Draft |
| Change | Initial version from RCA |

## Purpose
Restore Finance shared drive (S:) access for users affected by the Intune PowerShell drive-mapping script (Map-FinBridgeDrives.ps1) failing because it runs in the SYSTEM context and cannot present user credentials to \\finbridge-fs01\Finance.

## Applies To
- Affected users: Finance users in OU=Finance (approx. 45 users)
- Affected devices: DESKTOP-FB* devices
- Symptom: Drive letter S: not mapped; no access to \\finbridge-fs01\Finance
- Trigger condition: Drive mapping was migrated from a GPO Logon Script (USER context) to an Intune PowerShell Script (SYSTEM context) within the last 24 hours

## Source Incident
Based on RCA: [RCA - Finance Shared Drive Access Failure After Intune Migration.md](../day4/RCA%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md) — root cause was Map-FinBridgeDrives.ps1 executing under the SYSTEM account after migration from a GPO logon script, so it could not present user credentials needed to reach the UNC path.

---

## Prerequisites

**Access rights:**
- Microsoft Intune admin role with permission to edit and reassign PowerShell scripts (e.g., **Intune Script Manager** or equivalent) — **elevated permission, confirm before starting**
- Local admin rights on affected DESKTOP-FB* devices, for log review and forced sync — **elevated permission, confirm before starting**
- Read access to Intune Management Extension logs on affected devices
- Read access to Event Viewer (System log) on affected devices

**Tools:**
- Microsoft Endpoint Manager admin center (`endpoint.microsoft.com`) access
- Remote access tool to connect to affected devices (e.g., Remote Help, RDP, or Quick Assist)
- Text editor to edit the PowerShell script (e.g., Notepad, VS Code)
- Event Viewer (`eventvwr.msc`)

**System information needed:**
- Script name: Map-FinBridgeDrives.ps1
- File share UNC path: \\finbridge-fs01\Finance
- List of affected device names (e.g., DESKTOP-FB041)
- Migration/change ticket number for the GPO-to-Intune drive mapping cutover
- One test Finance user account to use for verification (with their consent, or a designated test account)
- Azure AD group name the script is assigned to: **Finance-Devices** (confirm the exact name in your tenant before starting — check the migration/change ticket if it differs)

---

## Procedure

1. **Confirm the script is failing on a sample affected device.** Connect to DESKTOP-FB041 (or another reported affected device), open `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` in a text editor, and search for "Map-FinBridgeDrives".
   - *Success looks like:* You find a line showing the script executed, followed by an error line containing "Network name cannot be found" or "not accessible from SYSTEM context".

2. **Confirm the execution context recorded in the log.** In the same log file, locate the line immediately after script start showing "Script context:".
   - *Success looks like:* The line reads "Script context: SYSTEM account".

3. **Confirm the local symptom on the device.** Open `eventvwr.msc` on the same device, expand **Windows Logs > System**, click **Filter Current Log** in the right-hand Actions pane, enter `98` in the **<All Event IDs>** field, enter `Ntfs` in the **Event sources** dropdown, and click **OK**.
   - *Success looks like:* One or more rows appear with Source = "Ntfs", Event ID = 98, and the description reads "The system could not map drive letter S: because the network name is no longer available" (or similar), timestamped close to logon.

4. **Post a "remediation in progress" update in the incident bridge/Teams channel.** Type: "Finance drive mapping confirmed failing due to SYSTEM-context script after Intune migration. Updating script to run as logged-on user. ETA [x]." and send.
   - *Success looks like:* Message appears in the channel with your name and a timestamp.

5. **Open the script in Intune.** Go to `endpoint.microsoft.com` > left menu **Devices** > **Scripts and remediations** > **Platform scripts** tab > select **Map-FinBridgeDrives.ps1**.
   - *Success looks like:* The script's Properties/Overview page loads, showing its current assignment and settings.

6. **Open the script and remove the SYSTEM-only credential logic.** Copy `Map-FinBridgeDrives.ps1` from the device path noted in step 1 (or the Intune script export) to your admin workstation, right-click it and choose **Edit** (opens in Notepad/PowerShell ISE), press `Ctrl+F`, search for `New-PSDrive` and separately for `net use`. On whichever line is present, check for a `-Credential` parameter (e.g., `-Credential $storedCred` or `net use S: \\finbridge-fs01\Finance /user:svc-finance ****`) — this is the SYSTEM-only logic that must be removed. Delete the `-Credential` (or `/user:` and password) portion of that line only, leaving the drive letter (`S`) and path (`\\finbridge-fs01\Finance`) unchanged, then save the file (`Ctrl+S`).
   - *Success looks like:* The line that maps the drive still targets `S` and `\\finbridge-fs01\Finance`, but no longer contains `-Credential`, `/user:`, or a password; the file saves with no red/error underlines in the editor.

7. **Set the script to run using the logged-on user's credentials.** In the script's **Properties**, click **Edit** next to **Settings**, set **Run this script using the logged-on credentials** to **Yes**, and click **Review + save** > **Save**. **Elevated permission required: Intune Script Manager role.**
   - *Success looks like:* The Settings page reflects "Run this script using the logged-on credentials: Yes" after saving.

8. **Upload the corrected script file.** On the script's **Properties** page, click **Edit** next to **Script settings**, click the folder icon next to **Script location**, select the updated `.ps1` file from step 6, and click **Review + save** > **Save**. **Elevated permission required: Intune Script Manager role.**
   - *Success looks like:* The **Script settings** page shows the updated file name and a new "Last modified" timestamp.

9. **Confirm the script assignment still targets the correct group.** On the script's **Properties** page, click **Assignments** in the left menu, and check the group name listed under **Included groups**.
    - *Success looks like:* **Finance-Devices** is listed under Included groups with Assignment type = Required; no change is needed if it is already listed — do not add or remove groups at this step.

10. **Force an Intune policy sync on the sample affected device.** On DESKTOP-FB041, open **Settings** > **Accounts** > **Access work or school** > select the work account > click **Info** > scroll down and click **Sync**. (Alternatively, in Company Portal app, click **Settings gear** > **Sync**.)
    - *Success looks like:* A "Sync in progress" or "Sync completed" message appears within the Settings/Company Portal UI.

11. **Confirm the script re-ran successfully on the sample device.** Reopen `IntuneManagementExtension.log` on DESKTOP-FB041 and search again for "Map-FinBridgeDrives", looking for a run with a timestamp after the sync in step 10.
    - *Success looks like:* The newest log entry for the script shows successful completion with no "Network name cannot be found" error.

12. **Confirm the drive is mapped on the sample device.** On DESKTOP-FB041, open **File Explorer** and check **This PC**.
    - *Success looks like:* Drive **S:** appears listed and points to \\finbridge-fs01\Finance.

13. **Trigger a sync on all remaining affected devices.** In Endpoint Manager, go to **Devices** > **All devices**, filter/select the remaining DESKTOP-FB* devices reported as affected, click **... (More)** > **Sync**.
    - *Success looks like:* Endpoint Manager shows a notification confirming the sync command was sent to the selected devices.

14. **Post the all-clear update.** In the incident channel, type: "Finance drive mapping script updated to run as logged-on user, redeployed via Intune, sample device confirmed fixed. Syncing remaining devices now. Monitoring." and send.
    - *Success looks like:* Message sent in the incident channel.

---

## Verification

Before closing the incident, confirm **all** of the following:

- [ ] `IntuneManagementExtension.log` on the sample device (DESKTOP-FB041) shows the script's most recent run completed without error (step 11 repeated).
- [ ] Drive **S:** is visible in File Explorer and opens \\finbridge-fs01\Finance without a credential prompt, on the sample device (step 12 repeated).
- [ ] At least 3 other affected devices, checked individually, show drive **S:** mapped in File Explorer after their sync completes.
- [ ] `eventvwr.msc` > **Windows Logs > System** on the sample device, filtered for Event ID `98` / Source `Ntfs` (same filter as step 3), shows no new occurrence timestamped in the 30 minutes following the fix.
- [ ] Helpdesk/incident queue shows no new "cannot access Finance drive" tickets in the 30 minutes after remaining devices sync (step 13).
- [ ] A designated test Finance user confirms, in writing (chat/email), that they can open and save a file on the Finance shared drive.

Only close the incident once every checkbox above is confirmed. If any item fails, return to Procedure step 6 and re-check the script logic before reattempting.

---

## Rollback

**Target: every action below must be completed in under 3 minutes.** If a step doesn't visibly resolve within that window, stop and escalate — do not keep retrying.

### Step 0 — Always do this first (stops further harm, ~30 seconds)
1. Go to `endpoint.microsoft.com` in a browser. (~5 seconds)
2. Click **Devices** in the left menu > click **Scripts and remediations** > click the **Platform scripts** tab. (~5 seconds)
3. Click **Map-FinBridgeDrives.ps1** in the list. (~5 seconds)
4. On the **Properties** page, find the **Assignments** tile and click **Edit** (pencil icon) on it. (~5 seconds)
5. Click the **X** next to the **Finance-Devices** group chip to remove it. (~5 seconds)
6. Click **Review + save** at the bottom, then click **Save** on the next screen. (~5 seconds)
- *Success looks like:* Back on the Properties page, the Assignments tile reads "0 groups assigned" (or the Finance-Devices chip no longer appears).
- This one action is safe to run regardless of which failure below has occurred — it stops the broken or newly-edited script from running again on any device while you handle the rest.

### 1. Updated script upload (step 8) breaks devices that previously had a partial mapping
1. Confirm Step 0 has been done (Assignments tile reads "0 groups assigned"). If not, do it now. (~30 seconds)
2. In `endpoint.microsoft.com`, go to **Devices** > **Scripts and remediations** > **Platform scripts** > click **Map-FinBridgeDrives.ps1**. (~10 seconds)
3. On the **Properties** page, find the **Script settings** tile and click **Edit** (pencil icon). (~5 seconds)
4. Click the folder icon next to **Script location**, browse to the original (pre-edit) `.ps1` file you saved as a backup before step 6, and select it. If you did not keep a backup, browse instead to the copy attached to the **Known-error Record** or migration change ticket. (~40 seconds)
5. Click **Next**, then click **Review + save**, then click **Save**. (~15 seconds)
- *Success looks like:* The Script settings tile shows the original file name and a new "Last modified" timestamp.
- Total: under 2 minutes. Leave Step 0 in place — do not re-add the assignment until you are ready to redeploy deliberately.

### 2. "Run as logged-on user" setting (step 7) causes the script to fail for a different reason (e.g., permissions error in log after step 11)
1. On the affected device, open `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` in Notepad, scroll to the newest "Map-FinBridgeDrives" entry, and copy the error line. (~20 seconds)
2. Confirm Step 0 has been done (Assignments tile reads "0 groups assigned"). If not, do it now. (~10 seconds)
3. In the Teams incident channel, post: `@identity-team Map-FinBridgeDrives.ps1 fails under logged-on-user context with new error: [paste error]. Escalating as P1, assignment removed pending fix.` Send. (~30 seconds)
4. Stop. Do not re-enable the assignment yourself — this requires the identity/scripting team to review before another attempt.
- Total: under 1 minute.

### 3. Forced sync (step 10 or 13) leaves a device stuck / unresponsive
1. On the affected device, click **Start** > **Settings** (gear icon) > **Accounts** > **Access work or school** > click the work/school account tile > click **Info** > scroll down and click **Sync** — retry once. (~30 seconds)
2. If the sync still shows no result after that one retry, click **Start** > click the **Power** icon > click **Restart**. **No elevated permission required — standard user restart.** (~10 seconds to initiate)
3. After the device restarts and you sign back in, open **File Explorer** > **This PC** and check for drive **S:**. If still missing, stop and escalate in Teams: `@endpoint-team DESKTOP-FBxxx stuck after Intune sync retry, needs device-level check.` (~20 seconds)
- Total: under 2 minutes, including the one permitted retry and restart.

### 4. Sample device fix works (step 12) but rollout to remaining devices (step 13) causes new tickets from a different device group
1. Confirm Step 0 has been done (Assignments tile reads "0 groups assigned") — this immediately stops the script running on any further devices. If not, do it now. (~10 seconds)
2. In the Teams incident channel, post: `Finance drive script rollback triggered — assignment removed due to new tickets from [group name]. Investigating before re-deploying.` Send. (~20 seconds)
3. Do not re-add the assignment until the new group's symptom is triaged separately — treat it as a new investigation, not a retry of this runbook.
- Total: under 1 minute.

### General rule
Any step above that isn't resolved on the **first retry** is an automatic escalation — tag the identity/scripting team lead in the incident channel and leave the script assignment removed (Step 0). Never attempt a third action on the same failure yourself.

---

## Notes

- **Root cause reference:** The failure occurred because Map-FinBridgeDrives.ps1 ran under the SYSTEM account, which cannot present the user's credentials required for the UNC path \\finbridge-fs01\Finance. Any future migration of USER-context GPO scripts to Intune must explicitly set the correct execution context before cutover.
- **Group Policy processing is a red herring.** Event 1500 (Group Policy processed successfully) was logged normally throughout this incident — do not assume GP processing issues are the cause just because a migration recently occurred; verify each delivery mechanism (GPO vs. Intune script) independently.
- **No retry configured warning:** The Intune Management Extension log explicitly noted "No retry configured" for this script. Until a retry policy is added, a single transient network blip could reproduce this exact symptom — check the log context (SYSTEM vs. user) before assuming the same root cause on a recurrence.
- **Backup the script before editing.** Always save a copy of the currently-deployed `.ps1` file before making any edit in step 6, so Rollback option 1 can be executed without depending on ticket attachments.
- **Related incidents:** See [Closure Note - Finance Shared Drive Access Failure After Intune Migration.md](../day4/Closure%20Note%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md) and [Known-error Record - Finance Shared Drive Access Failure After Intune Migration.md](../day4/Known-error%20Record%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md) for prior documentation of this same event.
- **Escalation contact:** Identity/scripting team owning Intune platform scripts — confirm current on-call contact in the incident management tool before starting if this recurs outside business hours.
