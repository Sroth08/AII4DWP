L2/L3 Knowledge Base Article: Autopilot Enrolment Failure — Legacy MDM Conflict

Version: 1.0 | Date: 11/08/2026 | Status: Draft

---

## Background

Windows Autopilot is the zero-touch provisioning method used to enrol devices into Intune/Entra ID management during first-time setup (or after a reset), applying compliance policies, apps, and configuration profiles automatically without an engineer imaging the device manually. A device can only be actively managed by **one** MDM enrolment at a time — the MDM enrolment protocol on Windows rejects a second concurrent enrolment attempt by design, to prevent two management authorities issuing conflicting policy to the same device. This matters because if an old, forgotten enrolment record is never cleanly removed, any later legitimate re-enrolment attempt (such as an Autopilot migration) will be blocked at the protocol level, and the device cannot receive its compliance policy, apps, or configuration profiles until the conflict is resolved — leaving the user unable to safely use the device for work.

## Symptom

**What the user reports:**
- New or freshly reset device gets stuck during first-time setup, or shows an error/registration-related message on screen.
- Device does not receive expected apps/policies after setup appears to finish.

**What the engineer observes:**
- MDM diagnostic export shows `EnrollmentState: Failed`.
- `ErrorCode: 0x80180014` ("The device is already enrolled in MDM").
- `ProfilesApplied: 0 of 4` (or any count less than expected) with `LastError: 0x80070005` (Access denied).
- `MDMEnrolled: Yes`, with an `EnrolmentSource` that does **not** match the current Autopilot attempt (e.g., "Legacy manual MDM enrolment") and an enrolment date that significantly predates the current migration/setup attempt.
- `AzureADJoined`, licensing (Intune P1, Autopilot), and network connectivity all report healthy — ruling out identity, licensing, and connectivity as causes.

## Root Cause

**Primary root cause:** The device retained an active legacy manual MDM enrolment (in the source incident, dated 2023‑11‑04) that was never retired/disconnected before the device entered the Autopilot migration flow. The MDM enrolment service rejected the new Autopilot enrolment because a conflicting enrolment already existed (`0x80180014`). A subsequent partial policy delivery attempt was then denied (`0x80070005`) because residual client-side artefacts from the legacy enrolment (registration data/certificates) were still occupying the device's single management channel.

**Systemic root cause:** No pre-migration process exists to detect and remove pre-existing MDM enrolments before a device is queued for Autopilot re-provisioning, so this class of conflict is only discovered at enrolment time.

**Evidence confirming this cause:**
- MDM diagnostic export field `ErrorCode: 0x80180014`, with description "The device is already enrolled in MDM" — states the enrolment conflict directly.
- MDM diagnostic export fields `MDMEnrolled: Yes` and `EnrolmentSource: Legacy manual MDM enrolment`, dated 2023‑11‑04 — confirms a pre-existing enrolment from a different source than the current Autopilot attempt.
- MDM diagnostic export fields `ProfilesApplied: 0 of 4` and `LastError: 0x80070005` — confirms the failure progressed past the initial enrolment rejection into a distinct, later policy-delivery step, consistent with residual artefacts blocking that channel rather than the process stopping cleanly at the first error.
- `AzureADJoined: Yes`, `IntuneP1License: Yes`, `AutopilotLicense: Yes`, `Network: All endpoints reachable, no proxy` — rules out AAD join, licensing, and network as contributing causes.
- **Comparison/control check:** A device with no prior enrolment history, run through the same Autopilot profile, completes with `EnrollmentState: Succeeded` and `ProfilesApplied: 4 of 4` — isolating the fault to devices carrying a pre-existing enrolment record, not a problem with the Autopilot profile or infrastructure itself.

## Detection

Confirm this specific issue **before** taking any remediation action. The steps below are split into a **fast path** (one log, one pass, under 3 minutes) and **deeper validation** (only needed if the fast path is ambiguous or you need to rule out a broader incident).

### Fast path — under 3 minutes

**Step 1 — Generate/open the one report you need (~60–90 seconds).**
On the device, run:
```powershell
MdmDiagnosticsTool.exe -area Autopilot;DeviceEnrollment -cab C:\MDMDiagReport.cab
```
Extract `C:\MDMDiagReport.cab` (right-click → **Extract all**) and open `MDMDiagReport.html` (or `.xml`) in a browser/editor. If a report was already attached to the ticket, skip straight to opening it — do not regenerate.

**Step 2 — Scan these 6 fields in that one report (~60 seconds).** All of them live in the same file — you do not need to open any other log for the fast path.

| Field | What it means if unhealthy | Confirms this issue |
|---|---|---|
| `EnrollmentState` | `Failed` | ✅ if Failed |
| `ErrorCode` | `0x80180014` | ✅ if this exact code |
| `MDMEnrolled` | `Yes`, with an `EnrolmentSource` that isn't "Autopilot" (e.g. legacy/manual) | ✅ if a non-Autopilot source is shown |
| `ProfilesApplied` | Less than the expected total (e.g. `0 of 4`) | ✅ if less than expected |
| `LastError` | `0x80070005` | ✅ if this exact code |
| `AzureADJoined` / `IntuneP1License` / `AutopilotLicense` / `Network` | All healthy (`Yes` / "reachable, no proxy") | ✅ if all healthy — rules out identity/licensing/network so you don't waste time on them |

**Step 3 — Decision (~10 seconds).** If `ErrorCode = 0x80180014` **and** `MDMEnrolled = Yes` from a non-Autopilot source **and** the last four fields are all healthy → this is confirmed as this known issue. Go straight to **Resolution**. If any of those don't match, stop — this is not this known issue; investigate as a new incident instead.

### Deeper validation (optional — only if the fast path above is ambiguous)

- **Registry cross-check:** `regedit.exe` → `HKLM\SOFTWARE\Microsoft\Enrollments` → check the `EnrollmentType`/`ProviderID` values under each GUID subkey to independently corroborate the `EnrolmentSource` shown in the report.
- **Event Viewer cross-check:** `eventvwr.msc` → **Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin**, filtered to the time of the failed attempt. *Caveat:* exact Event ID numbers in this log vary by Windows build and are not asserted here with confidence — use `Get-WinEvent -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin" -FilterHashtable @{StartTime=...; EndTime=...}` rather than searching for a specific ID. Treat the fast-path report fields as the authoritative signal, not this log.
- **Comparison/control check:** Run the same `MdmDiagnosticsTool.exe` command on a device with no enrolment history, enrolled via the same Autopilot profile. Expect `EnrollmentState = Succeeded` and `ProfilesApplied = 4 of 4`, with only a single subkey under `HKLM\SOFTWARE\Microsoft\Enrollments`. If the control device also fails, stop — this points to a different/broader incident, not this known issue.

## Resolution

All portal paths below start from a fresh navigation — always confirm you are acting on the correct device name/serial number at each step, not a similarly-named device.

### Primary path — ~5 minutes hands-on (try this first)

1. **Open the device record in Intune.** Path: `https://intune.microsoft.com` → left navigation **Devices** → **All devices** → search box → enter device name/serial number.
   - *Expected result:* One row returned; opening it shows **Enrollment type** = "Legacy manual" (or similar) and **Enrolled date** matching the stale record identified in Detection.

2. **Record the device's Entra ID Object ID.** Path: same device blade → **Properties** tab → "Device information" section → **Entra AD Device ID** field.
   - *Expected result:* A GUID value copied into your ticket notes for use in step 4.

3. **Delete the stale device record in Intune.** Path: same device blade → **Overview** tab → command bar **Delete** → confirm **Yes**. **Elevated permission required: Intune Administrator (or equivalent delete-devices role).**
   - *Expected result:* Device no longer appears in **All devices** within 5 minutes.

4. **Check and delete the corresponding Entra ID device object, if present.** Path: `https://entra.microsoft.com` → left navigation **Identity** → **Devices** → **All devices** → search box → paste the Object ID from step 2 → if a row is returned, tick its checkbox → command bar **Delete** → confirm **Yes**. **Elevated permission required: Cloud Device Administrator (or equivalent).**
   - *Expected result:* No row returned for that Object ID on a subsequent search.

5. **Clear the legacy enrolment client-side.** On the device (remote session or physical access): `Settings > Accounts > Access work or school` → select the old account entry → **Disconnect** → confirm.
   - *Expected result:* The old account entry no longer listed.

6. **Re-trigger Autopilot enrolment.** If already in Windows: `Settings > Accounts > Access work or school > + Add a work or school account > Alternate actions > Enroll only in device management`. (If the device is already sitting at OOBE, just continue through the on-screen prompts instead.)
   - *Expected result:* The Enrollment Status Page (ESP) begins, showing "Device setup" and "Account setup" stages in progress.

**This is where your ~5 minutes of hands-on effort ends.** The ESP itself then runs unattended for several minutes as the device pulls down policies/apps — this is device processing time, not engineer effort. Move to your next ticket and come back to run Verification once the user reports ESP has finished (or after ~15 minutes).

### Advanced path — only if enrolment fails again with the same error codes (~5–8 minutes hands-on)

If ESP fails again with `0x80180014`/`0x80070005`, residual client-side artefacts are still blocking the channel — clear them directly:

7. **Back up and remove the legacy enrolment registry key.** `regedit.exe` (elevated) → address bar → paste `HKLM\SOFTWARE\Microsoft\Enrollments` → identify the legacy GUID subkey (check `EnrollmentType`/`ProviderID` values) → right-click it → **Export** → save as `Enrollments_<GUID>_backup.reg` → then right-click the same subkey → **Delete** → confirm. **Elevated permission required: local administrator.**
   - *Expected result:* Backup `.reg` file exists at your saved location; the GUID subkey no longer appears under `Enrollments`.

8. **Remove the matching scheduled task.** Task Scheduler → **Task Scheduler Library > Microsoft > Windows > EnterpriseMgmt** → right-click the folder matching the same GUID → **Delete** → confirm. **Elevated permission required: local administrator.**
   - *Expected result:* No task folder remains under `EnterpriseMgmt` matching that GUID.

9. **Back up and remove the matching certificate.** `certlm.msc` → **Personal > Certificates** → locate the certificate referencing the legacy GUID → right-click → **All Tasks > Export** → **Yes, export the private key** → set a password → save as `<GUID>_cert_backup.pfx` → then right-click the same certificate → **Delete** → confirm. **Elevated permission required: local administrator.**
   - *Expected result:* Backup `.pfx` file exists; the certificate no longer appears under **Personal**.

10. **Retry enrolment.** Repeat step 6.
    - *Expected result:* ESP begins again without the same error recurring.

### Last resort — full device reset (not timeboxed; this is device processing time, not hands-on time — typically 20–60+ minutes)

11. **If the primary and advanced paths both fail, or the device is unreachable for client-side cleanup, reset it instead.** `Settings > System > Recovery > Reset this PC > Remove everything > Cloud download`. **Elevated permission required: local administrator. Confirm the user's files are synced to OneDrive before proceeding — this step is destructive.**
    - *Expected result:* Device reboots to the OOBE region-selection screen with no user data/apps remaining. Then repeat step 6.

## Verification

**Fast confirm (~2 minutes) — do this first:**

1. Path: `https://intune.microsoft.com` → **Devices > All devices** → search device name. Confirm: single record, **Enrolled date** = today, **Enrollment type** = "Windows Autopilot".
2. Path: **Devices > Enrollment (Device onboarding) > Windows Enrollment > Devices**. Confirm: **Deployment status** = "Successful" for this device.
3. On device: run `dsregcmd /status`. Confirm: `AzureAdJoined : YES` and MDM management URL populated (not blank).

**Full confirm (~3 minutes) — complete before closing the ticket:**

4. Path: device blade → **Device compliance** tab. Confirm: assigned compliance policy shows "Compliant" or "In grace period", not "Not evaluated".
5. Re-run `MdmDiagnosticsTool.exe -area Autopilot;DeviceEnrollment -cab C:\MDMDiagReport_verify.cab` on the device. Confirm: `EnrollmentState = Succeeded`, `ProfilesApplied` = full expected count, no `0x80180014`/`0x80070005` in the new report.
6. Confirm with the end user that sign-in and at least one line-of-business app work as expected before closing the ticket.

## Rollback
Match the rollback to what specifically went wrong — do not apply generic troubleshooting.

1. **Wrong Entra ID device object deleted (Resolution step 4):** Path: `https://entra.microsoft.com` → **Identity > Devices > Deleted devices** → search by device name → **Restore**. Verify your tenant's retention window (commonly up to 30 days) before relying on this.
2. **Wrong Intune device record deleted (Resolution step 3):** Deleting an Intune device record only removes the management record, it does not wipe the device. Re-enrol the correct device via Company Portal or by re-running its Autopilot profile; no device data is lost from this action alone.
3. **Registry/certificate deletion (Resolution steps 7/9) breaks enrolment further, or the wrong GUID was targeted:** Reimport the `.reg` backup taken in step 7 (double-click the file) and reimport the certificate via `certlm.msc > Personal > All Tasks > Import` using the `.pfx` backup from step 9 and its password. Then retry from Resolution step 6.
4. **Reset (Resolution step 11) performed and the user reports missing local data not backed up to OneDrive:** Do not make further changes to the device. Escalate immediately to the desktop support/data recovery team with the ticket number — a local reset is not reversible from this article; recovery depends on separate backup/imaging solutions.
5. **Conditional Access starts blocking a wider set of users after this fix was applied to multiple devices:** Path: `https://intune.microsoft.com` → **Devices > Compliance policies >** the assigned policy **> Actions for noncompliance**. Confirm the "Mark device noncompliant" schedule is still **7 days**; revert if changed, and notify the incident channel.

## Preventive

Specific process/tooling changes required — not "test before applying". Each control below states owner, timing, pass/fail criteria, failure action, and automation status. Existing controls are strengthened, not replaced; gap-check additions are appended at the end.

**1. Pre-migration enrolment audit** *(strengthened — existing control)* — Manual today, automatable.
- Owner: Release engineer. Timing: Before deployment, run ≥48 hours before each migration wave.
- What/Pass-Fail: Export Intune devices via Graph API `deviceManagement/managedDevices` filtered on `enrollmentType`, cross-reference against the wave's device list. Pass = 0 overlap; Fail = any device appears in both lists.
- If fail: that device is pulled from the wave and routed to a release engineer for manual retirement (Resolution steps 1–4) before being re-added to a later wave.
- [REQUIRES: scheduled Graph API script / Azure Automation runbook to auto-run this and emit a pass/fail count — not yet built]

**2. Migration runbook gate** *(strengthened — existing control)* — Manual today, partially automatable.
- Owner: Change manager. Timing: Before deployment, at wave approval/CAB step.
- What/Pass-Fail: Change manager requires the release engineer's Control 1 output attached to the change record, showing a 0-conflict count for 100% of devices in the wave. Pass = 0-count attached; Fail = missing or count > 0.
- If fail: change manager blocks CAB approval until conflicts are resolved and Control 1 is rerun with a 0 count.
- [REQUIRES: change record field/checklist item conditional on Control 1's reported count — not yet built]

**3. Reporting/tagging change** *(strengthened — existing control)* — Automated once built.
- Owner: Service desk lead (rule maintained by DWP engineer). Timing: Ongoing, active during and after every deployment.
- What/Pass-Fail: Alert rule tags any enrolment failure with `ErrorCode = 0x80180014` into a distinct "stale enrolment conflict" queue linked to this KB. Pass = 100% of such failures auto-tagged; Fail = any 0x80180014 ticket lands in the generic "enrolment failed" queue untagged (target: 0/week).
- If fail: service desk lead reviews the rule; DWP engineer patches the tagging query.
- [REQUIRES: Log Analytics/Azure Monitor alert rule wired to Intune enrolment failure telemetry — confirm this exists in the current tenant]

**4. Endpoint-level discovery script** *(strengthened — was "optional," now recommended)* — Fully automatable.
- Owner: DWP engineer. Timing: Before deployment, run against in-scope devices ahead of each wave.
- What/Pass-Fail: Intune Proactive Remediation detection script queries `HKLM\SOFTWARE\Microsoft\Enrollments` for GUIDs predating the migration project start date. Pass = 0 legacy GUIDs detected per device; Fail = 1+ detected.
- If fail: device is auto-flagged in the remediation report and pulled from the wave for manual cleanup (Resolution steps 7–9) before re-add.
- [REQUIRES: Intune Proactive Remediations / Endpoint analytics licensing confirmed in tenant]

### Gap-check additions (standard preventive layers not yet covered above)

**5. Pre-deployment test gate (smoke test)** — Manual today, scriptable.
- Owner: Release engineer. Timing: Before deployment, whenever Control 1 or Control 4's script logic changes.
- What/Pass-Fail: Run the updated audit/remediation script against a fixed 5-device pilot set (mix of known legacy-enrolled and clean devices). Pass = 100% correct classification on the pilot set; Fail = any misclassification.
- If fail: script is not promoted to the full wave; release engineer fixes and reruns the pilot before wider use.
- [REQUIRES: a maintained pilot/test device set with known, documented enrolment states]

**6. In-flight monitoring (alert during rollout window)** — Automatable.
- Owner: DWP engineer (wave monitor on shift). Timing: During deployment, for the full duration of each wave's rollout window.
- What/Pass-Fail: Monitor enrolment failure telemetry for `ErrorCode 0x80180014` occurrences during the wave. Pass = 0 occurrences; Fail/alert threshold = 1 occurrence (any hit means the pre-deployment audit missed a device).
- If fail: DWP engineer pauses further devices being released into the wave and investigates why Control 1/4 missed that device.
- [REQUIRES: Azure Monitor/Log Analytics alert rule polling Intune enrolment failure data every 15 minutes during wave windows — not yet built]

**7. Post-deployment validation (confirm healthy state before closing the change)** — Automatable.
- Owner: Release engineer. Timing: After deployment, at wave completion, before the change record is closed.
- What/Pass-Fail: Bulk Graph API query confirms `enrollmentType = windowsAzureADWindowsAutopilot` and `complianceState` in (compliant, inGracePeriod) for every device in the completed wave. Pass = 100% of wave devices meet both; Fail = any device outside these states.
- If fail: those devices are routed to a follow-up ticket queue using this KB's Resolution steps; the change record is not closed until resolved.
- [REQUIRES: post-wave validation script with output attached to the change record — not yet built]

**8. Rollback trigger (automatic or manual threshold)** — Manual today, automatable.
- Owner: Change manager (trigger decision); DWP engineer executes the pause. Timing: During deployment, continuously against Control 6's monitoring.
- What/Pass-Fail: If more than 5% of devices in a wave (or 10 devices, whichever is lower) hit `0x80180014` during rollout, the wave is paused — no further devices released until Control 1/4's script is corrected and rerun. Pass = failure rate stays below threshold; Fail = threshold breached.
- If fail: change manager marks the change record "Paused"; release engineer investigates root cause before resuming.
- [REQUIRES: automated pause wired to the Autopilot deployment profile's device group assignment — not yet built, currently a manual judgment call]

**9. Knowledge update (update runbook/checklist from this incident's learnings)** — Manual today, partially automatable.
- Owner: DWP engineer (KB owner). Timing: After deployment, within 5 business days of each incident or wave closure.
- What/Pass-Fail: Any new enrolment-conflict variant found during a wave (e.g., a legacy enrolment type not covered by Control 1/4's filter) is added to this KB's Detection section and the audit script logic. Pass = KB and script updated/version-bumped within 5 business days; Fail = incident closed with no corresponding update.
- If fail: service desk lead flags the ticket at weekly incident review for follow-up.
- [REQUIRES: ITSM workflow rule enforcing a linked KB-update ticket before the parent incident can close — not yet built]

## Related
- [Runbook - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Runbook%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md)
- [RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md)
- [Detailed RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Detailed%20RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md)
- [Known-error Record - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Known-error%20Record%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md)
- [Closure Note - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Closure%20Note%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md)
- [End-User Communications - Autopilot Enrolment Failure (Legacy MDM Conflict).md](End-User%20Communications%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md)
- [KB Article - Autopilot Enrolment Failure (Legacy MDM Conflict) - L1 Self Service.md](KB%20Article%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29%20-%20L1%20Self%20Service.md)
- [Windows 11 Intune Compliance Policy - Security Baseline Mapping.md](Windows%2011%20Intune%20Compliance%20Policy%20-%20Security%20Baseline%20Mapping.md) — compliance policy state referenced in Verification step 4.
