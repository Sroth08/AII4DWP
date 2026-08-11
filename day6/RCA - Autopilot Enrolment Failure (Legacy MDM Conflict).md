# RCA: Autopilot Enrolment Failure — Legacy MDM Conflict

| Field | Value |
|---|---|
| Title | RCA: Autopilot Enrolment Failure — Legacy MDM Conflict |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | DWP Endpoint Engineer |
| Reviewed | Self |
| Status | Draft |
| Source | MDM diagnostic export, single test device (Win11 Autopilot enrolment attempt) |

## Purpose
Root cause analysis and remediation plan for a Windows Autopilot enrolment failure caused by a stale, pre-existing legacy MDM enrolment on the target device. Findings apply to any device migrating to Autopilot that previously went through manual/legacy MDM enrolment.

---

## 1. Diagnostic Evidence (Scope Facts)

- Enrolment result: **Failed**
- Error code: **0x80180014** — "The device is already enrolled in MDM."
- Azure AD joined: **Yes**
- Existing MDM enrolment: **Yes** — previous enrolment dated 2023‑11‑04, source: legacy manual MDM enrolment
- Policy application: **Failed** — 0 of 4 profiles applied; last error **0x80070005 (Access denied)**
- Licensing: **Correct** — Intune P1 and Autopilot licenses both present
- Network connectivity: **Healthy** — all endpoints reachable, no proxy

## 2. Causes Considered (Ranked)

| Rank | Hypothesis | Status |
|---|---|---|
| 1 | Stale legacy MDM enrolment (2023‑11‑04) never removed before Autopilot attempt | **Confirmed root cause** — directly stated by the 0x80180014 error description and corroborated by `MDMEnrolled: Yes` from a different enrolment source |
| 2 | Residual enrolment artefacts (certs/scheduled tasks) blocking the new policy channel | Ruled in as a *symptom/mechanism* of #1 rather than an independent cause — explains the 0/4 profiles + 0x80070005 access-denied detail |
| 3 | Duplicate/conflicting device object in Azure AD or Intune | Not required to explain the evidence once #1 is confirmed; checked opportunistically during remediation |

## 3. Confirmed Root Cause
The device retains an **active legacy manual MDM enrolment from 2023‑11‑04**. Autopilot enrolment cannot complete over a conflicting existing enrolment (0x80180014), and the partial policy push that was attempted was denied (0x80070005) because the old enrolment's certificates/registration were still occupying the device's management channel. Licensing and network are confirmed healthy and are **not** contributing factors.

---

## 4. Remediation Plan — Exact Steps in Order

> **Legend:** 🖥️ = Intune admin center only (no device access needed) · 🔧 = Requires device access (physical or remote session)

### Step 1 — 🖥️ Identify the stale device record(s)
- Intune admin center > **Devices > All devices** > search by device name / serial number / hardware hash.
- Confirm the enrolment date (2023‑11‑04) and enrolment type ("Legacy manual") on the existing record.
- Cross-check **Entra ID (Azure AD) > Devices** for the corresponding device object and note its Object ID.

### Step 2 — 🖥️ Remove the stale device record from Intune
- **Devices > All devices** > select the stale (legacy) device record > **Retire** if the device can still check in, otherwise **Delete**.
- Use **Delete** in this case: the device is stuck mid-enrolment and cannot reliably check in, so a graceful Retire command may never be acknowledged. Delete forcibly clears the MDM management record and its "already enrolled" state at the service side.

### Step 3 — 🖥️ Remove the stale device object in Entra ID (if it persists)
- **Entra ID > Devices** > select the stale device object > **Delete**.
- Intune device deletion does not always cascade to the Azure AD device object for legacy-enrolled devices — verify it is actually gone after Step 2, and remove manually if it lingers.

### Step 4 — 🔧 Clear the legacy enrolment client-side
*Requires device access (physical or remote session).*
- If the device is reachable: **Settings > Accounts > Access work or school** > select the old work account > **Disconnect**.
- Confirm cleanup of leftover artefacts:
  - Registry: `HKLM\SOFTWARE\Microsoft\Enrollments\<old enrolment GUID>` should no longer exist.
  - Scheduled Tasks: `Microsoft\Windows\EnterpriseMgmt\<old enrolment GUID>` should be removed.
  - Certificates: `certlm.msc` > Personal store — no orphaned MDM enrolment certificate tied to the old GUID.
- If the device cannot be reliably reached or cleaned interactively (common when the failure occurs mid-OOBE/Autopilot ESP): perform a **Reset this PC (Remove everything)** or reimage instead of manual cleanup — this guarantees a clean enrolment state without hunting for residual artefacts.

### Step 5 — 🔧 Re-trigger Autopilot enrolment
*Requires device access (physical or remote session).*
- Boot to OOBE (post-reset) so the device re-runs the Autopilot profile, or if mid-Windows, use **Settings > Accounts > Access work or school > Enroll only in device management**.

### Why this order matters
The Intune/Entra ID cleanup (Steps 1–3) must happen **before** the device-side cleanup/reset (Steps 4–5). Resetting the device first, while the stale record still exists in Intune/Entra ID, risks the device re-registering against the same stale record or creating a second orphaned duplicate — reproducing the same conflict or setting up a future duplicate-object issue.

---

## 5. Verification — Confirming Autopilot Completes Successfully
- The Autopilot Enrollment Status Page (ESP) completes with no errors and reaches the desktop.
- 🖥️ **Devices > All devices**: device now shows a **single** record, enrolment date = today, enrolment type = **Windows Autopilot** (not "Legacy manual").
- 🖥️ **Devices > Enrollment > Windows Enrollment > Devices** (or **Devices > Monitor > Autopilot deployments**): deployment status shows **Successful** for the device's serial number, with no repeat failures.
- 🔧 On-device: `dsregcmd /status` shows `AzureAdJoined: YES` and a populated MDM management URL; MDM diagnostic Event Viewer logs show no new 0x80180014/0x80070005 events.
- 🖥️ The device's compliance policy (see [Windows 11 Intune Compliance Policy - Security Baseline Mapping.md](Windows%2011%20Intune%20Compliance%20Policy%20-%20Security%20Baseline%20Mapping.md)) now evaluates to **Compliant** or **In grace period** rather than "Not evaluated," confirming policy delivery is actually flowing end-to-end — this directly resolves the original "0 of 4 profiles applied" symptom.

---

## 6. Preventive Action — Stop This Recurring Across the Fleet
- 🖥️ **Pre-migration audit:** Before any device enters the Autopilot migration ring, bulk-filter **Devices > All devices** by enrolment type = legacy/manual, cross-reference against the list of devices scheduled for migration, and proactively **retire** any matching stale records — admin-center only, no device access needed, and can be done ahead of time at scale.
- **Migration runbook gate:** Add a mandatory pre-flight check to the migration runbook: no device proceeds to Autopilot re-provisioning until Intune/Entra ID confirm **zero pre-existing enrolment records** for that device's hardware hash.
- **Device-side discovery script (optional, for scale):** Where devices are still reachable prior to migration, run a discovery script checking `HKLM\SOFTWARE\Microsoft\Enrollments` for enrolment GUIDs predating the migration project, and flag/clean any hits before the device is queued for Autopilot reset.

---

## Notes
- Consistent with the Personal AI Usage Charter: this document contains no device identifiers, serial numbers, tenant names, or credentials — only sanitized diagnostic facts and generic remediation guidance.
- Apply generate-then-verify: validate this remediation sequence against a single pilot device before scripting/scaling it across the fleet.
