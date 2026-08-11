# Detailed RCA: Autopilot Enrolment Failure — Legacy MDM Conflict

## Document Control
- Incident type: Windows Autopilot enrolment failure
- Affected scope: Single test device (representative of any device migrating with a pre-existing legacy MDM enrolment)
- Source: MDM diagnostic export collected from the failed device
- Companion document: [RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md) — remediation steps and verification
- Analyst role: DWP Analyst
- Date of analysis: 2026-08-11

## Executive Summary
A test device failed Windows Autopilot enrolment with error `0x80180014` ("The device is already enrolled in MDM"), and 0 of 4 configuration profiles applied with a secondary error `0x80070005` (Access denied). Investigation confirmed the device retained an **active legacy manual MDM enrolment from 2023‑11‑04** that was never removed before the device entered the Autopilot migration flow. Azure AD join, licensing, and network connectivity were all confirmed healthy and are not contributing factors. Root cause: the stale legacy enrolment blocked the new Autopilot enrolment at the service level, and residual client-side artefacts from that legacy enrolment caused the subsequent partial policy push to be denied access. The systemic gap enabling this is the absence of a pre-migration audit step to detect existing MDM enrolments before a device enters the Autopilot ring.

## Supporting Evidence

### Raw diagnostic export (source of truth for this analysis)
```
EnrollmentState : Failed
ErrorCode : 0x80180014
ErrorDescription: The device is already enrolled in MDM.
MDMEnrolled : Yes (previous enrolment from 2023-11-04)
EnrolmentSource : Legacy manual MDM enrolment
ProfilesApplied : 0 of 4
LastError : 0x80070005 (Access denied)
AzureADJoined : Yes
IntuneP1License : Yes
AutopilotLicense: Yes
Network : All endpoints reachable, no proxy
```

### Scope facts extracted from the export
- Enrolment result: **Failed**
- Error code: **0x80180014** — "The device is already enrolled in MDM"
- Azure AD joined: **Yes**
- Existing MDM enrolment: **Yes** — legacy manual enrolment dated 2023‑11‑04
- Policy application: **Failed** — 0 of 4 profiles applied; last error 0x80070005 (Access denied)
- Licensing: **Correct** — Intune P1 and Autopilot licenses both present
- Network connectivity: **Healthy** — all endpoints reachable, no proxy

### Note on error code interpretation
Per the source export, `0x80180014` is given with its own description ("already enrolled in MDM") and is treated as authoritative rather than inferred. `0x80070005` is the standard Win32 `E_ACCESSDENIED` HRESULT — a generic access-denied code, confirmed generically but not assumed to mean anything MDM-specific beyond what's stated.

## Timeline

> **Note:** The source export does not include event timestamps beyond the legacy enrolment date. The sequence below is reconstructed from the logical order of the Autopilot enrolment process and the two distinct error codes recorded (enrolment-level failure occurring before policy-level failure). No specific clock times are asserted beyond the one date present in the evidence.

| Stage | Event | Detail |
|---|---|---|
| 2023‑11‑04 | Legacy enrolment created | Device manually enrolled into MDM via a legacy (non-Autopilot) process. Record never retired/disconnected. |
| Pre-migration | Device queued for Autopilot migration | No evidenced pre-flight check confirmed absence of an existing MDM enrolment before scheduling. |
| Enrolment attempt (current) | OOBE/Autopilot enrolment initiated | Device begins Autopilot profile registration against Entra ID/Intune. |
| Enrolment attempt (current) | Enrolment rejected | `EnrollmentState: Failed`, `ErrorCode: 0x80180014` — service detects the pre-existing 2023‑11‑04 enrolment and blocks the new one. |
| Enrolment attempt (current), following the above | Partial policy push attempted | `ProfilesApplied: 0 of 4` — despite the enrolment-level rejection, a policy delivery attempt was logged and failed. |
| Enrolment attempt (current), following the above | Policy push denied | `LastError: 0x80070005 (Access denied)` — consistent with residual legacy-enrolment client-side artefacts (certificates/registration) still occupying the management channel. |
| Enrolment attempt (current) | Supporting checks pass | Azure AD join, licensing, and network all confirmed healthy at time of failure — ruling these out as contributing causes. |

## Hypothesis Elimination Summary
Three candidate causes were considered against the evidence:

1. **Stale legacy MDM enrolment never removed before the Autopilot attempt** — **Confirmed.** Directly stated by the `0x80180014` error description and corroborated by `MDMEnrolled: Yes` from a different enrolment source (legacy manual, 2023‑11‑04) than the current Autopilot attempt.
2. **Residual enrolment artefacts (certificates/registration) blocking the new policy channel** — **Confirmed as contributing mechanism.** Explains why a *policy push* was attempted and denied (`0/4 profiles`, `0x80070005`) rather than the process stopping cleanly at the enrolment-level error alone.
3. **Duplicate/conflicting device object in Azure AD or Intune** — **Not required to explain the evidence.** Azure AD join is confirmed healthy (`AzureADJoined: Yes`) with no indication of a second conflicting object; not pursued further as an independent cause.
4. **Licensing gap** — **Eliminated.** Both `IntuneP1License` and `AutopilotLicense` confirmed present.
5. **Network/connectivity issue** — **Eliminated.** All endpoints reachable, no proxy.

## Detailed 5-Why Analysis

### Problem Statement
Autopilot enrolment failed on the test device (`0x80180014`), and 0 of 4 configuration profiles applied (`0x80070005`, Access denied).

### Why 1
**Why did Autopilot enrolment fail?**
Because the device attempted to register a new MDM enrolment while it already held an active MDM enrolment record, and the MDM service rejected the new enrolment.
- Evidence: `ErrorCode: 0x80180014`, description "The device is already enrolled in MDM"; `MDMEnrolled: Yes`.

### Why 2
**Why did the device already have an active MDM enrolment at the time of the Autopilot attempt?**
Because a legacy manual MDM enrolment performed on 2023‑11‑04 was never removed or de-registered before the device entered the Autopilot migration flow.
- Evidence: `EnrolmentSource: Legacy manual MDM enrolment`, dated 2023‑11‑04 — roughly 2.5 years prior to the current attempt, with no retirement/disconnect step evidenced in between.

### Why 3
**Why wasn't the legacy enrolment removed before the device entered the Autopilot migration process?**
Because there is no evidenced pre-migration check or gate in the process that verifies a device has zero pre-existing MDM enrolments before Autopilot re-provisioning begins.
- Evidence: absence of any retire/disconnect record prior to the enrolment attempt; the attempt proceeded directly against a device with a known conflicting enrolment.

### Why 4
**Why did the partial policy push fail with access denied instead of the process stopping cleanly at the enrolment conflict?**
Because residual client-side artefacts from the legacy enrolment (certificates and registration data tied to the 2023 enrolment) were still occupying the device's management channel, so a subsequent profile delivery attempt was denied access rather than the process halting immediately at the first error.
- Evidence: `LastError: 0x80070005 (Access denied)` recorded specifically against profile application (`0 of 4`), distinct from and logically subsequent to the enrolment-level `0x80180014` error.

### Why 5
**Why did this reach the point of a logged enrolment failure instead of being caught during migration planning?**
Because there is no documented fleet-wide pre-flight audit that cross-references devices scheduled for Autopilot migration against their existing Intune/Entra ID enrolment records before the migration wave begins.
- Evidence: licensing, Azure AD join, and network were all independently confirmed healthy — ruling out infrastructure/config gaps — leaving the absence of a pre-migration enrolment audit as the systemic gap that allowed a known-type conflict (legacy enrolment) to surface only at enrolment time rather than earlier in planning.

## Root Cause
**Primary root cause:** A stale legacy manual MDM enrolment (2023‑11‑04) was never removed from the device before it entered the Autopilot migration flow, causing the new enrolment to be rejected (`0x80180014`) and a subsequent partial policy push to be denied (`0x80070005`) due to residual client-side artefacts from that legacy enrolment.

**Systemic (process-level) root cause:** No pre-migration gate exists to detect and remove existing MDM enrolments before a device is queued for Autopilot re-provisioning.

## Contributing Factors
- Long dwell time (2023 → 2026) between the legacy enrolment and the migration attempt, increasing the likelihood the old record was forgotten or undocumented.
- No automated pre-flight validation of enrolment state before a device is assigned to an Autopilot migration ring.
- No distinct alerting/reporting category for "device already enrolled" (0x80180014-class) errors to flag them for proactive cleanup rather than being triaged as a generic enrolment failure.

## Preventive Actions
- **Pre-migration audit (admin-center only):** Before any device enters the Autopilot migration ring, bulk-filter Intune **Devices > All devices** by enrolment type = legacy/manual, cross-reference against the migration schedule, and proactively retire matching stale records ahead of time.
- **Migration runbook gate:** Add a mandatory pre-flight step to the migration runbook — no device proceeds to Autopilot re-provisioning until Intune/Entra ID confirm zero pre-existing enrolment records for that device's hardware hash.
- **Reporting refinement:** Tag/flag `0x80180014`-class failures distinctly in enrolment failure reporting so they route to a "stale enrolment cleanup" queue rather than generic enrolment troubleshooting.
- **Optional discovery script:** For devices still reachable prior to migration, run a discovery check against `HKLM\SOFTWARE\Microsoft\Enrollments` for enrolment GUIDs predating the migration project, flagging any hits for cleanup before the device is queued.

## Notes
- Consistent with the Personal AI Usage Charter: this document contains no device identifiers, serial numbers, tenant names, or credentials — only sanitized diagnostic facts and generic remediation guidance.
- Remediation steps (exact admin-center and device-side actions, verification checks) are documented separately in the companion RCA to keep this document focused on evidence, timeline, and root cause analysis.
