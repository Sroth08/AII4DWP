L2/L3 Knowledge Base Article: AVD Black Screen After Login (POOL-FIN-01)

Version: 1.0 | Date: 07/08/2026 | Status: Draft

---

## Background

POOL-FIN-01 is an Azure Virtual Desktop (AVD) host pool used by Finance users to run their remote desktop sessions. Each session host runs the Desktop Window Manager (`dwm.exe`), the Windows process responsible for rendering and compositing the desktop and application windows on screen. `dwm.exe` depends on the graphics driver stack installed in the host's image (for these hosts, the Intel driver module `igdumd64.dll`). If `dwm.exe` cannot render, the user's session shows a black screen instead of the desktop — even though the session itself has logged on successfully. This matters because Finance relies on POOL-FIN-01 for day-to-day work; a pool-wide rendering failure blocks an entire business function, not just one user.

## Symptom

**What the user reports:**
- Logs in normally (credentials accepted, session appears to start) but the screen stays black.
- Some users say the screen clears after roughly 30 seconds; others report it never clears and they have to be logged off/back on.

**What the engineer observes:**
- ~40% of users on POOL-FIN-01 affected; POOL-FIN-02 completely unaffected in the same time window.
- Onset ~07:00, the first business-hours login wave after an overnight change.
- Affected sessions show a logon event, then almost immediately a disconnect, sometimes followed by one or more reconnect/disconnect cycles before either stabilizing or crash-looping indefinitely.

## Root Cause

**Primary root cause:** A graphics driver regression — `igdumd64.dll` version `31.0.101.4146` — was introduced by an overnight image update applied to POOL-FIN-01 at 02:00. This driver version causes `dwm.exe` (v10.0.22621.2861) to crash with an access-violation exception (`0xc0000005`) immediately after session load. Some sessions recover after 1-2 reconnect cycles when a subsequent DWM restart happens to succeed; others crash-loop and remain black indefinitely.

**Evidence confirming this cause:**
- Application log, Event ID **1000** (Application Error) on SHFIN-01-A at 07:02:16, 07:02:46, and 07:08:24: faulting application `dwm.exe` (v10.0.22621.2861), faulting module `igdumd64.dll` (v31.0.101.4146), exception code `0xc0000005`.
- System log, Event ID **9009** (Desktop Window Manager — DWM exited) on SHFIN-01-A at 07:02:18 and 07:03:01, exit code `0x40010004`, immediately following each Event 1000.
- System log, Event ID **1** (Microsoft-Windows-Kernel-General — boot time) on SHFIN-01-A at 07:02:14 shows boot time `02:03:11`, confirming the host rebooted onto the new image shortly after the 02:00 change window.
- **Comparison/control check:** SHFIN-02-A (POOL-FIN-02, image build `10.0.22621.2861-build-20240313`, not updated) logged Event ID **21** (session logon succeeded) at 07:01:44 immediately followed by Event ID **9011** (DWM started successfully) at 07:01:46, with zero Event 1000 entries in the same window — isolating the fault to hosts that received the 02:00 image update.
- Alternative causes were ruled out: no RDP shell/rdpshell/rdpinit failure events, no resource-exhaustion signature (`0xc0000005` is an access violation, not an out-of-resource code), and no FSLogix/profile/network events on the affected host.

## Detection

Confirm this specific issue **before** taking any remediation action. This should take under 3 minutes per host using the commands below — do not proceed to Resolution until all steps are confirmed.

**Fast path — run this first (affected host, e.g. SHFIN-01-A):**
```powershell
# Event 1000 (Application log) - confirms dwm.exe crash in igdumd64.dll
Get-WinEvent -ComputerName SHFIN-01-A -LogName Application -FilterXPath "*[System[(EventID=1000)]]" |
    Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' } |
    Select-Object TimeCreated, Message -First 5

# Event 9009 (System log) - confirms DWM actually exited immediately after
Get-WinEvent -ComputerName SHFIN-01-A -LogName System -FilterXPath "*[System[(EventID=9009)]]" |
    Select-Object TimeCreated, Message -First 5
```
If both commands return matching entries within seconds of each other, the crash signature is confirmed — proceed to the remaining checks below.

1. **Confirm the crash signature on an affected host.**
   - Log location: **Application log** (not System, not Security) — `eventvwr.msc` → **Windows Logs > Application** → **Filter Current Log** → Event ID `1000`. Equivalent PowerShell: `Get-WinEvent -LogName Application -FilterXPath "*[System[(EventID=1000)]]"` (see fast path above).
   - Look for: Source = `Application Error`; Faulting application name = `dwm.exe`; **Faulting module name = `igdumd64.dll`**, version `31.0.101.4146`; Exception code = `0xc0000005`.
   - Confirms: This is the known driver-regression crash, not a different `dwm.exe` fault.

2. **Confirm DWM actually exited as a result.**
   - Log location: **System log** — `eventvwr.msc` → **Windows Logs > System** → **Filter Current Log** → Event ID `9009`, Source `Desktop Window Manager`. Equivalent PowerShell: `Get-WinEvent -LogName System -FilterXPath "*[System[(EventID=9009)]]"` (see fast path above).
   - Look for: An entry timestamped within 1-3 seconds of the matching Event 1000, exit code `0x40010004`.
   - Confirms: The crash brought DWM down (not a transient, self-recovering render glitch). **Event 1000 and Event 9009 together are the confirmed signature for this issue** — either one alone is not sufficient.

3. **Confirm the timing lines up with an image/driver change.**
   - Log location: **System log** — `eventvwr.msc` → **Windows Logs > System** → **Filter Current Log** → Event ID `1`, Source `Microsoft-Windows-Kernel-General`.
   - PowerShell:
     ```powershell
     Get-WinEvent -ComputerName SHFIN-01-A -LogName System -FilterXPath "*[System[(EventID=1) and Provider[@Name='Microsoft-Windows-Kernel-General']]]" -MaxEvents 1 |
         Select-Object TimeCreated, Message
     ```
   - Look for: Most recent boot timestamp falling inside the suspected overnight deployment window (e.g., `02:00`-`03:00`), not a routine nightly reboot with no associated change.
   - Confirms: The host is running the newly deployed image, not an older build that happens to be crashing for an unrelated reason.

4. **Run the comparison/control check against the unaffected pool.**
   - Log location: **Application log** and **System log** on the control host — repeat step 1 and the Event 9011 check on a host from a sibling pool that did **not** receive the same image update, e.g. **SHFIN-02-A in POOL-FIN-02**.
   - PowerShell:
     ```powershell
     # Should return zero rows on the control host
     Get-WinEvent -ComputerName SHFIN-02-A -LogName Application -FilterXPath "*[System[(EventID=1000)]]" -ErrorAction SilentlyContinue |
         Select-Object TimeCreated, Message

     # Should show a clean DWM start on the control host
     Get-WinEvent -ComputerName SHFIN-02-A -LogName System -FilterXPath "*[System[(EventID=9011)]]" |
         Select-Object TimeCreated, Message -First 5
     ```
   - Look for: **Zero Event 1000 results** on SHFIN-02-A in the same time window, and a clean **Event ID 9011** (Source `Desktop Window Manager`, System log) shortly after each Event 21 logon — this is the healthy baseline that this issue is compared against.
   - Confirms: The fault is scoped to the pool/image that changed, not an environment-wide problem (e.g., shared storage, network, identity). If the control host (POOL-FIN-02) also shows Event 1000/9009, stop and treat this as a different/broader incident, not this known issue.

5. **Confirm scope across the pool before rolling back.**
   - Path: Azure Portal → search bar → "Azure Virtual Desktop" → **Host pools** → **POOL-FIN-01** → **Session hosts**.
   - Look for: Which hosts show recent/active session churn; cross-check each against steps 1-3 individually — do not assume every host in the pool is affected without checking, since partial image rollout or staggered reboots can leave some hosts clean.

Only proceed to Resolution once steps 1-4 are all positively confirmed on at least one affected host and the control comparison in step 4 (POOL-FIN-02 clean, Event 9011 healthy) is clean.

## Resolution

Prerequisite (once per session): `az login` and `az account set --subscription <subscription-id>`. All commands below assume resource group `<resource-group>` — substitute your actual RG. All portal paths start from **Azure Portal → Host pools → POOL-FIN-01** (not just "the pool" — always confirm POOL-FIN-01 specifically, not POOL-FIN-02, in the breadcrumb before acting).

1. **Drain the pool to stop new logins landing on the faulty image.**
   - Path: Azure Portal → **Host pools → POOL-FIN-01** → left menu **Session hosts** → select header checkbox (all hosts) → toolbar **Drain mode** → confirm.
   - CLI (repeat per host, or loop over all hosts in the pool):
     ```bash
     az desktopvirtualization sessionhost list \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --query "[].name" -o tsv

     az desktopvirtualization sessionhost update \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --name SHFIN-01-A --allow-new-session false
     ```
   - Expected result: Portal "Drain mode" column reads **On** for every row within ~10 seconds; CLI `sessionhost show` returns `"allowNewSession": false` for each host.

2. **Warn and then log off remaining active sessions.**
   - Path: Azure Portal → **Host pools → POOL-FIN-01** → **Session hosts** → click a host with active sessions → left menu **Sessions** → select active session checkboxes → toolbar **Send message** → title "Maintenance", message with a 5-minute warning → **Send**. Wait 5 minutes, then select remaining active sessions → toolbar **Log off** → confirm.
   - CLI:
     ```bash
     az desktopvirtualization session list \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --session-host-name SHFIN-01-A -o table

     az desktopvirtualization session send-message \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --session-host-name SHFIN-01-A --session-id <session-id> \
       --message-title "Maintenance" --message-body "Your session will be logged off in 5 minutes for urgent maintenance. Save your work now."

     az desktopvirtualization session disconnect \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --session-host-name SHFIN-01-A --session-id <session-id>
     ```
   - Expected result: Sessions grid (portal) or `session list` (CLI) shows zero remaining active sessions for the pool.

3. **Identify the last known-good image version.**
   - Path: Azure Portal → search bar → "Azure Compute Gallery" → select the gallery → left menu **Image definitions** → select the POOL-FIN-01 image definition → **Image versions** tab → note the version dated before the 02:00 change.
   - CLI:
     ```bash
     az sig image-version list \
       --resource-group <resource-group> --gallery-name <gallery-name> \
       --gallery-image-definition <image-definition-name> \
       --query "[].{Version:name, Published:publishingProfile.publishedDate}" -o table
     ```
   - Expected result: One specific, written-down version number confirmed as pre-incident (e.g., matching SHFIN-02-A's known-good build `10.0.22621.2861-build-20240313`).

4. **Remove the faulty session hosts.**
   - Path: Azure Portal → **Host pools → POOL-FIN-01** → **Session hosts** → select affected host checkboxes → toolbar **Remove** → tick **Delete the underlying VM(s)** → **Remove** to confirm.
   - CLI:
     ```bash
     az desktopvirtualization sessionhost delete \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --name SHFIN-01-A --yes

     az vm delete --resource-group <resource-group> --name SHFIN-01-A --yes
     ```
   - Expected result: Removed hosts disappear from **Session hosts**; their VMs no longer appear under **Virtual machines**.

5. **Deploy replacement hosts on the known-good image.**
   - Path: Azure Portal → **Host pools → POOL-FIN-01** → **Overview** → **+ Add** → **Virtual machines** tab → under "Image" click **See all images** → **Azure Compute Gallery images** → select the image definition and the version noted in step 3 → complete VM size/network/domain-join fields → **Review + create** → **Create**.
   - CLI (using the version confirmed in step 3):
     ```bash
     az vm create \
       --resource-group <resource-group> --name SHFIN-01-A \
       --image "/subscriptions/<sub-id>/resourceGroups/<resource-group>/providers/Microsoft.Compute/galleries/<gallery-name>/images/<image-definition-name>/versions/<known-good-version>" \
       --size <vm-size> --vnet-name <vnet> --subnet <subnet>
     ```
     Then register the new VM to POOL-FIN-01 using the pool's registration token (Azure Portal → **Host pools → POOL-FIN-01** → **Registration key** → generate/copy) via the AVD agent installer, or an equivalent deployment template.
   - Expected result: Portal notification "Deployment succeeded"; new hosts appear in **Session hosts** with Status = **Available**.

6. **Confirm each new host booted on the correct image/driver.**
   - Portal path (host's image setting): Azure Portal → **Host pools → POOL-FIN-01** → **Session hosts** → click the new host name (opens the VM resource) → left menu **Properties** → check the **Compute Gallery image version** field matches the version from step 3.
   - CLI:
     ```bash
     az vm show --resource-group <resource-group> --name SHFIN-01-A \
       --query "storageProfile.imageReference" -o json
     ```
   - Also confirm boot time and driver via `eventvwr.msc` → **Windows Logs > System** → Event ID `1` (Source `Microsoft-Windows-Kernel-General`), and Device Manager → Display adapters → driver **Properties** tab for the `igdumd64.dll` version.
   - Expected result: `imageReference` shows the known-good version; boot time matches redeployment time; driver version is **not** `31.0.101.4146`.

7. **Take the pool out of drain mode.**
   - Path: Azure Portal → **Host pools → POOL-FIN-01** → **Session hosts** → select all hosts → toolbar **Drain mode** → toggle **Off**.
   - CLI:
     ```bash
     az desktopvirtualization sessionhost update \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --name SHFIN-01-A --allow-new-session true
     ```
   - Expected result: Portal "Drain mode" column reads **Off** for every row; CLI `sessionhost show` returns `"allowNewSession": true`.

8. **Test-login validation.**
   - Path: AVD client (or web client) → connect using a designated test account targeted at POOL-FIN-01 → wait 60 seconds.
   - Expected result: Desktop renders fully within a few seconds and stays visible for the full 60 seconds with no black screen or disconnect.

## Verification

Confirm **all** of the following before closing the incident:

- [ ] Test login (Resolution step 8) succeeds with no black screen on **every** rebuilt host.
- [ ] On each rebuilt host: `eventvwr.msc` → **Windows Logs > System** → filter Event ID `9011` (Source `Desktop Window Manager`) shows a fresh entry within 1 minute of the test login, with **no** Event ID `9009` from the same source in the following 15 minutes. CLI equivalent (run against each host if remote log query is configured):
  ```bash
  az monitor log-analytics query \
    --workspace <workspace-id> \
    --analytics-query "Event | where Computer == 'SHFIN-01-A' and EventID in (9009, 9011) | order by TimeGenerated desc | take 10" \
    -o table
  ```
- [ ] Helpdesk/incident queue shows at least 3 real (non-test) user logins to POOL-FIN-01 completed successfully with no black-screen report, checked 30 minutes after Resolution step 7.
- [ ] Re-run the Application log filter (Event ID `1000`, **Windows Logs > Application**) on every rebuilt host 2 hours after re-enabling the pool — confirm zero matching rows.
- [ ] Confirm pool state via CLI matches expectations:
  ```bash
  az desktopvirtualization sessionhost list \
    --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
    --query "[].{Name:name, AllowNewSession:allowNewSession, Status:status}" -o table
  ```
  All hosts should show `AllowNewSession: true` and `Status: Available`.
- [ ] Written confirmation obtained directly from the change/image owner that the faulty image version has been withdrawn from the deployment pipeline (not just posted in the incident channel).

If any item fails, return to Resolution step 3 and re-verify the correct known-good image version was recorded and used — do not repeat the rollback with the same version without re-checking.

## Rollback

Use if the fix itself causes a new failure. Target: each action below completed in under 3 minutes; do not retry a failing action more than once before escalating.

**Always do first:**
- Path: Azure Portal → **Host pools → POOL-FIN-01** → **Session hosts** → select header checkbox → **Drain mode** → **On**.
- CLI:
  ```bash
  for host in $(az desktopvirtualization sessionhost list --host-pool-name POOL-FIN-01 --resource-group <resource-group> --query "[].name" -o tsv); do
    az desktopvirtualization sessionhost update --host-pool-name POOL-FIN-01 --resource-group <resource-group> --name "$host" --allow-new-session false
  done
  ```
- This is safe regardless of which failure below occurs and stops new users connecting while you handle it.

1. **New VM deployment fails (Resolution step 5 shows "Failed"):**
   - Path: Azure Portal → bell/Notifications icon → failed deployment entry → **Operation details** → copy the Status Message/error code.
   - CLI:
     ```bash
     az deployment operation group list \
       --resource-group <resource-group> --name <deployment-name> \
       --query "[?properties.provisioningState=='Failed'].properties.statusMessage" -o json
     ```
   - Post the error in the incident channel tagging the platform/image team; state the pool is in drain mode.
   - Do not click **Retry** in the portal or re-run `az vm create`. Wait for platform team response — this is now their action, not yours.

2. **Known-good image also crash-loops on test login (Resolution step 8 fails):**
   - Confirm drain mode is On (see above — portal path or CLI loop).
   - Escalate immediately in the incident channel as a P1: the "known-good" image is not actually clean.
   - Do not select or deploy any other image version yourself — this is now an image-team investigation, not a repeat of this runbook.

3. **Forced logoff (Resolution step 2) triggers a data-loss complaint:**
   - Advise the user: log back in, then in the affected app use File > Info > Manage Document/Workbook > Recover Unsaved Documents.
   - Log the user's name, app, and file name in the incident notes.
   - Continue the main procedure; this does not block the pool-wide rollback.

4. **Drain mode won't toggle off after rollback (Resolution step 7 fails):**
   - Path: Azure Portal → **Virtual machines** → select the host → **Connect** → **RDP/Bastion** (requires local admin).
   - Run `Restart-Service RDAgent` in an elevated PowerShell session on the host.
   - Retry via portal: **Host pools → POOL-FIN-01** → **Session hosts** → select the host → **Drain mode → Off**, or CLI:
     ```bash
     az desktopvirtualization sessionhost update \
       --host-pool-name POOL-FIN-01 --resource-group <resource-group> \
       --name SHFIN-01-A --allow-new-session true
     ```
   - If still stuck after this one retry, escalate to the platform team naming the specific host — do not attempt a third time yourself.

## Preventive

1. **Mandatory pilot/canary validation before pool-wide image deployment (pre-deployment test gate).** Owner: **release engineer**. Timing: **before deployment** — runs immediately after image build, before any pool-wide push. Process: deploy to one canary host, run an automated synthetic login + DWM health check. Pass/fail: canary host must produce Event ID `9011` (DWM started) with **zero** Event ID `1000`/`9009` within 5 minutes of test login; any Event `1000`/`9009` = automatic fail. If it fails: image is blocked from pool-wide deployment and returned to the image owner with the captured event log excerpt attached. Automation: **automated** (CI/CD gate) — [REQUIRES: synthetic login test harness + automated Event Viewer/Log Analytics query integrated into the image pipeline].

2. **Mandatory driver/component version diff as a deployment gate (pre-deployment test gate).** Owner: **image owner**. Timing: **before deployment** — runs as part of the build pipeline, before the canary step (control 1). Pass/fail: diff tool must show zero driver version changes without an attached vendor release note/advisory link; any unattached driver change = fail. If it fails: pipeline blocks promotion and requires the image owner to attach the advisory or revert the driver before re-submitting. Automation: **automated** — [REQUIRES: automated driver/component version-diff tooling in the image pipeline, not yet confirmed to exist].

3. **In-flight monitoring during the rollout window (in-flight monitoring).** Owner: **DWP engineer** (on-call for the rollout window). Timing: **during deployment** — active from the first host reboot until the last host in the pool has rebooted onto the new image. Pass/fail: alert fires if **more than 2 hosts** in the pool log Event ID `1000` (Application Error, `dwm.exe`) within any 15-minute window during rollout. If it fails: rollout auto-pauses (remaining un-rebooted hosts held back) and the on-call DWP engineer is paged to assess before continuing. Automation: **automated** — [REQUIRES: alert rule wired to pause/hold the deployment pipeline, not just notify; current alerting is notify-only].

4. **Automated alerting on the specific failure signature, standing/ongoing (in-flight + post-deployment monitoring).** Owner: **DWP engineer** (monitoring on-call). Timing: **during and after deployment** — always-on across all AVD session hosts, not just during a rollout. Pass/fail: alert fires on any single occurrence of Event ID `1000` where the faulting module matches a graphics driver pattern, or any Event ID `9009` (Desktop Window Manager). If it fires: on-call DWP engineer triages within 15 minutes using the Detection section of this KB. Automation: **automated** — [REQUIRES: Log Analytics/Sentinel alert rule scoped to these two event IDs across the AVD host pool workspace].

5. **Defined post-deployment bake-in period (in-flight/early post-deployment monitoring).** Owner: **release engineer**, with sign-off from **change manager**. Timing: **after deployment** — fixed 2-hour window starting at pool re-enable (Resolution step 7), covering the next login wave. Pass/fail: zero Event `1000`/`9009` occurrences and at least 3 real user logins completed cleanly within the window = pass; any occurrence = fail. If it fails: change manager holds the change open and triggers the Rollback section rather than closing it. Automation: **manual** review of automated alert output — could be automated by having the bake-in pass/fail evaluated automatically from the same Log Analytics query used in control 4.

6. **Post-deployment validation gate before closing the change (post-deployment validation).** Owner: **change manager**. Timing: **after deployment** — the final gate before the change record is closed, run after the bake-in window (control 5) completes. Pass/fail: all Verification section checklist items in this KB must be ticked, including written confirmation from the image owner that the faulty version is withdrawn from the pipeline. If it fails: change manager keeps the change record open and re-engages the release engineer/image owner; the change cannot be closed on a partial pass. Automation: **manual** sign-off — the underlying event/login checks it depends on are automated (controls 4-5).

7. **Rollback trigger with a defined threshold (rollback trigger).** Owner: **DWP engineer** (incident responder), authorized to act without separate approval once the threshold is met. Timing: **during or immediately after deployment**. Pass/fail threshold: **any 2 hosts** in the pool showing Event `1000`/`9009` within 15 minutes, or **any single host** crash-looping (3+ Event `1000` occurrences on the same host within 10 minutes), automatically authorizes immediate rollback per the Rollback section — no additional sign-off required to act. If the threshold is not met but isolated single events occur: monitor only, do not roll back. Automation: **automated detection, manual execution** — [REQUIRES: alert rule with the above threshold logic; rollback execution itself remains a manual runbook action].

8. **Vendor advisory tracking for the graphics driver (pre-deployment gate, recurring).** Owner: **image owner**. Timing: **before deployment** — checked each time a new driver version is proposed for the master image, and additionally on a recurring monthly cadence for drivers already in use. Pass/fail: no open/unacknowledged known-issue advisory from the driver vendor (Intel) for the version being added or currently deployed. If it fails: image owner holds the driver version out of the master image (new deployments) or raises a proactive change to patch/roll back (existing deployments). Automation: **manual** — [REQUIRES: subscription/integration to vendor advisory feed to automate detection; currently a manual check].

9. **Knowledge update from this incident (knowledge update).** Owner: **service desk lead** (for the L1 article) jointly with the **DWP engineer** who worked the incident (for this L2/L3 KB and the runbook). Timing: **after deployment** — completed as part of incident closure, before the change/incident record is closed by the change manager (control 6). Pass/fail: this KB, the runbook, and the L1 article are updated with any new detection signal, event ID, or step discovered during the incident that wasn't already documented; closure is blocked until the change manager confirms the update is logged. Automation: **manual** — no automation applicable; this is a documentation/process step.

## Related

- Runbook: [Runbook - AVD Black Screen Incident (POOL-FIN-01).md](../day5/Runbook%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md)
- RCA: [RCA - AVD Black Screen Incident (POOL-FIN-01).md](../day4/RCA%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md)
- Known-error Record: [Known-error Record - AVD Black Screen Incident (POOL-FIN-01).md](../day4/Known-error%20Record%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md)
- Closure Note: [Closure Note - AVD Black Screen Incident (POOL-FIN-01).md](../day4/Closure%20Note%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md)
- Ranked Cause Analysis: [Ranked Cause Analysis - AVD Black Screen Incident (POOL-FIN-01).md](../day4/Ranked%20Cause%20Analysis%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md)
- L1 self-service article: [KB Article - Black Screen After Login (Virtual Desktop).md](KB%20Article%20-%20Black%20Screen%20After%20Login%20(Virtual%20Desktop).md)
