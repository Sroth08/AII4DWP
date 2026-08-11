# Runbook: Autopilot Enrolment Failure (Legacy MDM Conflict)

| Field | Value |
|---|---|
| Title | Runbook: Autopilot Enrolment Failure (Legacy MDM Conflict) |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | Sourav Roth |
| Reviewed | Self |
| Status | Draft |
| Change | Initial version from RCA |

## Purpose
Restore a device to a successful Windows Autopilot enrolment when it fails with `0x80180014` ("already enrolled in MDM") and `0x80070005` (Access denied) on policy push, by removing the stale legacy MDM enrolment blocking it.

## Applies To
- Symptom: `EnrollmentState: Failed`, `ErrorCode: 0x80180014`; `ProfilesApplied: 0 of 4`, `LastError: 0x80070005`
- Trigger condition: Device previously had a legacy manual MDM enrolment that was never removed before an Autopilot (re-)enrolment attempt

## Source Incident
Based on RCA: [Detailed RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Detailed%20RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md) — root cause was a stale legacy manual MDM enrolment (dated 2023‑11‑04) never removed before the device entered the Autopilot migration flow, blocking the new enrolment and causing the subsequent policy push to be denied.

---

## Prerequisites

**Access rights:**
- Intune admin center role with permission to delete/retire devices (e.g., **Intune Administrator**, or custom role with "Delete devices") — **elevated permission, confirm before starting**
- Entra ID (Azure AD) role with permission to delete device objects (e.g., **Cloud Device Administrator**) — **elevated permission, confirm before starting**
- Local administrator rights on the affected device — **elevated permission, confirm before starting**

**Tools:**
- Intune admin center (`intune.microsoft.com`) access
- Entra ID admin center (`entra.microsoft.com`) access
- Remote access tool to reach the device (Remote Help, Quick Assist, RDP) or physical access to the device
- Registry Editor (`regedit.exe`) and Certificate Manager (`certlm.msc`) on the device
- A safe storage location (USB, network share, or ticket attachment) to save backup exports taken during this runbook

**System information needed:**
- Device name and/or serial number of the affected device
- Confirmation of the legacy enrolment date from the diagnostic export (2023‑11‑04 in the source incident)
- Ticket/incident number for this event

---

## Procedure

1. **Open the device record in Intune.** Go to `https://intune.microsoft.com`. In the left navigation pane, click **Devices**. Under the "Manage devices" heading, click **All devices**. In the search box at the top of the grid, type the device name or serial number and press Enter.
   - *Success looks like:* Exactly one row appears in the grid. Click it to open the device blade — the **Enrollment type** field (right-hand summary panel, or the **Properties** tab) reads "Legacy manual" (or similar non-Autopilot value), and **Enrolled date** matches the diagnostic export (2023‑11‑04).

2. **Record the device's Entra ID Object ID.** With the device blade still open from step 1, click the **Properties** tab in the left-hand menu of the blade. In the "Device information" section, locate the field labelled **Entra AD Device ID** and copy its GUID value into your ticket notes.
   - *Success looks like:* You have a GUID string (format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) pasted into your ticket notes, ready for step 4.

3. **Delete the stale device record in Intune.** From the device's **Overview** tab (top of the blade), click **Delete** in the command bar at the top. In the confirmation dialog, click **Yes**. **Elevated permission required: Intune Administrator (or equivalent role with "Delete devices").**
   - *Success looks like:* You are returned to the **All devices** list and the device row is no longer present (allow up to 5 minutes; refresh the grid with the **Refresh** button in the command bar if it still shows).

4. **Check Entra ID for the corresponding device object.** Go to `https://entra.microsoft.com`. In the left navigation pane, click **Identity**, then **Devices**, then **All devices**. In the search box above the grid, paste the Object ID GUID recorded in step 2 and press Enter.
   - *Success looks like:* The grid returns either zero rows (already auto-cleaned — skip to step 6) or exactly one row matching that Object ID.

5. **If found, delete the stale Entra ID device object.** Tick the checkbox on the left of the row found in step 4, then click **Delete** in the command bar at the top of the grid, and click **Yes** in the confirmation dialog. **Elevated permission required: Cloud Device Administrator (or equivalent Entra ID role).**
   - *Success looks like:* Refresh the **All devices** grid (command bar > **Refresh**) — the row is no longer present.

6. **Connect to the affected device.** In Intune, from the device blade opened in step 1 (if not yet deleted, open it again via **All devices**), click **New remote assistance session** in the command bar to launch Remote Help. If Remote Help is not licensed/available, use RDP or Quick Assist (search "Quick Assist" in the Windows Start menu on your own machine, click **Assist another person**, and have the user read out the code shown on their screen).
   - *Success looks like:* A remote session window opens showing the user's live desktop, and you can move the mouse/type on their screen.

7. **Open the work account settings on the device.** On the remote/local session, click the Windows **Start** button, type `Access work or school`, and press Enter to open that Settings page.
   - *Success looks like:* The page lists at least one entry under "Add a work or school account" showing the old organisation account tied to the legacy enrolment.

8. **Disconnect the old work account.** On the same page, click the old account entry to expand it, click **Disconnect**, then click **Yes** to confirm.
   - *Success looks like:* The page refreshes and that account entry is no longer listed under "Add a work or school account."

9. **Open Registry Editor and locate the legacy enrolment key.** On the remote/local session, click **Start**, type `regedit`, right-click **Registry Editor** and choose **Run as administrator**. In the address bar at the top of the Registry Editor window, paste `HKLM\SOFTWARE\Microsoft\Enrollments` and press Enter. **Elevated permission required: local administrator.**
   - *Success looks like:* The left pane expands to show one or more GUID-named subkeys under `Enrollments`. Click each one and check the `EnrollmentType` and `ProviderID` values in the right pane until you find the one matching the legacy manual enrolment (cross-check any date-related value against 2023‑11‑04).

10. **Back up the legacy enrolment subkey before deleting it.** Right-click the GUID subkey identified in step 9, choose **Export**, in the "Export Registry File" dialog navigate to your safe storage location, name the file `Enrollments_<GUID>_backup.reg` (replace `<GUID>` with the actual key name), and click **Save**.
    - *Success looks like:* Using File Explorer, browse to the saved location and confirm `Enrollments_<GUID>_backup.reg` exists with a file size greater than 0 KB.

11. **Delete the legacy enrolment subkey.** Right-click the same subkey identified in step 9, choose **Delete**, and click **Yes** to confirm. **Elevated permission required: local administrator.**
    - *Success looks like:* The GUID subkey no longer appears in the left pane under `HKLM\SOFTWARE\Microsoft\Enrollments` (press F5 to refresh if unsure).

12. **Remove the matching scheduled task.** Click **Start**, type `Task Scheduler`, press Enter. In the left pane, expand **Task Scheduler Library > Microsoft > Windows**, then click **EnterpriseMgmt**. Right-click the folder matching the same GUID from step 9 and choose **Delete**, then click **Yes**. **Elevated permission required: local administrator.**
    - *Success looks like:* The folder matching that GUID no longer appears under **EnterpriseMgmt** in the left pane (press F5 to refresh if unsure).

13. **Back up the matching certificate before deleting it.** Click **Start**, type `certlm.msc`, press Enter. In the left pane, expand **Personal**, then click **Certificates**. In the middle pane, find the certificate whose **Issued To** or **Issued By** column references the legacy enrolment GUID (double-click a certificate and check the **Details** tab if the column isn't shown). Right-click it, choose **All Tasks > Export**, click **Next**, select **Yes, export the private key**, click **Next** twice, set and confirm a password, click **Next**, browse to your safe storage location, name the file `<GUID>_cert_backup.pfx`, click **Next**, then **Finish**. **Elevated permission required: local administrator.**
    - *Success looks like:* A dialog confirms "The export was successful," and File Explorer shows `<GUID>_cert_backup.pfx` at the saved location with a file size greater than 0 KB.

14. **Delete the matching certificate.** In the same `certlm.msc` **Personal > Certificates** view, right-click the certificate identified in step 13, choose **Delete**, and click **Yes** to confirm. **Elevated permission required: local administrator.**
    - *Success looks like:* The certificate no longer appears in the middle pane under **Personal > Certificates** (press F5 to refresh if unsure).

15. **If steps 6–14 cannot be completed cleanly** (device unreachable, artefacts ambiguous, or any step fails), perform a full reset instead: Click **Start**, open **Settings > System > Recovery**, and under "Reset this PC" click **Reset PC**, then choose **Remove everything**, then **Cloud download** (or **Local reinstall** if no internet), and follow the prompts to **Reset**. **Elevated permission required: local administrator. Before clicking Reset, confirm with the user that their files are synced to OneDrive — this step is destructive and not reversible by this runbook.**
    - *Success looks like:* The device reboots multiple times and lands on the blue Windows **OOBE "Let's start with region"** setup screen, with no user files, desktop icons, or installed apps remaining.

16. **Re-trigger Autopilot enrolment.** If the device is at OOBE (post-reset), proceed through the on-screen prompts and connect to Wi‑Fi/Ethernet when asked — Autopilot will take over automatically. If the device is already at the Windows desktop instead, open **Settings > Accounts > Access work or school**, click **+ Add a work or school account**, then at the bottom of the sign-in box click **Alternate actions > Enroll only in device management**, and sign in with the user's credentials.
    - *Success looks like:* A full-screen blue **"Setting up your device for work"** page appears (the Enrollment Status Page), listing "Device setup" and "Account setup" as in-progress stages with spinning progress indicators.

17. **Wait for the Enrollment Status Page to complete.** Do not close the session or let the device sleep; leave the ESP screen running undisturbed.
    - *Success looks like:* The ESP screen changes to **"All done!"** (or the device proceeds directly to the sign-in/desktop screen) with no red error text or error code displayed anywhere on the page.

---

## Verification

1. **Confirm a single, correctly-typed device record in Intune.** Go to `https://intune.microsoft.com` > **Devices** > **All devices** > search for the device name.
   - *Success looks like:* Exactly one row is returned, its **Enrolled date** column shows today's date, and opening the row's **Properties** tab shows **Enrollment type: Windows Autopilot** (not "Legacy manual").

2. **Confirm the Autopilot deployment status.** Go to **Devices** > left-hand menu **Enrollment** (under "Device onboarding") > **Windows Enrollment** > **Devices** tab, and search for the device by serial number.
   - *Success looks like:* The **Deployment status** column reads **Successful** for this device.

3. **Confirm Entra ID join state on the device.** On the device, open **Command Prompt** (Start > type `cmd` > Enter) and run `dsregcmd /status`.
   - *Success looks like:* The output under "Device State" shows `AzureAdJoined : YES`, and under "MDM Details" (or `TenantDetails`) a Management URL/MDM endpoint is populated (not blank/`NO`).

4. **Confirm compliance policy evaluation.** In Intune, go to **Devices** > **All devices** > open the device > click the **Device compliance** tab in the left-hand menu of the blade.
   - *Success looks like:* The relevant compliance policy row shows status **Compliant** or **In grace period** — not "Not evaluated" or a red error icon.

5. **Confirm no repeat MDM errors.** On the device, open **Settings > Accounts > Access work or school**, click the connected work account, click **Info**, scroll down and click **Create report** under "Diagnostic report," wait for it to generate, then click **Export** and open the resulting file.
   - *Success looks like:* Searching the exported report for `0x80180014` and `0x80070005` returns no matches with today's date/time.

6. **Confirm with the end user.** Ask the user (in person, by phone, or via the ticket) to sign in, open one line-of-business app, and confirm it works as expected.
   - *Success looks like:* The user replies confirming successful sign-in and normal app access — record this confirmation in the ticket before closing.

---

## Rollback
Use the specific rollback matching what went wrong — do not attempt generic troubleshooting.

1. **Wrong device object deleted in Entra ID (step 5), not the intended stale one:** Go to `entra.microsoft.com` > **Devices > Deleted devices**, search for the device by name, and click **Restore**. Verify your tenant's retention window (commonly up to 30 days) before relying on this — restore only works within that window.
2. **Wrong device record deleted in Intune (step 3):** Deleting an Intune device record only removes the management record — it does not wipe the device. Re-enrol the affected device via Company Portal or by re-running its Autopilot profile; no device data is lost from this action alone.
3. **Registry subkey or certificate deletion (steps 11/14) breaks enrolment further, or the wrong GUID was targeted:** Reimport the backups taken in steps 10 and 13 — double-click the saved `Enrollments_<GUID>_backup.reg` file to restore the registry subkey, and in `certlm.msc` > **Personal** > **All Tasks > Import**, select the saved `<GUID>_cert_backup.pfx` file (enter the password used at export) to restore the certificate. Then retry enrolment from step 16.
4. **"Reset this PC" (step 15) was performed and the user reports missing local data not backed up to OneDrive/cloud:** Do not make further changes to the device. Escalate immediately to the desktop support/data recovery team, referencing the ticket number — a local reset is not reversible from this runbook; any recovery depends on separate backup/imaging solutions outside this procedure.
5. **Conditional Access starts blocking a wider set of users after this runbook was applied to multiple devices:** Check whether the compliance policy's grace period was inadvertently altered — in Intune, go to **Devices > Compliance policies >** the assigned policy **> Actions for noncompliance**, and confirm the "Mark device noncompliant" schedule is still set to **7 days**; revert it if changed, and notify the incident channel immediately.

---

## Notes
- **Edge case:** A device may have more than one legacy enrolment GUID if it changed management methods multiple times over the years — repeat steps 9–14 for each additional GUID found before proceeding to step 15/16.
- **Warning:** Never delete a device record (steps 3 or 5) without first confirming its enrolment date/source in step 1 — deleting the wrong device is high risk; Intune has no undo for device record deletion (see Rollback #2), and Entra ID restore is time-limited (see Rollback #1).
- **Warning:** Confirm the user's files are synced to OneDrive/cloud storage before step 15 — this is the only destructive, non-reversible action in this runbook.
- **Related documents:** [Known-error Record - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Known-error%20Record%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md), [RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md), [Detailed RCA - Autopilot Enrolment Failure (Legacy MDM Conflict).md](Detailed%20RCA%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md), [End-User Communications - Autopilot Enrolment Failure (Legacy MDM Conflict).md](End-User%20Communications%20-%20Autopilot%20Enrolment%20Failure%20%28Legacy%20MDM%20Conflict%29.md) — use the pre-drafted end-user comms if this recurs across multiple devices.
- **Preventive follow-up:** If this runbook is being used repeatedly across a migration wave, escalate to have the pre-migration audit gate (see RCA Preventive Actions) implemented before continuing further waves, rather than repeating this per-device fix at scale.
