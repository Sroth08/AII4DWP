# Windows 11 Intune Compliance Policy — Security Baseline Mapping

| Field | Value |
|---|---|
| Title | Windows 11 Intune Compliance Policy — Security Baseline Mapping |
| Version | 1.0 |
| Date | 10/08/2026 |
| Author | DWP Endpoint Engineer |
| Reviewed | Self |
| Status | Draft |
| Scope | Devices > Compliance policies > Policies > Create policy > Platform: **Windows 10 and later** |

## Purpose
Translates 7 security baseline requirements into concrete Microsoft Intune Windows 10/11 compliance policy settings, with a single 7‑day grace period applied before enforcement (e.g., Conditional Access block).

> **Note on data handling:** This document contains no device identifiers, tenant names, or credentials — safe for use per the Personal AI Usage Charter.

---

## Requirement 1 — BitLocker must be enabled on the OS drive

| Field | Detail |
|---|---|
| Settings name | **Require BitLocker** (category: *Device Health*) |
| Value | **Require** |
| Effect | Device is marked non‑compliant unless the OS drive is encrypted with BitLocker and a valid recovery key has been escrowed. |
| False‑positive risk | Devices that were encrypted with BitLocker *before* Intune enrollment but never escrowed a recovery key to Azure AD/Entra ID can fail even though the drive is encrypted. Suspended protection (e.g., during a firmware/BIOS update) also flags as non‑compliant until resumed. Self-encrypting drives (SED/eDrive) misreported by hardware can also cause false negatives. |
| Recommendation | Push a BitLocker encryption profile (Endpoint security > Disk encryption) *alongside* the compliance policy so escrow happens automatically, rather than relying on pre-existing encryption. Confirm TPM 2.0 is present via the separate **Trusted Platform Module (TPM)** setting to avoid conflating TPM failures with BitLocker failures. |

---

## Requirement 2 — Secure Boot must be enabled

| Field | Detail |
|---|---|
| Settings name | **Require Secure Boot to be enabled on the device** (category: *Device Health*) |
| Value | **Require** |
| Effect | Device is marked non‑compliant if UEFI Secure Boot is disabled or the device is running in Legacy/CSM BIOS mode. |
| False‑positive risk | Older hardware still running Legacy BIOS, or devices where Secure Boot was disabled for third-party dual-boot/driver reasons, will flag as non-compliant even if otherwise healthy. Virtual machines (test/AVD golden images) built without Secure Boot enabled in the VM firmware also flag. |
| Recommendation | Audit hardware inventory for Legacy BIOS/CSM devices before enabling this as a blocking (vs. reporting-only) setting; remediate firmware settings first. For AVD/VM pools, ensure the VM generation/firmware template has Secure Boot enabled at deployment, not retrofitted. |

---

## Requirement 3 — Minimum OS build: N‑1 (10.0.22621.2861)

| Field | Detail |
|---|---|
| Settings name | **Minimum OS version** (category: *Device Properties*) |
| Value | **10.0.22621.2861** (full 4-part build string required — not just "22621.2861") |
| Effect | Device is marked non‑compliant if its installed Windows 11 build is older than 10.0.22621.2861. |
| False‑positive risk | Servicing/feature updates roll out in rings; devices in a later deferred update ring can be genuinely healthy and patched but simply haven't received the newest cumulative update yet, causing a wave of flags right after each Patch Tuesday. Devices with update installs pending a restart also show the old build until reboot. |
| Recommendation | Set the minimum build 1–2 patch levels *behind* the absolute latest (as already done here with N‑1) and align the compliance grace period with your update deployment ring timeline so devices aren't flagged mid-rollout. Cross-check against your Windows Update for Business deployment rings before raising this value. |

---

## Requirement 4 — Windows Defender real-time protection must be on

| Field | Detail |
|---|---|
| Settings name | **Real-time protection** (category: *System Security*, sub-group *Microsoft Defender Antimalware*) |
| Value | **Require** |
| Effect | Device is marked non‑compliant if Microsoft Defender Antivirus real-time protection is turned off (either by policy, user action, or third-party AV taking ownership). |
| False‑positive risk | Devices running a **third-party antivirus** (Defender enters passive mode) can be flagged even though they are protected, since Intune reads Defender's own state rather than the third-party AV's state. Brief real-time protection toggling during AV signature updates or scheduled full scans can also cause transient flags. |
| Recommendation | If third-party AV is in use anywhere in the estate, use **Microsoft Defender for Endpoint machine risk score** or a custom compliance script instead of (or alongside) this setting so passive-mode Defender doesn't unfairly fail devices that are actually protected by another vendor. |

---

## Requirement 5 — Firewall must be enabled for all profiles

| Field | Detail |
|---|---|
| Settings name | **Firewall** (category: *System Security*) |
| Value | **Require** |
| Effect | Device is marked non‑compliant if Windows Defender Firewall is disabled on any active network profile (Domain, Private, Public). |
| False‑positive risk | This setting only confirms the firewall **service/profile** is on — it does not check per-profile state granularly in the base toggle, so a device with firewall off on only the Public profile (e.g., after joining a new Wi-Fi network) can be inconsistently reported depending on which profile is currently active at check-in time. Group Policy or third-party firewall management tools that momentarily disable/re-enable the service during policy refresh can also cause transient flags. |
| Recommendation | Pair this compliance check with an **Endpoint security > Firewall** configuration profile that explicitly enforces all three profiles (Domain/Private/Public) to "On", rather than relying on compliance reporting alone to catch a single mis-set profile. |

---

## Requirement 6 — A PIN or password must be configured

| Field | Detail |
|---|---|
| Settings name | **Require a password to unlock mobile devices** (category: *System Security*) — *the "mobile devices" wording is legacy UI naming inherited from the mobile-first policy schema; it applies fully to Windows 10/11 desktops/laptops.* Additional related settings in the same group: **Password type** (set to *Device default* or *Numeric* to permit Windows Hello PIN), **Minimum password length**, **Maximum minutes of inactivity before password is required**. |
| Value | **Require = Yes**; Password type = **Device default**; Minimum length = **6** (or per org policy); Max inactivity = **15 minutes** (or per org policy) |
| Effect | Device is marked non‑compliant if no PIN/password/biometric unlock is configured, or if the configured method doesn't meet the minimum length/complexity/timeout thresholds. |
| False-positive risk | Devices enrolled via Windows Hello for Business with only biometric (face/fingerprint) configured but no PIN fallback can be misread by older policy versions expecting a traditional password. Kiosk/shared devices intentionally configured without a lock screen password will also legitimately (and correctly) fail — this is a common source of "why is this healthy device non‑compliant" tickets that is actually working as intended. |
| Recommendation | Confirm which device categories (kiosk, shared AVD session hosts, standard user laptops) should be exempt via a **filter or a separate compliance policy assignment**, rather than loosening the org-wide password requirement. Deploy a Windows Hello for Business / PIN configuration profile ahead of enforcing this to avoid a wave of initial non-compliance. |

---

## Requirement 7 — Device must not be jailbroken or rooted

| Field | Detail |
|---|---|
| Settings name | **Require device to not be jailbroken or rooted** (category: *Device Health*) |
| Value | **Require** |
| ⚠️ Platform caveat | This setting is primarily meaningful for **Android/iOS/iPadOS/macOS**; Windows has no direct "jailbreak/root" concept, so on the Windows 10/later profile this control has little/no practical detection effect. The closest genuine Windows equivalents are: **Require code integrity** (detects unauthorized kernel-mode driver/boot component tampering) and the **Microsoft Defender for Endpoint machine risk score** setting, both under *System Security* / *Microsoft Defender for Endpoint* categories. |
| Effect (as configured) | Provides negligible additional enforcement on Windows by itself; **Require code integrity = Require** is what actually blocks devices with tampered boot components or unsigned kernel drivers. |
| False‑positive risk | If code integrity is used as the substitute control: developer/test machines with unsigned test drivers loaded, or devices with driver signing enforcement temporarily disabled for troubleshooting, will flag as non-compliant. |
| Recommendation | Enable this toggle for completeness/audit purposes, but treat **Require code integrity + Secure Boot + BitLocker + Defender for Endpoint risk score** as the real compensating control set for "device tampering" on Windows. Document this substitution clearly in the policy so auditors understand why the literal requirement wording doesn't map 1:1 to a Windows-specific detection. |

---

## Grace Period — 7 days (applies to all settings above)

| Field | Detail |
|---|---|
| Settings name | **Actions for noncompliance** → action **Mark device noncompliant** → **Schedule (days after noncompliance)** |
| Value | **7** |
| Effect | A device that fails one or more of the settings above is *evaluated* immediately but is only formally **marked non‑compliant, and any downstream Conditional Access block/enforcement action fires, after 7 days** of continued failure. This gives users/automation time to self-remediate (e.g., re-enable firewall, install pending update, re-enrol BitLocker) before impact. |
| False‑positive risk | A 7-day window can mask a genuinely non-compliant device for up to a week if remediation doesn't happen — this is a security/usability trade-off, not a false-positive risk per se. Conversely, devices that are offline (leave, long holiday) for >7 days will accrue a non-compliance mark even though nothing on the device actually changed. |
| Recommendation | Add a secondary, earlier **"Send push notification / email to end user"** action at day 0–1 so users are alerted well before the 7-day enforcement point. Consider a slightly longer grace period (e.g., 10–14 days) specifically for the OS build requirement, since patch ring deployment timelines often exceed 7 days, to avoid punishing devices still waiting on a scheduled update ring. |

---

## ⚠️ Intune UI Path Notes (verify before deployment)

Microsoft reorganizes the Intune (formerly "Microsoft Endpoint Manager") admin center categories and blade names periodically. Treat the paths below as **best-known-current** and re-confirm in your tenant, since:
- The portal has previously been renamed from *Microsoft Endpoint Manager admin center* to simply **Intune admin center** ([intune.microsoft.com](https://intune.microsoft.com)).
- Settings have been re-grouped between *Device Health*, *Device Properties*, and *System Security* categories in past service updates (e.g., Firewall and Encryption-related settings have moved category groupings historically).
- "Require a password to unlock mobile devices" is a known point of confusion and is a candidate for renaming by Microsoft in future releases — if the exact string doesn't appear under *System Security*, search the settings picker for "password" or "PIN".

**Best-known current navigation path (as of latest available knowledge):**
```
Intune admin center (intune.microsoft.com)
 > Devices
   > Compliance policies (under "Manage")
     > Policies > Create policy
       > Platform: Windows 10 and later > Profile type: Compliance settings
         > Settings tabs: Device Health | Device Properties | Configuration Manager Compliance | System Security | Microsoft Defender for Endpoint
       > Actions for noncompliance tab (grace period configured here)
```

**Recommended validation step:** Before rollout, walk through the policy creation wizard in a test/pilot tenant and screenshot the actual setting names/categories present, since minor label or grouping changes do not always appear in public documentation immediately.

---

## Summary Table

| # | Requirement | Category | Setting | Value |
|---|---|---|---|---|
| 1 | BitLocker on OS drive | Device Health | Require BitLocker | Require |
| 2 | Secure Boot | Device Health | Require Secure Boot to be enabled on the device | Require |
| 3 | Min OS build N‑1 | Device Properties | Minimum OS version | 10.0.22621.2861 |
| 4 | Defender real-time protection | System Security | Real-time protection | Require |
| 5 | Firewall all profiles | System Security | Firewall | Require |
| 6 | PIN/password configured | System Security | Require a password to unlock mobile devices | Yes |
| 7 | Not jailbroken/rooted | Device Health | Require device to not be jailbroken or rooted (+ Require code integrity as real control) | Require |
| — | Grace period | Actions for noncompliance | Mark device noncompliant → Schedule | 7 days |
