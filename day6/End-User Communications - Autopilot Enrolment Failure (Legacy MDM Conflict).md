# End-User Communications: Autopilot Enrolment Failure (Legacy MDM Conflict)

| Field | Value |
|---|---|
| Title | End-User Communications: Autopilot Enrolment Failure (Legacy MDM Conflict) |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | DWP Endpoint Engineer |
| Source | [Detailed RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Detailed%20RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md), [RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md) |

## Purpose
Three versions of the same incident facts, tailored for audience and technical depth. No facts are added or removed between versions — only language and level of detail change.

---

## Audience 1 — Non-Technical Executive
*(<80 words, no jargon, reassurance first, ends with required action)*

> Your access and data remain fully safe. During a routine device setup upgrade, one device briefly failed to complete its automatic configuration because of a leftover setup record from a previous system. No security or data was affected. Our team identified the cause, corrected it, and confirmed the device now works correctly and applies its security settings as expected. We've also added a check to prevent this affecting other devices during the migration. No action is needed from you.

---

## Audience 2 — Affected End-User Team (10 people, non-technical)
*(<100 words, plain and friendly, one-sentence explanation, next steps, contact)*

> Hi team, one device recently had trouble finishing its automatic setup because of an old leftover setup record from a previous system that hadn't been cleared. This didn't affect your files, access, or security — nothing was lost or exposed. Our support team found the cause, cleaned up the old record, and confirmed the device now sets up and applies security settings correctly. If your device ever gets stuck during setup or shows an "already enrolled" type message, please don't try to fix it yourself — contact the DWP Service Desk and reference this issue so we can resolve it quickly.

---

## Audience 3 — Engineer-to-Engineer Internal Note
*(technical shorthand, no length limit, full pickup-and-run detail)*

**Root cause:** Device carried an active legacy manual MDM enrolment (dated 2023‑11‑04) that was never retired/disconnected before entering the Autopilot migration flow. New Autopilot enrolment attempt was rejected by the service with `0x80180014` ("device already enrolled in MDM"). A subsequent partial policy push attempt (`ProfilesApplied: 0 of 4`) was denied with `0x80070005` (Access denied), consistent with residual client-side artefacts (certs/registration) from the legacy enrolment still occupying the management channel. Azure AD join, IntuneP1/Autopilot licensing, and network connectivity were all confirmed healthy — not contributing factors.

**Exact action taken:**
1. Identified the stale device record — Intune `Devices > All devices` (enrolment type: legacy manual, dated 2023‑11‑04) + corresponding Entra ID `Devices` object.
2. Deleted (not Retire — device wasn't reliably checking in) the stale Intune device record.
3. Deleted the lingering Entra ID device object (didn't auto-cascade from step 2).
4. Client-side: disconnected the old work account (`Settings > Accounts > Access work or school > Disconnect`); confirmed removal of `HKLM\SOFTWARE\Microsoft\Enrollments\<old GUID>`, the associated scheduled task under `Microsoft\Windows\EnterpriseMgmt\<old GUID>`, and any orphaned MDM cert in `certlm.msc` (Personal store). Full reset used where device wasn't cleanly reachable.
5. Re-triggered Autopilot enrolment from OOBE.

**Config detail:** `EnrolmentSource: Legacy manual MDM enrolment`, enrolment date `2023-11-04`, `ErrorCode: 0x80180014`, `LastError: 0x80070005`, `ProfilesApplied: 0 of 4`, `AzureADJoined: Yes`, `IntuneP1License: Yes`, `AutopilotLicense: Yes`, `Network: healthy, no proxy`.

**Verification step:** ESP completed with no errors; Intune `Devices > All devices` shows a single record with today's enrolment date and enrolment type = **Windows Autopilot** (not legacy manual); `Devices > Enrollment > Windows Enrollment > Devices` shows deployment status **Successful**; on-device `dsregcmd /status` shows `AzureAdJoined: YES` with MDM URL populated; assigned compliance policy now evaluates to Compliant/In grace period instead of "Not evaluated," confirming the 0/4 profile symptom is resolved end-to-end.

**Preventive action needed:** Add a mandatory pre-migration gate — bulk-filter Intune `Devices > All devices` by enrolment type = legacy/manual, cross-reference against the Autopilot migration schedule, and retire matching stale records before the device is queued (admin-center only, no device access required). Tag `0x80180014`-class failures distinctly in enrolment failure reporting so they route to a stale-enrolment cleanup queue instead of generic enrolment troubleshooting. Optional: discovery script against `HKLM\SOFTWARE\Microsoft\Enrollments` for pre-migration devices still reachable, to flag stale GUIDs ahead of the reset.
