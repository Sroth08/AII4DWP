# Known-error Record - Autopilot Enrolment Failure (Legacy MDM Conflict)

Symptom: Windows Autopilot enrolment fails with `EnrollmentState: Failed` and `ErrorCode: 0x80180014`; 0 of 4 configuration profiles apply, with `LastError: 0x80070005` (Access denied).
Cause: The device retained an active legacy manual MDM enrolment (dated 2023‑11‑04) that was never removed before the Autopilot migration attempt; residual client-side artefacts from that legacy enrolment blocked the subsequent policy push.
Scope: Any device with a pre-existing legacy manual MDM enrolment that is queued for Autopilot migration. Azure AD join, Intune P1/Autopilot licensing, and network connectivity are confirmed healthy and unaffected on impacted devices.
Workaround: Retire/delete the stale device record in Intune and the corresponding Entra ID device object, disconnect or reset the legacy enrolment on the device, then re-trigger Autopilot enrolment.
Permanent fix: Add a mandatory pre-migration audit gate that confirms zero pre-existing MDM enrolments for a device's hardware hash before it is queued for Autopilot, so legacy enrolments are retired ahead of the migration wave instead of at enrolment time.
How to spot it: `ErrorCode 0x80180014` ("device already enrolled in MDM") paired with `ProfilesApplied: 0 of 4` and `LastError: 0x80070005`; `MDMEnrolled: Yes` with an `EnrolmentSource` of legacy manual MDM enrolment predating the current migration attempt.
