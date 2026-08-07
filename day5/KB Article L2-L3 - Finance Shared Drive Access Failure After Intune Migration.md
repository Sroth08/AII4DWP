L2/L3 Knowledge Base Article: Finance Shared Drive Access Failure After Intune Migration

Version: 1.0 | Date: 07/08/2026 | Status: Draft

---

## Background

Finance users access their team file share through a mapped network drive, letter **S:**, pointing to the UNC path `\\finbridge-fs01\Finance`. This mapping is not built into Windows — it must be delivered to each device by a logon mechanism every time a user signs in.

Until 2024-03-14, this was delivered by a **GPO Logon Script** — a script attached to a Group Policy Object that Windows executes automatically at logon, in the **interactive signed-in user's own context**. Because it runs as the user, it carries the user's Kerberos ticket/credentials, so a call to map `\\finbridge-fs01\Finance` succeeds using the same identity the user is signed in with.

On 2024-03-14 23:30, this was migrated to an **Intune PowerShell Script** (a "platform script" under Devices > Scripts and remediations), named **Map-FinBridgeDrives.ps1**, assigned to the Azure AD group **Finance-Devices**. Intune platform scripts execute through the **Intune Management Extension (IME)**, a Windows service that, **by default, runs scripts as `NT AUTHORITY\SYSTEM`** — the local computer account, not the interactive user — unless the script's **"Run this script using the logged-on credentials"** setting is explicitly set to **Yes**.

This distinction is the entire basis of this incident: **SYSTEM is the computer's identity, not the user's**. SYSTEM has no Kerberos ticket for the signed-in user and cannot authenticate to a UNC share that expects the user's own credentials. A script that worked perfectly as a GPO logon script (USER context) can fail completely when moved to an Intune platform script (SYSTEM context by default) if this setting is not changed at the same time. This is why execution context must always be explicitly verified — and never assumed to carry over — whenever a logon mechanism is migrated between delivery platforms.

## Symptom

**What the user reports:**
- "I can't see my S: drive" / "My Finance drive is missing" at the start of the business day.
- No error dialog is shown to the user — the drive is simply absent from File Explorer.

**What the engineer observes:**
- Approximately 45 Finance users affected, all on **DESKTOP-FB\*** naming-convention devices in **OU=Finance**.
- Onset at the start of business hours, the first logon wave following the 23:30 migration change the previous night.
- Group Policy processing itself is confirmed healthy (Event ID 1500) on affected devices — this rules out a GPO-side regression and points at the newly introduced Intune script delivery path instead.
- No server/share-wide outage reported — other UNC-based access to `\\finbridge-fs01\Finance` from already-connected sessions is unaffected; only the **logon-time mapping** fails.

## Root Cause

**Verified root cause:** `Map-FinBridgeDrives.ps1` executes under the `NT AUTHORITY\SYSTEM` account because the Intune script's **"Run this script using the logged-on credentials"** setting was left at its default (**No**) when the drive-mapping mechanism was migrated from a **GPO Logon Script (USER context)** to an **Intune PowerShell Script (SYSTEM context)**. `NT AUTHORITY\SYSTEM` is the local computer's own identity — it holds no Kerberos ticket or credential for the interactively signed-in user, so it cannot authenticate to `\\finbridge-fs01\Finance`, which requires the user's own credentials. As a result, the script fails before it can map the drive, and drive letter **S:** is never created for the user.

**Evidence confirming this cause (source: incident RCA; IntuneManagementExtension.log and System log on DESKTOP-FB041):**
- ScriptRunner Info: **"Executing: Map-FinBridgeDrives.ps1"** → confirms the script **did** execute (rules out "script not running" as the cause).
- ScriptRunner Info: **"Script context: SYSTEM account"** → confirms the execution identity was the computer account (`NT AUTHORITY\SYSTEM`), not the interactive user.
- ScriptRunner Warning: **"Network path \\finbridge-fs01\Finance not accessible from SYSTEM context"** → confirms the specific failure mechanism is identity/context, not name resolution or share health.
- ScriptRunner Error: **"Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found."** → this is the logged symptom of the SYSTEM-context authentication rejection, not a genuine DNS/name-resolution fault — the same share remains reachable from user-context sessions.
- System log, **Event ID 98** (Source `Ntfs`) — "could not map drive letter S:, drive letter has not been assigned" → confirms the downstream, user-visible effect that follows directly from the script failure above.
- System log, **Event ID 1500** (Source `GroupPolicy`) — "Group Policy settings processed successfully" → **elimination check**: confirms Group Policy processing itself is healthy, so the fault is isolated to the Intune script delivery path and is not a GPO regression.
- Migration change record — confirms the mechanism changed from a GPO Logon Script (USER context) to an Intune PowerShell Script (SYSTEM context), and that the script was **not updated** to support the new execution context. This is the change that introduced the fault.

**Why alternative causes are ruled out:**
| Hypothesis | Verdict | Why |
|---|---|---|
| Script not executing on affected devices | Ruled out | "Executing: Map-FinBridgeDrives.ps1" confirms execution start; the failure occurs later, at network access, not at launch. |
| Intune assignment/targeting failure (script never reached the device) | Ruled out | The "Executing" and "Script context" log entries prove the Finance-Devices assignment reached the device and the script ran. |
| Deployment delay (Intune had not yet rolled out to all devices) | Ruled out | The script had already been delivered and executed at the start of business hours, per the same log entries. |
| Execution context lacks required permissions (**confirmed**) | **Root cause** | "Script context: SYSTEM account", "not accessible from SYSTEM context", and "Network name cannot be found" together confirm SYSTEM cannot present user credentials for the UNC path. |
| File server outage (`finbridge-fs01` down) | Ruled out | The logged failure is attributed specifically to SYSTEM-context access being rejected, not to the server being unreachable; other user-context sessions can still reach the server. |
| Share outage (`\\finbridge-fs01\Finance` unavailable) | Ruled out | Same evidence as above — the failure message names the execution context as the blocker, not share availability. |
| Share/NTFS permissions changed independently of the migration | Ruled out | The failure is logged as a SYSTEM-context access rejection at the network layer, not an access-denied/permissions error against the share's ACL. |
| Group Policy processing failure | Ruled out | Event ID 1500 confirms Group Policy settings processed successfully on the affected device — GPO delivery is unaffected. |

## Detection

Confirm this specific issue **before** taking any remediation action. This should take under 3 minutes per device using the checks below — do not proceed to Resolution until the Detection Decision at the end of this section confirms it.

**Fast path — run all three commands first (affected device, e.g. DESKTOP-FB041):**

```powershell
# 1. Log search for Map-FinBridgeDrives - confirms the script ran and how it failed
$logPath = '\\DESKTOP-FB041\C$\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log'
Select-String -Path $logPath -Pattern 'Map-FinBridgeDrives','Script context: SYSTEM account','Network name cannot be found','not accessible from SYSTEM context' |
    Select-Object LineNumber, Line
```
```powershell
# 2. Event ID 98 query (System log, Source Ntfs) - confirms the downstream symptom
Get-WinEvent -ComputerName DESKTOP-FB041 -FilterHashtable @{LogName='System'; ProviderName='Ntfs'; Id=98} -MaxEvents 5 |
    Select-Object TimeCreated, Message
```
```powershell
# 3. Event ID 1500 query (System log, Source GroupPolicy) - elimination check for GPO
Get-WinEvent -ComputerName DESKTOP-FB041 -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-GroupPolicy'; Id=1500} -MaxEvents 1 |
    Select-Object TimeCreated, Message
```

If command 1 returns lines matching all four search strings, command 2 returns a matching Event ID 98 entry, and command 3 returns a successful Event ID 1500 entry, the failure signature is confirmed — proceed to the remaining steps to complete scope and comparison confirmation.

1. **Confirm the script executed and identify the failure.**
   - Exact location: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` on the affected device.
   - Search string: `Map-FinBridgeDrives`, then `Network name cannot be found` and `not accessible from SYSTEM context`.
   - Event ID / source: N/A (application log file, not Event Viewer).
   - Expected result: An "Executing: Map-FinBridgeDrives.ps1" line, followed by an error line containing **"Network name cannot be found"** and/or **"not accessible from SYSTEM context"**.
   - Why this confirms the diagnosis: Proves the script ran (rules out non-execution/targeting/delay causes) and that it failed specifically on network path access, not at launch.

2. **Confirm the execution context.**
   - Exact location: same file, same run block (lines immediately after the "Executing" line).
   - Search string: `Script context:`.
   - Event ID / source: N/A (application log file).
   - Expected result: The line reads **"Script context: SYSTEM account"**.
   - Why this confirms the diagnosis: Proves the script ran as `NT AUTHORITY\SYSTEM`, not the interactive user — this is the specific condition that makes the UNC path unreachable.

3. **Confirm the downstream symptom in Event Viewer.**
   - Exact location: Event Viewer → **Windows Logs > System**. Path: `eventvwr.msc` → **Windows Logs > System** → **Filter Current Log** → Event ID `98`, Event sources: `Ntfs`.
   - Event ID / source: **98** / **Ntfs**.
   - Expected result: An entry stating drive letter **S:** could not be mapped / has not been assigned, logged shortly after the IME log error in step 1.
   - Why this confirms the diagnosis: Confirms the script failure in steps 1-2 is what caused the missing drive letter, not an unrelated NTFS/disk fault.

4. **Run the elimination check against Group Policy processing.**
   - Exact location: Event Viewer → **Windows Logs > System**. Path: `eventvwr.msc` → **Windows Logs > System** → **Filter Current Log** → Event ID `1500`, Event sources: `GroupPolicy` (or `Microsoft-Windows-GroupPolicy`).
   - Event ID / source: **1500** / **GroupPolicy**.
   - Expected result: A successful "Group Policy settings processed successfully" entry close to logon time.
   - Why this confirms the diagnosis: If present and successful, this proves Group Policy processing is healthy, isolating the fault to the Intune script delivery path — **do not** investigate GPO as the cause. If Event 1500 is missing or shows failure, this is a different/broader GPO incident, not this known issue.

5. **Run the comparison/control check between an affected and unaffected device.**
   - Affected device: **DESKTOP-FB041** (or another reported device in Finance-Devices).
   - Control device: a known-good DESKTOP-FB\* device confirmed **not** a member of the Finance-Devices Azure AD group (or one still on the prior GPO logon script path).
   - Exact location: same log file path on both devices — `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`.
   - Command (run against both, compare output):
     ```powershell
     foreach ($device in 'DESKTOP-FB041','<control-device-name>') {
         Write-Host "=== $device ===" -ForegroundColor Cyan
         Select-String -Path "\\$device\C$\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Pattern 'Map-FinBridgeDrives' -ErrorAction SilentlyContinue
     }
     ```
   - Expected differences: The affected device (DESKTOP-FB041) shows the "Map-FinBridgeDrives" execution/failure entries from steps 1-2; the control device shows **either** no matching log entries at all (script never targeted it) **or**, if it is on the prior GPO path, no Event ID 98 in its System log for drive S:.
   - Why this confirms the diagnosis: Proves the fault is scoped to devices that received the migrated Intune script, not a share/server/network-wide problem. If the control device (confirmed in the same group/context) also shows Event ID 98, this points to a broader share/network incident, not this script-context root cause — see Detection Decision below.

6. **Confirm scope via the Intune script's own reporting.**
   - Exact location: `endpoint.microsoft.com` → **Devices** → **Scripts and remediations** → **Platform scripts** → **Map-FinBridgeDrives.ps1** → **Device status** tab.
   - Event ID / source: N/A (Intune portal reporting).
   - Expected result: A **"Failed"** or **"With error"** count against the Finance-Devices assignment consistent with the reported user impact.
   - Why this confirms the diagnosis: Confirms the reporting scope matches the reported user impact. A failure count far smaller than the reported impact may indicate a partial or different issue — see Detection Decision below.

### Detection Decision

- **Confirmed as this incident when:** the affected device's IntuneManagementExtension.log shows "Script context: SYSTEM account" together with "Network name cannot be found" and/or "not accessible from SYSTEM context" for Map-FinBridgeDrives.ps1 (steps 1-2), **and** System log Event ID 98 (Source `Ntfs`) is present (step 3), **and** System log Event ID 1500 (Source `GroupPolicy`) shows successful processing (step 4).
- **Not this incident when:** the log shows Map-FinBridgeDrives.ps1 completing with no context/network error, **or** Event ID 1500 shows a Group Policy processing failure, **or** the device has no Map-FinBridgeDrives log entries at all (check Finance-Devices membership before proceeding further).
- **Escalate before remediation when:** the control device comparison (step 5) shows the same Event ID 98 symptom on a device outside the Finance-Devices/SYSTEM-context path (indicates a broader share/server/network issue, not this script-context cause), **or** the Device status tab (step 6) shows a failure count inconsistent with the reported user impact, **or** the log contains an error string other than the four documented in steps 1-2. In any of these cases, escalate to the identity/scripting team before applying the Resolution section.

Only proceed to Resolution once the Detection Decision above confirms this incident.

## Resolution

**Prerequisite (run once):**
```powershell
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","DeviceManagementManagedDevices.ReadWrite.All"
$script = Get-MgDeviceManagementScript -Filter "displayName eq 'Map-FinBridgeDrives.ps1'"   # script lookup
$deviceId = (Get-MgDeviceManagementManagedDevice -Filter "deviceName eq 'DESKTOP-FB041'").Id  # sample device lookup
```
Portal paths below all start from `endpoint.microsoft.com` → **Devices** → **Scripts and remediations** → **Platform scripts** → **Map-FinBridgeDrives.ps1** — confirm this exact script name before editing.

1. **Open the script.**
   - Path: `endpoint.microsoft.com` → **Devices** → **Scripts and remediations** → **Platform scripts** → **Map-FinBridgeDrives.ps1**.
   - Expected result: **Properties** page loads with **Settings**, **Script settings**, **Assignments**, **Device status** tiles/tabs visible.

2. **Back up the current script.**
   - Path: **Properties** → **Script settings** tile → export/download current file as `Map-FinBridgeDrives.ps1.bak`.
   - Graph: `Get-MgDeviceManagementScriptContent -DeviceManagementScriptId $script.Id | Out-File 'Map-FinBridgeDrives.ps1.bak'` (if supported by your SDK version).
   - Expected result: Local `.bak` copy saved — required for Rollback scenario 1.

3. **Edit the script — remove SYSTEM-only credential logic.**
   - Change: Remove `-Credential` parameter (wherever used on `New-PSDrive`).
   - Change: Remove `/user:` clause (wherever used on `net use`).
   - Change: Remove any embedded password following `/user:`.
   - Confirm unchanged: target path remains `\\finbridge-fs01\Finance` and drive letter remains `S`.
   - Expected result: Drive-mapping line targets `S` and `\\finbridge-fs01\Finance` only, with no `-Credential`, `/user:`, or password. Save file.

4. **Set: Run this script using the logged-on credentials = Yes.**
   - Path: **Properties** → **Settings** tile → **Edit** → **Run this script using the logged-on credentials** → **Yes** → **Review + save** → **Save**.
   - Graph: `Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{ runAsAccount = "user" }`
   - **Elevated permission required: Intune Script Manager role.**
   - Expected result: Settings tile shows "Run this script using the logged-on credentials: Yes".

5. **Upload the corrected script file.**
   - Path: **Properties** → **Script settings** tile → **Edit** → folder icon → select edited file from step 3 → **Next** → **Review + save** → **Save**.
   - Graph: `Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{ scriptContent = [Convert]::ToBase64String((Get-Content -Path '.\Map-FinBridgeDrives.ps1' -Raw -Encoding Byte)) }`
   - **Elevated permission required: Intune Script Manager role.**
   - Expected result: Script settings tile shows new file name/"Last modified" timestamp.

6. **Confirm: Finance-Devices assignment.**
   - Path: **Properties** → **Assignments** tile → **Included groups**.
   - Expected result: **Finance-Devices** listed, Assignment type = Required. Do not add/remove groups here.

7. **Sync the sample device (DESKTOP-FB041).**
   - Path (on device): **Settings** → **Accounts** → **Access work or school** → work account → **Info** → **Sync**.
   - Graph: `Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId`
   - Expected result: "Sync completed" message in Settings/Company Portal UI.

8. **Confirm re-run success.**
   - Location: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` on DESKTOP-FB041.
   - Search string: `Map-FinBridgeDrives` (newest entry, after step 7 sync time).
   - Expected result: Successful completion, no "Network name cannot be found".

9. **Confirm drive mapped.**
   - Path: **File Explorer** → **This PC** on DESKTOP-FB041.
   - Expected result: **S:** listed, targets `\\finbridge-fs01\Finance`.

10. **Check Device status tab before wider rollout.**
    - Path: **Properties** → **Device status** tab.
    - Expected result: DESKTOP-FB041 shows **Success**.

11. **Roll out to all remaining affected devices.**
    - Path: `endpoint.microsoft.com` → **Devices** → **All devices** → select remaining DESKTOP-FB\* devices → **... (More)** → **Sync**.
    - Graph:
      ```powershell
      $deviceNames = @('DESKTOP-FB0xx','DESKTOP-FB0yy')  # remaining affected devices
      foreach ($name in $deviceNames) {
          $id = (Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$name'").Id  # device lookup
          Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $id                        # device sync
      }
      ```
    - Expected result: Portal notification confirms sync sent to all selected devices.

## Verification

| Check | Exact location | Expected result | Pass | Fail | Next action if failed |
|---|---|---|---|---|---|
| Script log | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` (DESKTOP-FB041) | Newest "Map-FinBridgeDrives" run has no error | No "Network name cannot be found" after sync time | Error present | Return to Resolution step 3 |
| Drive mapped | File Explorer → **This PC** → **S:** on DESKTOP-FB041 | S: opens `\\finbridge-fs01\Finance`, no credential prompt | Drive present, opens share | Drive absent or prompts for credentials | Return to Resolution step 3 |
| Script rollout status | **Scripts and remediations** → **Map-FinBridgeDrives.ps1** → **Device status** tab | 0 Failed / 0 With error across Finance-Devices | 0 failed, success count = ~45 devices | Any failed count | Identify device(s), re-run Resolution steps 7-9 |
| Sample of other devices | File Explorer → **This PC** → **S:** on 3+ other affected devices | S: mapped after their sync | All 3 show mapped drive | Any device missing drive | New device-level investigation (Rollback scenario 3) |
| Event Viewer | `eventvwr.msc` → **Windows Logs > System**, Event ID `98`, Source `Ntfs` (DESKTOP-FB041) | No new occurrence in 30 min after fix | Zero new rows | New Event 98 | Re-check Resolution step 4 was saved |
| Helpdesk validation | Helpdesk/incident queue | No new "cannot access Finance drive" tickets in 30 min after rollout | Zero new tickets | New tickets | Check Finance-Devices targeting before re-running fix |
| User confirmation test | Written confirmation (chat/email) from designated test Finance user | User opens/saves a file on the Finance drive | Confirmation received | No confirmation / issue reported | Do not close incident |

Close the incident only when every row above shows **Pass**. Any **Fail** → do not retry the same fix a third time without re-validating Detection steps 1-2 on the failing device.

## Rollback

**Rapid containment (Step 0 — always do first, target 30 seconds):**
- Path: `endpoint.microsoft.com` → **Devices** → **Scripts and remediations** → **Platform scripts** → **Map-FinBridgeDrives.ps1** → **Assignments** tile → **Edit** → click **X** on **Finance-Devices** chip → **Review + save** → **Save**.
- Graph: `Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{ assignments = @() }`
- Expected result: Assignments tile reads **"0 groups assigned"** — this removes Finance-Devices and prevents any further script execution.
- Safe to run regardless of which scenario below applies.

| Scenario | Exact portal path | Exact action | Graph alternative | Expected result | Escalation point | First-retry limit |
|---|---|---|---|---|---|---|
| 1. Updated script (step 5) breaks devices with a partial mapping | **Scripts and remediations** → **Map-FinBridgeDrives.ps1** → **Properties** → **Script settings** tile → **Edit** | Browse to `Map-FinBridgeDrives.ps1.bak` (Resolution step 2) → **Next** → **Review + save** → **Save** | `Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{ scriptContent = [Convert]::ToBase64String((Get-Content '.\Map-FinBridgeDrives.ps1.bak' -Raw -Encoding Byte)) }` | Script settings shows original file name, new "Last modified" | If no backup exists, pull the copy from the Known-error Record/change ticket, then escalate to identity/scripting team | 1 retry, then escalate |
| 2. "Run as logged-on user" (step 4) fails with a new error | N/A — log-only | Copy new error line from `IntuneManagementExtension.log` | N/A | Error text captured | Post in incident channel: `@identity-team Map-FinBridgeDrives.ps1 fails under logged-on-user context with new error: [paste error]. Escalating as P1, assignment removed pending fix.` | 0 retries — escalate immediately, do not re-enable assignment |
| 3. Forced sync (step 7 or 11) leaves device stuck/unresponsive | Device: **Settings** → **Accounts** → **Access work or school** → **Info** → **Sync** | Retry sync once; if unresponsive, **Start** → **Power** → **Restart** | `Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId` (retry once) | Drive **S:** present after restart | Escalate in Teams: `@endpoint-team DESKTOP-FBxxx stuck after Intune sync retry, needs device-level check.` | 1 retry + 1 restart, then escalate |
| 4. Sample fix works but rollout (step 11) causes new tickets from a different group | N/A — Step 0 already applied | Confirm Step 0 done | `Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{ assignments = @() }` | Assignment remains removed | Post: `Finance drive script rollback triggered — assignment removed due to new tickets from [group name]. Investigating before re-deploying.` | 0 retries — new investigation, not a retry of this KB |

**General rule:** Any scenario not resolved on the first retry (or zero-retry scenarios 2 and 4) is an automatic escalation — tag the identity/scripting team lead and leave the assignment removed (Step 0).

## Rapid Recovery Path

Use this section alone when time-pressured and the Detection Decision has already confirmed this incident.

**Fastest fix (run in order):**
```powershell
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All","DeviceManagementManagedDevices.ReadWrite.All"
$script   = Get-MgDeviceManagementScript -Filter "displayName eq 'Map-FinBridgeDrives.ps1'"
$deviceId = (Get-MgDeviceManagementManagedDevice -Filter "deviceName eq 'DESKTOP-FB041'").Id

# Edit Map-FinBridgeDrives.ps1 locally first: remove -Credential / /user: / password, keep S: and \\finbridge-fs01\Finance unchanged.
Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{
    runAsAccount  = "user"
    scriptContent = [Convert]::ToBase64String((Get-Content -Path '.\Map-FinBridgeDrives.ps1' -Raw -Encoding Byte))
}
Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId
```
Expected result: Device syncs; `IntuneManagementExtension.log` shows a clean rerun; **S:** appears in File Explorer.

**Fastest verification:**
```powershell
Select-String -Path '\\DESKTOP-FB041\C$\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log' -Pattern 'Map-FinBridgeDrives'
Get-WinEvent -ComputerName DESKTOP-FB041 -FilterHashtable @{LogName='System'; ProviderName='Ntfs'; Id=98} -MaxEvents 3
```
Pass: log shows clean rerun, no new Event ID 98. Then check **Device status** tab = 0 Failed, and get the user confirmation test in writing.

**Fastest rollback:**
```powershell
Update-MgDeviceManagementScript -DeviceManagementScriptId $script.Id -BodyParameter @{ assignments = @() }
```
Expected result: Assignments tile reads "0 groups assigned" within seconds — all further script execution stopped. Then use the Rollback table above for the specific failure scenario.

## Preventive

1. **Execution-context validation gate for GPO-to-Intune script migrations (pre-deployment test gate).**
   - Owner: **Identity/Scripting engineer**. When: **Before deployment** — pre-cutover, in a lab/pilot device group, for any Finance-Devices UNC-mapping script (e.g., Map-FinBridgeDrives.ps1 → `\\finbridge-fs01\Finance`) moving between GPO (USER context) and an Intune Platform Script (SYSTEM context by default).
   - Pass: script completes its UNC operation on 100% of pilot devices under the exact intended **Run as account** (User/SYSTEM), with the context explicitly documented | Fail: any pilot device fails the UNC operation, or Run as account is undocumented/assumed | Action if fail: block promotion to production assignment; return to Identity/Scripting engineer for context correction and re-test.
   - Automation: Manual review. [REQUIRES: migration checklist template with an "execution context confirmed" sign-off field]

2. **Mandatory retry configuration on all Intune platform scripts touching network resources (scripting standard).**
   - Owner: **Identity/Scripting engineer**. When: **Before deployment** — at script submission/review, for every Intune Platform Script touching a UNC path or network resource.
   - Pass: script specifies at least one retry with a defined interval | Fail: script shows "No retry configured" (as logged for Map-FinBridgeDrives.ps1) | Action if fail: reject at review; return to author with the required retry/interval values before resubmission.
   - Automation: Manual review checklist. [REQUIRES: script-submission template enforcing a retry-count field]

3. **Device Status monitoring with alert threshold (during and after deployment).**
   - Owner: **Intune administrator** (rollout window), handing off to **DWP engineer** (monitoring on-call) thereafter. When: **During deployment** (first rollout/sync wave) and **after deployment** (standing, ongoing).
   - Pass: **Device Status** tab shows ≤5 "Failed"/"With error" devices in any rolling 1-hour window, and Event ID 98 (Source `Ntfs`) occurrences stay at 0 across monitored devices | Fail: >5 failed/with-error devices in 1 hour, **or** any new Event ID 98 occurrence post-deployment | Action if fail: alert fires; on-call engineer triages within 15 minutes using the Detection section of this KB.
   - Automation: **Automated.** [REQUIRES: alert rule against Intune script Device Status reporting and Event ID 98 telemetry, e.g., via Graph API polling or Log Analytics if Intune diagnostics are exported]

4. **Migration change record must capture execution context explicitly (change control enhancement).**
   - Owner: **Change manager**. When: **Before deployment** — at change submission, before CAB approval, for any change migrating a logon mechanism between GPO and Intune.
   - Pass: change record includes a mandatory field stating source and target execution context (e.g., "GPO: USER context → Intune: SYSTEM context, RunAsAccount=user confirmed") and names the affected assignment group (e.g., Finance-Devices) | Fail: field missing, blank, or context/assignment group not named | Action if fail: reject at CAB review; return to change owner for completion.
   - Automation: Manual. [REQUIRES: change template field addition in the ITSM change form]

5. **Defined bake-in period before decommissioning the replaced GPO logon script (post-deployment validation).**
   - Owner: **Release engineer**, sign-off from **Change manager**. When: **After deployment** — the first full business-day logon wave following cutover.
   - Pass: zero Event ID 98 (Source `Ntfs`) occurrences **and** Device Status tab shows 0 Failed across 100% of the Finance-Devices population | Fail: any Event ID 98 occurrence or any Device Status failure in that population | Action if fail: hold the old GPO script in place (do not remove); re-run Detection steps on failing devices and re-validate before the next business day.
   - Automation: Manual sign-off; underlying counts automatable via control 3.

6. **Knowledge update from this incident (knowledge update).**
   - Owner: **Service desk lead** (L1 article) jointly with the **DWP engineer** who worked the incident (this KB and the runbook). When: **After deployment** — as part of incident closure, before the change/incident record is closed.
   - Pass: this KB, the runbook, and the L1 article are updated with any new detection signal or step discovered during the incident | Fail: no update logged against any of the three documents | Action if fail: block incident closure until the update is confirmed logged.
   - Automation: Manual; no automation applicable.

7. **Pilot deployment to a Finance-Devices subset before full rollout (staged deployment gate).**
   - Owner: **Release engineer** with **Intune administrator** executing the assignment. When: **Before deployment** (full rollout) — a pilot ring of ≥3 Finance-Devices machines, assigned and synced ahead of the remaining population.
   - Pass: 100% of pilot devices confirm S: mapped to `\\finbridge-fs01\Finance` and 0 pilot-user validation failures (written confirmation obtained from each pilot user) | Fail: any pilot device fails to map the drive, or any pilot user reports an issue | Action if fail: halt full rollout; return to Resolution/Detection to re-diagnose before expanding scope.
   - Automation: Manual. [REQUIRES: a defined pilot-ring device list maintained per migration]

8. **Intune assignment validation for Finance-Devices (pre- and post-change check).**
   - Owner: **Intune administrator**. When: **Before deployment** (immediately after any assignment edit) and **after deployment** (post-sync confirmation), for the Map-FinBridgeDrives.ps1 script specifically.
   - Pass: **Assignments** tile shows **Finance-Devices** as the only included group, Assignment type = Required, with no unintended additional/removed groups | Fail: assignment shows an unexpected group, a missing Finance-Devices entry, or wrong assignment type | Action if fail: correct the assignment immediately via the Assignments tile before any further sync/rollout.
   - Automation: Manual check; automatable via `Get-MgDeviceManagementScriptAssignment`. [REQUIRES: a scheduled Graph query comparing current assignments to an approved baseline]

9. **Mandatory peer review of Intune Platform Scripts before upload (context-assumption checklist).**
   - Owner: **Identity/Scripting engineer** (a second reviewer, not the script author). When: **Before deployment** — before any Platform Script touching a UNC path (e.g., `\\finbridge-fs01\Finance`) is uploaded or updated.
   - Pass: reviewer confirms the script does not hard-code `-Credential`, `/user:`, or embedded passwords, and that the intended **Run as account** setting matches the script's authentication assumptions | Fail: script relies on SYSTEM-context credentials for a user-authenticated UNC path, or the Run as account setting is unspecified | Action if fail: reject upload; return to author with the specific line(s) flagged.
   - Automation: Manual review checklist. [REQUIRES: a peer-review sign-off field in the script-submission template, shared with control 2]

10. **Script backup and version control for all Platform Scripts (change hygiene).**
    - Owner: **Identity/Scripting engineer**. When: **Before deployment** — immediately before every edit/upload to an existing Intune Platform Script (e.g., prior to Resolution step 3/5 edits on Map-FinBridgeDrives.ps1).
    - Pass: a timestamped, versioned copy of the prior script (e.g., `Map-FinBridgeDrives.ps1.bak`) is saved to a version-controlled location before the new version is uploaded | Fail: no backup exists prior to upload | Action if fail: block the upload until a backup is captured (via `Get-MgDeviceManagementScriptContent`).
    - Automation: Manual today. [REQUIRES: a source-control repository (e.g., Git) for Intune Platform Scripts to replace ad hoc `.bak` file naming]

11. **Rollout monitoring during phased deployment window (helpdesk ticket volume).**
    - Owner: **DWP engineer** (monitoring the rollout), with **Service desk lead** reporting ticket volume. When: **During deployment** — the 2-hour window immediately following any Finance-Devices script sync/rollout wave.
    - Pass: fewer than 3 new "cannot access Finance drive"-type helpdesk tickets logged in the 2-hour window | Fail: 3 or more new matching tickets in the window | Action if fail: pause further rollout to remaining devices; re-run Detection on the affected devices before continuing.
    - Automation: Manual ticket-queue check today. [REQUIRES: a helpdesk queue tag/category for this known error to enable automated ticket-volume counting]

12. **Rollback trigger thresholds (explicit auto-rollback decision points).**
    - Owner: **DWP engineer**, executed with **Intune administrator**. When: **During or after deployment** — evaluated continuously against controls 3, 5, and 11.
    - Pass: Device Status failed count ≤5/hour, Event ID 98 occurrences = 0 post-fix, and helpdesk ticket volume <3 in 2 hours (all thresholds hold) | Fail: **any one** threshold is breached (>5 failed devices/hour, any new Event ID 98, or ≥3 new tickets in 2 hours) | Action if fail: immediately execute Rollback Step 0 (remove Finance-Devices assignment) without waiting for all three signals to confirm.
    - Automation: **Automated** trigger recommended. [REQUIRES: an alerting/orchestration rule combining Device Status, Event ID 98 telemetry, and helpdesk ticket volume into a single rollback-trigger signal]

## Related

- Runbook: [Runbook - Finance Shared Drive Access Failure After Intune Migration.md](../day5/Runbook%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
- RCA: [RCA - Finance Shared Drive Access Failure After Intune Migration.md](../day4/RCA%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
- Ranked Cause Analysis: [Ranked Cause Analysis - Finance Shared Drive Access Failure After Intune Migration.md](../day4/Ranked%20Cause%20Analysis%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
- Known-error Record: [Known-error Record - Finance Shared Drive Access Failure After Intune Migration.md](../day4/Known-error%20Record%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
- Closure Note: [Closure Note - Finance Shared Drive Access Failure After Intune Migration.md](../day4/Closure%20Note%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
- End-User Communications: [End-User Communications - Finance Shared Drive Access Failure After Intune Migration.md](../day4/End-User%20Communications%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
- L1 self-service article: [KB Article - Finance Shared Drive Access Failure After Intune Migration.md](KB%20Article%20-%20Finance%20Shared%20Drive%20Access%20Failure%20After%20Intune%20Migration.md)
