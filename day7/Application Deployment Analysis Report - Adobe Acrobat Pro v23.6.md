# Application Deployment Analysis Report

| Field | Value |
|---|---|
| Title | Application Deployment Analysis Report — Adobe Acrobat Pro v23.6 |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | DWP Endpoint Engineer (Senior Intune/DWP, L2/L3 support analysis) |
| Reviewed | Self |
| Status | Draft |

> **Note on data handling:** This report analyzes only the log excerpt supplied by the requester — no tenant names, device identifiers, or credentials are present or required. Safe for use per the Personal AI Usage Charter.

---

## Application Information
- **Application Name:** Adobe Acrobat Pro v23.6
- **Package Type:** Win32 app (.intunewin) — `AdobeAcrobatPro.intunewin`
- **Install Context:** SYSTEM
- **Install Command:** `msiexec /i AcrobatPro.msi /quiet`

---

## Executive Summary
The Win32 app deployment of Adobe Acrobat Pro v23.6 failed on both the initial attempt and the first automatic retry, in each case with MSI return code **1603** (generic fatal installation error). Independently of the installer failure, the configured detection rule checks a registry path for **Adobe Acrobat Reader** (`HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0`) rather than Acrobat **Pro** — a product/detection mismatch that would cause Intune to report the app as "Not detected" even if the MSI had installed successfully. Two independent problems are therefore visible in the log: an installer-level failure (cause not yet determinable from this evidence alone) and a detection-logic defect (confirmed by direct comparison of product name vs. registry path). Both must be addressed; fixing only one will not result in a compliant "Installed" state.

---

## Deployment Timeline

| Timestamp | Component | Event | Outcome |
|---|---|---|---|
| 2024-03-15 10:01:00 | AgentExecutor | Starting app install: Adobe Acrobat Pro v23.6 | Initiated |
| 2024-03-15 10:01:01 | AppInstaller | Install context: SYSTEM | Informational |
| 2024-03-15 10:01:02 | AppInstaller | Package: `AdobeAcrobatPro.intunewin` | Informational |
| 2024-03-15 10:01:03 | AppInstaller | Install command: `msiexec /i AcrobatPro.msi /quiet` | Executed |
| 2024-03-15 10:01:44 | AppInstaller | Return code: 1603 | Failure (41 sec install runtime) |
| 2024-03-15 10:01:44 | AppInstaller | Install failed. Return code 1603 | Failed |
| 2024-03-15 10:01:45 | DetectionRule | Running detection: registry check | Initiated |
| 2024-03-15 10:01:45 | DetectionRule | Key: `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` | Informational |
| 2024-03-15 10:01:45 | DetectionRule | Value: not found | Not found |
| 2024-03-15 10:01:46 | DetectionRule | Detection result: Not detected | Not detected |
| 2024-03-15 10:01:47 | AgentExecutor | App install result: Failed | Failed |
| 2024-03-15 10:01:47 | AgentExecutor | Retry scheduled: 60 minutes | Scheduled |
| 2024-03-15 11:01:47 | AgentExecutor | Retry attempt 1: Adobe Acrobat Pro v23.6 | Initiated |
| 2024-03-15 11:01:48 | AppInstaller | Install command: `msiexec /i AcrobatPro.msi /quiet` | Executed |
| 2024-03-15 11:02:31 | AppInstaller | Return code: 1603 | Failure (43 sec install runtime) |
| 2024-03-15 11:02:32 | AgentExecutor | Retry 1 failed. Next retry: 60 minutes | Scheduled for further retry |

---

## Confirmed Findings
Facts directly observed in the log, with no interpretation:

- The app was installed via the Win32 app channel (`.intunewin`), in **SYSTEM** context, using `msiexec /i AcrobatPro.msi /quiet`.
- The initial install attempt ran for **41 seconds** (10:01:03 → 10:01:44) before returning code **1603**.
- The detection rule that ran immediately afterward is a **registry existence/value check** against `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0`, and the value was **not found**.
- The detection result was **"Not detected"**.
- The Intune Management Extension scheduled and executed exactly **one retry**, 60 minutes after the first failure, using the **identical install command**.
- The retry ran for **43 seconds** (11:01:48 → 11:02:31) and returned the **same code, 1603**.
- A second retry was scheduled after the first retry's failure; no further log entries are provided beyond that point.
- No entries in the supplied log show MSI verbose output, Windows Installer subsystem errors, pending-reboot state, disk space, permissions errors, or any other diagnostic detail beyond the bare return code.

---

## Installation Analysis

**Installer execution:** The install command used (`msiexec /i AcrobatPro.msi /quiet`) is a standard silent MSI invocation with no logging switch (e.g. `/l*v`) attached, and no `/norestart` or other qualifiers are present. The command executed and ran to completion (it did not hang or time out) in both attempts, producing a definitive Windows Installer return code rather than an Intune-side timeout/agent error — this indicates the **installer engine itself is being invoked correctly**; the failure is occurring inside the MSI's own execution.

**Return code 1603:** MSI error 1603 is a **generic, non-specific fatal error during execution of the installation package**. Per the analysis guidelines, 1603 is a symptom, not a root cause — it is Windows Installer's catch-all for "something inside a custom action, prerequisite check, or file/registry operation failed," and by itself does not indicate *which* underlying condition triggered it. Determining the actual cause requires MSI verbose logging (see "Additional Logs Required" below), which is not present in this excerpt.

**Installation behavior:** Both attempts show near-identical execution duration (41s and 43s) and an identical return code, suggesting the failure is **deterministic and repeatable** under the current device/environment state, rather than a transient/timing-related fault. A transient issue (e.g. a one-off lock or race condition) would more often show variable duration or an intermittent code; a fixed, repeated code with similar timing is more consistent with a persistent blocking condition (e.g. a conflicting existing installation, an unmet prerequisite, or a permissions/environment issue that doesn't change between attempts).

**Retry attempts:** Only one retry is shown, executed automatically 60 minutes after the first failure, using the **exact same install command with no modification**. Because nothing about the environment or command changed between attempts, and the underlying condition causing 1603 was not addressed, the retry failing identically is the expected outcome, not a new data point — it confirms the fault is persistent rather than transient, but does not add diagnostic detail beyond that confirmation.

---

## Detection Rule Analysis

- **Detection method used:** Registry-based detection (key/value existence and presumably version match, though only existence is shown failing here).
- **Registry path checked:** `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0`.
- **Detection result:** Not found → "Not detected."
- **Alignment with expected installation outcome:** This is the most significant structural defect visible in the log, **independent of the 1603 failure**. The application being deployed is **Adobe Acrobat Pro v23.6**, but the detection rule targets a registry path for **Adobe Acrobat Reader**, version **23.0** — a different product, and a different version number, from what is being installed. Acrobat Pro and Acrobat Reader are distinct Adobe products that install to different registry locations under normal circumstances. Even in a scenario where the MSI installed successfully, this detection rule would very likely still report "Not detected," because it is not inspecting the location Acrobat **Pro** actually writes to. This is a **confirmed logic mismatch** based on product-name comparison alone, not an inference — the detection target does not match the declared application.

---

## Root Cause Assessment

### Primary Probable Cause
**Detection rule targets the wrong product (Acrobat Reader path/version instead of Acrobat Pro), independent of and in addition to an installer-level failure (MSI 1603) whose specific trigger is not identifiable from this log alone.**
- Confidence: **High** (for the detection mismatch, directly confirmed by comparing the declared app name to the registry path/version in the log) / **Low** (for the specific underlying trigger of the 1603 failure itself, since no verbose MSI detail is available).

### Secondary Possible Causes
| Possible cause | Applies to | Confidence |
|---|---|---|
| Existing conflicting product installed (e.g. a prior Acrobat Reader or Acrobat Pro version, or another PDF handler holding a shared component/service) causing the custom action to fail | 1603 failure | Medium — consistent with a deterministic, repeatable 1603, but no evidence (e.g. existing-products list) is present to confirm |
| Unmet installation prerequisite (e.g. required Visual C++ runtime, .NET version, or Windows feature not present) | 1603 failure | Low–Medium — plausible generic 1603 trigger, not confirmed or excluded by available data |
| Pending reboot on the device blocking MSI execution | 1603 failure | Low–Medium — a common 1603 trigger; the log shows no reboot-pending indicator either way |
| Insufficient permissions for the SYSTEM install context to complete a specific custom action (e.g. writing to a protected path or registry hive) | 1603 failure | Low — SYSTEM context normally has broad rights, making this less likely than other causes, but not excluded |
| Corrupted or incomplete installer package (`AcrobatPro.msi` or the `.intunewin` wrapper) | 1603 failure | Low — package integrity is not verifiable from this log |
| Command-line/switch issue with `msiexec /i AcrobatPro.msi /quiet` | 1603 failure | Low — the command syntax itself is valid MSI syntax; unlikely to be the primary driver, though absence of a log-capture switch limits confirmation either way |

---

## Technical Impact

- **Application deployment:** The app has failed to install on this device across two attempts and will continue retrying on the existing 60-minute schedule without remediation, consuming device/network resources without progress.
- **User experience:** The end user does not have Acrobat Pro available for use; if they were expecting the tool for business tasks, this is a direct productivity impact, with no visible end-user-facing error surfaced in this log (silent install gives no UI feedback).
- **Compliance state:** The device will report as **non-compliant / app not installed** for this assignment, since detection independently confirms "Not detected" — and would continue to do so via the reporting pipeline even if the 1603 issue were fixed, until the detection rule itself is corrected.
- **Intune reporting:** Admins viewing **Device install status** will see this device as "Failed," and — due to the detection mismatch — even a successful reinstall attempt risks still showing "Failed" or "Not detected" in reporting, which would misleadingly suggest a persistent installer problem when the actual remaining fault is the detection rule.

---

## Recommended Remediation

### Immediate Actions
1. Correct the detection rule to target the actual registry path and value written by **Acrobat Pro v23.6** (not Acrobat Reader 23.0) — verify the real key/value on a clean reference device where the Pro MSI installs successfully outside of Intune, before re-publishing the rule.
2. Re-run the install manually (or via a test device) with MSI verbose logging enabled (e.g. `msiexec /i AcrobatPro.msi /quiet /l*v C:\Windows\Temp\AcrobatPro_install.log`) to capture the actual custom-action/error detail behind return code 1603.
3. Check the target device(s) for a pending reboot state and for any existing Acrobat Reader/Pro installations or conflicting PDF-handler software before the next retry.

### Validation Steps
1. Confirm the corrected detection rule evaluates **true** on a device where Acrobat Pro v23.6 is known to be installed, and **false** on a clean device — do not assume, test both states explicitly.
2. Re-attempt the install on an isolated test device with verbose MSI logging active, and confirm a **0** (or other documented success) return code before resuming broader assignment.
3. Confirm the corrected detection rule and successful install combination produces an **"Installed"** status in Intune's Device install status report, not just a locally-observed successful install.

### Long-Term Preventive Actions
1. Require MSI verbose logging (or equivalent) by default for all new Win32 app packages during initial UAT/pilot testing, so return-code-only failures like this are diagnosable without needing a second data-gathering round.
2. Add a packaging review checklist step that explicitly cross-checks the **application name in the catalog entry against the registry path/version used in the detection rule**, to catch product/version mismatches (as seen here) before an app reaches any pilot ring.
3. Where feasible, prefer **MSI product code** detection over a hand-typed registry path/version for MSI-based packages, since Intune can read the product code directly from the package and this removes the class of error seen in this incident.

---

## Additional Logs Required

The following are needed for a definitive RCA beyond the probable-cause assessment above:

- **IntuneManagementExtension.log** — to confirm the full Win32 app processing sequence (download, extraction, execution invocation) around the timestamps in this excerpt, and any IME-side errors not captured in this summarized log.
- **AppWorkload.log** — to cross-check app workload processing and confirm whether any errors occurred outside the install-command execution itself.
- **MSI verbose installation log** (`msiexec ... /l*v <path>`) — the single most important missing artifact; required to identify which custom action, prerequisite check, or file/registry operation actually caused return code 1603.
- **Event Viewer entries** — specifically the **Application** and **MsiInstaller** logs around 10:01:03–10:01:44 and 11:01:48–11:02:31, which typically record the specific Windows Installer error text associated with a 1603.
- **Registry validation results** — a manual dump/export of `HKLM\SOFTWARE\Adobe\` on the affected device, to confirm exactly where (if anywhere) Acrobat Pro v23.6 actually writes its version key, to correctly rebuild the detection rule.
- **Company Portal logs** (if applicable) — only relevant if the deployment is user-initiated/visible rather than purely silent SYSTEM-context; would confirm whether the end user saw any error surfaced locally.

---

## Final Conclusion
The deployment of Adobe Acrobat Pro v23.6 failed on both the initial attempt and its automatic retry with an identical MSI return code (1603), a generic fatal installer error whose specific underlying trigger cannot be determined from the available log alone — the repeatable, near-identical failure signature across both attempts indicates a persistent, non-transient condition (most plausibly a conflicting product, unmet prerequisite, pending reboot, or similar) rather than a one-off timing issue, but confirming which of these applies requires MSI verbose logging that was not provided. Separately and with high confidence, the configured detection rule checks a registry path belonging to **Adobe Acrobat Reader v23.0**, not **Acrobat Pro v23.6** — a product/version mismatch that would independently cause Intune to report "Not detected" even if the installer issue were resolved. The retry failed for the same reason the original attempt failed: no change was made to the install command or environment between attempts, so the same persistent blocking condition reproduced the same result. Both the installer-level fault and the detection-rule mismatch must be corrected — and independently validated — before this deployment can be expected to report as compliant in Intune.
