# Root Cause Analysis (RCA)

## Document Information
- **Incident / Issue Title:** Adobe Acrobat Pro v23.6 Win32 App Deployment Failure (MSI 1603) with Detection Rule Mismatch
- **Application Name:** Adobe Acrobat Pro v23.6
- **Environment:** Intune-managed Windows endpoint(s), Win32 app (.intunewin) deployment, SYSTEM install context
- **Analysis Date:** 11/08/2026
- **RCA Version:** 1.0
- **Prepared By:** DWP Endpoint Engineer

> **Note on data handling:** This RCA is derived solely from the previously produced [Application Deployment Analysis Report - Adobe Acrobat Pro v23.6.md](Application%20Deployment%20Analysis%20Report%20-%20Adobe%20Acrobat%20Pro%20v23.6.md) — no tenant names, device identifiers, or credentials are present or required. Safe for use per the Personal AI Usage Charter.

---

## Executive Summary

Deployment of Adobe Acrobat Pro v23.6 to a managed endpoint failed on its initial attempt and on its single automatic retry, both times with Windows Installer error code 1603. Independently, the app's Intune detection rule was found to reference **Adobe Acrobat Reader**, not Acrobat Pro — a confirmed configuration defect that would have prevented the app from ever reporting as "Installed" even had the installer succeeded. Impact is currently limited to the affected device(s) not receiving the application, showing as Failed/non-compliant in Intune. Remediation requires two separate fixes: root-causing the 1603 installer failure (which needs additional logs not yet collected) and correcting the detection rule to target Acrobat Pro's actual registry location. Neither fix alone will resolve the reported failure.

---

## Issue Description

- **Expected behavior:** Adobe Acrobat Pro v23.6 installs silently via `msiexec /i AcrobatPro.msi /quiet` in SYSTEM context, and the Intune detection rule subsequently confirms the install by finding the correct registry value, marking the device "Installed."
- **Actual behavior:** The install command executed but returned MSI code 1603 on both the initial attempt and the automatic retry one hour later. The subsequent detection check queried a registry path for Acrobat Reader, not Acrobat Pro, and reported "Not detected."
- **Failure symptoms observed:** Two consecutive install failures with an identical return code and similar execution duration (~41–43 seconds); detection rule referencing the wrong product/registry path; no further retries evidenced beyond the one shown.

---

## Evidence Collected

Evidence below is drawn only from what is directly stated in the source Analysis Report.

### Deployment Evidence
- App: Adobe Acrobat Pro v23.6, packaged as `AdobeAcrobatPro.intunewin`, installed in **SYSTEM** context.
- Install command: `msiexec /i AcrobatPro.msi /quiet`.

### Installation Evidence
- Initial attempt: executed 10:01:03, returned code **1603** at 10:01:44 (41 seconds runtime).
- Retry attempt 1: executed 11:01:48, returned code **1603** at 11:02:31 (43 seconds runtime).
- No MSI verbose logging switch was used in either invocation.

### Detection Evidence
- Detection method: registry existence/value check.
- Registry path checked: `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` (Acrobat **Reader**, version 23.0).
- Result: value not found → "Not detected."

### Retry Evidence
- Exactly one retry was scheduled and executed, 60 minutes after the initial failure.
- The retry used the **identical, unmodified install command** with no evidence of any remediation applied between attempts.
- The retry result matched the initial failure exactly (same return code).

---

## Root Cause Determination

### Technical Root Cause

The installer failed with MSI return code **1603** on both attempts. 1603 is a generic, non-specific "fatal error during installation" code — it indicates an internal installer failure but does not itself identify which custom action, prerequisite check, or file/registry operation caused it. No MSI verbose log, Event Viewer entry, or other diagnostic detail beyond the bare return code is available in the evidence collected. **The exact installer failure trigger cannot be conclusively determined from the available evidence.**

Based on the repeatable, near-identical failure signature across both attempts (consistent duration, identical code, no environmental change between attempts), the most probable contributing conditions — none confirmed — are: a conflicting existing product installation, an unmet installation prerequisite, a pending reboot, or a permissions/environment condition. These remain **Probable Causes**, not confirmed findings.

#### Confidence Level
**Low** — the 1603 code confirms an installer-level failure occurred, but with no verbose MSI log or Event Viewer data available, the specific underlying trigger is unverified and cannot be elevated beyond a probable-cause assessment.

---

### Configuration Root Cause

The detection rule configured for this app performs a registry check against `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0`. The application being deployed is **Adobe Acrobat Pro v23.6** — a distinct product from Acrobat Reader, expected to write to a different registry location and version value. Comparing the declared application name against the configured detection path shows a direct, verifiable mismatch.

**This is confirmed as a configuration defect**, not a probable cause: the detection rule targets the wrong product's registry path/version, independent of the installer's outcome. Even a fully successful Acrobat Pro installation would not satisfy this detection rule as configured, because it is not inspecting a path Acrobat Pro writes to.

#### Confidence Level
**High** — this conclusion is based on direct comparison of the declared application name against the literal registry path recorded in the detection rule, requiring no inference beyond that comparison.

---

## Contributing Factors

- **Repeated execution of an identical install command:** the retry made no change to the install command or environment, so it could not have produced a different outcome than the initial failure.
- **Missing MSI verbose logging:** no `/l*v` (or equivalent) logging switch was included in the install command, removing the primary diagnostic source needed to root-cause a 1603 failure.
- **Detection-rule design issue:** a registry path/version referencing the wrong product (Acrobat Reader instead of Acrobat Pro) was published and used for live detection.
- **Insufficient deployment validation:** no evidence of pre-deployment validation confirming the detection rule matches the packaged application prior to assignment.
- **Lack of pre-production packaging review:** a review step cross-checking application name against detection-rule target would likely have caught the Reader/Pro mismatch before deployment.

---

## Why the Retry Failed

The retry failed because it re-executed the exact same install command, in the same environment, with no remediation of the condition that caused the original 1603 failure — there is no evidence any corrective action, prerequisite fix, reboot, or conflicting-software removal occurred between the initial failure (10:01:44) and the retry (11:01:48). Automatic retry mechanisms re-run the deployment; they do not diagnose or remediate the underlying cause. Since the environmental conditions were unchanged, the retry reproducing the identical result (same return code, similar duration) is the expected outcome rather than a new or unexpected finding.

---

## Impact Assessment

### User Impact
The end user does not have Acrobat Pro available. The install runs silently in SYSTEM context, so no error was surfaced to the user directly in the evidence reviewed.

### Business Impact
Any business process dependent on Acrobat Pro being present on the affected device(s) is unfulfilled until remediation; deployment failure at this stage also indicates a risk that other, currently unassigned devices in a wider rollout would fail identically if the same package/detection rule were used unchanged.

### Intune Compliance Impact
The device reports as **non-compliant / Failed** for this app assignment. Because the detection rule is independently misconfigured, correcting only the installer issue would still leave the device reporting "Not detected" until the detection rule itself is fixed.

### Reporting Impact
Admins reviewing Intune's Device install status will see "Failed," and — due to the detection mismatch — could misattribute a future re-install failure to a persistent installer problem when the actual remaining fault is the detection rule, unless both issues are tracked and closed separately.

---

## Corrective Actions

### Immediate Corrective Actions
1. Enable MSI verbose logging (e.g. `msiexec /i AcrobatPro.msi /quiet /l*v <path>`) on the next attempt to capture the specific cause of return code 1603.
2. Collect Intune (`IntuneManagementExtension.log`, `AppWorkload.log`) and Windows Installer diagnostics (Event Viewer `Application` / `MsiInstaller` logs) for the affected device.
3. Validate the affected device for existing/conflicting Acrobat Reader or Acrobat Pro installations, and check for a pending reboot state.
4. Correct the detection rule to reference the actual registry path and value written by Acrobat Pro v23.6, verified against a known-good reference install.

### Permanent Corrective Actions
1. Improve packaging standards to require verbose/diagnostic logging by default for all new Win32 app install commands during initial testing.
2. Introduce a formal detection-rule validation process: confirm the rule evaluates true on a known-installed device and false on a clean device before publishing.
3. Require pilot/UAT deployment testing on a small device sample before any wider assignment.
4. Require packaging peer-review that explicitly cross-checks application name against detection-rule target (registry path/version, MSI product code, or file path).
5. Prefer MSI product-code detection over hand-typed registry paths where the package is a native MSI, since Intune can read the product code directly from the package.

---

## Lessons Learned

- **What worked:** The Intune retry mechanism functioned as designed, and both install and detection events were logged with clear timestamps, enabling this analysis.
- **What failed:** No diagnostic logging was enabled at deployment time, and the detection rule was not validated against the correct product before publishing.
- **What could have identified the issue earlier:** A pre-production packaging review comparing the application name to the detection-rule's registry path would have caught the Reader/Pro mismatch before any device was assigned; enabling verbose MSI logging from the outset would have shortened the diagnostic cycle for the 1603 failure.

---

## RCA Statement

Based on the available evidence, the deployment failure was caused by a persistent MSI installation failure returning code 1603. The specific installer-level trigger cannot be conclusively determined due to absence of MSI verbose logs. Additionally, a confirmed configuration defect was identified wherein the detection rule targeted Adobe Acrobat Reader registry locations instead of Adobe Acrobat Pro. This detection-rule mismatch would have prevented successful application detection even if installation had succeeded. The retry attempt failed because the deployment retried using the same installation command and environmental conditions without remediation of the underlying issue.

---

## Confidence Assessment

| RCA Area | Confidence | Justification |
|---|---|---|
| Installer Failure RCA | Low | MSI 1603 confirms a fatal installer-level failure occurred on both attempts, but no verbose MSI log, Event Viewer detail, or other diagnostic beyond the return code is available to identify the specific trigger. |
| Detection Rule RCA | High | Directly confirmed by comparing the declared application name (Acrobat Pro v23.6) against the literal registry path/version recorded in the detection rule (Acrobat Reader 23.0) — no inference required. |
| Overall RCA | Medium | The configuration defect is confirmed with high confidence, but the RCA cannot be closed as fully "Confirmed Root Cause" until the installer-level trigger is also verified with additional evidence. |

---

## Required Evidence for Final Confirmation

To convert this RCA from Probable Cause to Confirmed Root Cause for the installer-level failure, the following additional artifacts are required:

- MSI verbose installation log (`msiexec ... /l*v <path>`) for both the original and retry attempts.
- `IntuneManagementExtension.log` covering the full processing sequence around both attempts.
- `AppWorkload.log` for the same time windows.
- Event Viewer entries (`Application` and `MsiInstaller` logs) for the affected device.
- Device registry validation — an export of `HKLM\SOFTWARE\Adobe\` confirming where Acrobat Pro v23.6 actually writes its version key.
- Installed application inventory for the affected device, to check for conflicting or prior Acrobat installations.
