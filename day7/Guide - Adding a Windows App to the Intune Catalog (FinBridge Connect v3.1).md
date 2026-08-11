# Guide — Adding a Windows App to the Intune Catalog

| Field | Value |
|---|---|
| Title | Guide — Adding a Windows App to the Intune Catalog |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | DWP Endpoint Engineer |
| Reviewed | Self |
| Status | Draft |
| Scope | Devices > Apps > add a Windows LOB (.intunewin) app, through to pilot-group assignment |
| Worked example | FinBridge Connect v3.1 (.intunewin), install `FinBridgeConnect_Setup.exe /silent`, uninstall `FinBridgeConnect_Setup.exe /uninstall /silent`, detection `HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1` |

## Purpose
Step-by-step guide for adding a Windows LOB app to the Intune catalog and assigning it to a small pilot group, as the prerequisite before any phased rollout (e.g. the FinBridge Connect v3.1 deployment plan) can begin. Written for an engineer with no prior Intune app-deployment experience.

> **Note on data handling:** This document contains no credentials, tenant names, or device identifiers — safe for use per the Personal AI Usage Charter.

> ⚠ **General warning on UI labels:** Microsoft renames, regroups, and re-styles Intune portal labels, menu positions, and blade names between tenant versions and rollout waves fairly often. Every navigation path below is **based on a commonly seen layout, not guaranteed to match your tenant exactly**. Wherever you see ⚠, stop and visually confirm the actual label/position in your own tenant before clicking — do not trust the text blindly.

---

## 0. Prerequisite — Packaging the app as a .intunewin file

Before the app can be added to the catalog (Section 1), the installer must be wrapped into the **.intunewin** format using Microsoft's **Win32 Content Prep Tool** (`IntuneWinAppUtil.exe`). This is a local packaging step, run once, before any upload to Intune.

```powershell
# 1. Create a local working folder to hold the installer.
New-Item -Path "C:\dwp-labs\FinBridgeConnect" -ItemType Directory -Force

# 2. Obtain FinBridgeConnect_Setup.exe into that folder.
#    FinBridge Connect is an internal LOB app, not a public download — replace the source
#    path below with your actual internal share/repo location for the v3.1 installer.
Copy-Item -Path "\\<internal-source-path>\FinBridgeConnect_Setup.exe" -Destination "C:\dwp-labs\FinBridgeConnect\FinBridgeConnect_Setup.exe"

# 3. Download the Win32 Content Prep Tool from Microsoft's official repo.
Invoke-WebRequest -Uri "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -OutFile "C:\dwp-labs\IntuneWinAppUtil.exe"

# 4. Wrap FinBridgeConnect_Setup.exe into a .intunewin package for upload to Intune.
C:\dwp-labs\IntuneWinAppUtil.exe -c "C:\dwp-labs\FinBridgeConnect" -s "FinBridgeConnect_Setup.exe" -o "C:\dwp-labs"
```

| Parameter | Meaning | Value for FinBridge Connect v3.1 |
|---|---|---|
| `-c` | Source folder containing the installer and all its supporting files | `C:\dwp-labs\FinBridgeConnect` |
| `-s` | Setup file name (relative to `-c`) | `FinBridgeConnect_Setup.exe` |
| `-o` | Output folder for the generated `.intunewin` file | `C:\dwp-labs` |

- ⚠ Verify: `IntuneWinAppUtil.exe` must be obtained from Microsoft's official [Win32 Content Prep Tool GitHub repo](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool) — confirm you're running a version from that source, not a third-party copy.
- ⚠ Verify: replace `\\<internal-source-path>\` with the actual internal share/repo path for the FinBridge Connect v3.1 installer before running — do not substitute a public download URL, as this app is not publicly distributed.
- Replace all local paths above with your own working folders before running; none of the values shown are tenant-specific or sensitive.
- The resulting `.intunewin` file (e.g. `FinBridgeConnect_Setup.intunewin`) is what you select when prompted in Section 2 below.

---

## 1. Where to add an app in Intune

1. **Sign in to the Microsoft Intune admin center.**
   - Path: `endpoint.microsoft.com` (or `intune.microsoft.com` on newer tenants) → sign in with an account holding the **Intune Administrator** (or equivalent app-management) role.
   - ⚠ Verify: the exact portal domain and the role name can differ by tenant licensing/version — confirm with your tenant admin if sign-in is refused.

2. **Navigate to the Apps blade.**
   - Path: left-hand menu → **Apps** → **All apps**.
   - Expected result: a list/table of currently published apps, with an **+ Add** button above it.
   - ⚠ Verify: on some tenants **Apps** is nested under a **Devices** or **Endpoint Manager** landing page rather than being a top-level menu item.

3. **Start the add-app wizard.**
   - Path: **Apps > All apps** → **+ Add**.
   - Expected result: a panel/blade opens asking you to select an **app type** before anything else — this is the decision covered in Section 2.

---

## 2. Choosing the app type

The **App type** selector is the first choice in the wizard and determines every field you'll see afterwards. Picking the wrong type here means restarting the wizard.

| App type (as commonly labelled) | When to use it | Applies to FinBridge Connect v3.1? |
|---|---|---|
| **Windows app (Win32)** / **Line-of-business app** (exact label varies) | A locally packaged Windows installer wrapped as a **.intunewin** file, with your own install/uninstall commands, requirements, and detection rules — full control over deployment behaviour. | **Yes — this is the type to select.** FinBridge Connect v3.1 is a .intunewin package with custom silent install/uninstall switches. |
| **Microsoft Store app** (new Store / Store for Business, naming varies) | A published Microsoft Store listing, installed via the Store back end — no custom install command, no .intunewin packaging. | No — FinBridge Connect is not a Store app. |
| **Line-of-business app** (as a distinct, simpler option on some tenants, separate from Win32) | A single install file (e.g. MSI) with **no** custom requirements/detection logic beyond what Intune infers from the installer itself — less flexible than the Win32 option. | No — FinBridge Connect needs a custom silent install command and a registry-based detection rule, which requires the Win32/LOB option with full field control, not the simplified variant. |
| **Web link / Web app** | A shortcut to a URL, not an installed application. | No — not applicable to an installed Windows executable. |

- ⚠ Verify: the naming split between "Line-of-business app" and "Windows app (Win32)" has changed across Intune UI versions and is a common source of confusion — if in doubt, select the option that explicitly mentions **.intunewin** as the required file type, since that matches the FinBridge Connect package.

Select the **.intunewin-based Windows app type**, then select the FinBridge Connect v3.1 `.intunewin` file when prompted to upload the package.

---

## 3. Required fields when creating the LOB Windows app

The wizard is typically organised into tabs/steps: **App information**, **Program**, **Requirements**, **Detection rules**, **Return codes** (sometimes grouped under "Program" or shown as its own step), **Assignments**, **Review + create**. ⚠ Verify: tab names, order, and grouping (e.g. whether Return codes is its own tab or folded into Program) vary by tenant version.

### 3.1 App information

| Field | Value for FinBridge Connect v3.1 | Notes |
|---|---|---|
| Name | FinBridge Connect v3.1 | Include the version in the display name — makes rings/reporting/supersedence unambiguous later. |
| Description | e.g. "FinBridge Connect client, version 3.1 — internal finance connectivity tool." | Free text; keep it factual, no internal-only jargon that a helpdesk reader wouldn't understand. |
| Publisher | FinBridge (or the actual vendor/internal team name) | Shown to end users in Company Portal if the app is made **Available** — keep it recognisable. |
| Version (if a distinct version field is offered) | 3.1 | Some tenants only take version info from the package/detection rule rather than a separate field — ⚠ verify whether your tenant exposes this as an editable field. |

### 3.2 Program

| Field | Value for FinBridge Connect v3.1 |
|---|---|
| Install command | `FinBridgeConnect_Setup.exe /silent` |
| Uninstall command | `FinBridgeConnect_Setup.exe /uninstall /silent` |
| Install behavior | **System** (runs as `NT AUTHORITY\SYSTEM`, applies machine-wide) unless FinBridge Connect specifically requires per-user install context — confirm with the vendor/packaging notes before choosing **User**. Defaulting to System is normal for LOB tools shared across all users of a device. |

- ⚠ Verify: the exact field label is sometimes "Install behavior" and sometimes "Device restart behavior" is a separate, adjacent field — don't confuse the two; restart behaviour controls what happens after install, not the execution context.

### 3.3 Requirements

| Field | Value for FinBridge Connect v3.1 |
|---|---|
| Operating system architecture | Select the architecture(s) the package actually supports (e.g. **64-bit**, or both 32/64-bit if the vendor confirms dual support). Do not assume — check the installer/vendor documentation. |
| Minimum operating system | Select the lowest Windows 11 version FinBridge Connect v3.1 is supported/tested on. If unknown, use the same minimum build already enforced by your compliance policy baseline, so nothing installs on a device that would already be flagged non-compliant. |

- ⚠ Verify: additional requirement fields (disk space, memory) may appear depending on tenant version — if a **minimum RAM** field is available, this is directly relevant given the known 5% of the fleet on 4GB RAM hardware; set it deliberately rather than leaving it blank if you want Intune itself to block install attempts on underspecified devices.

### 3.4 Detection rules

This is how Intune decides an install **succeeded**, independent of the installer's own exit code.

| Field | Value for FinBridge Connect v3.1 |
|---|---|
| Rule format | **Registry** |
| Key path | `HKLM\SOFTWARE\FinBridge\Connect` |
| Value name | `Version` |
| Detection method | **String comparison — equals** `3.1` (not "exists", which would also match a pre-existing v3.0 key if the key path is unchanged between versions) |

Other detection rule types available (for reference, not used here since FinBridge Connect uses a registry key):
- **MSI product code** — used when the installer is a native MSI; Intune reads the product code/version automatically.
- **File** — checks for a specific file path/version/size on disk, used when neither registry nor MSI product code is reliable.

- ⚠ Verify: confirm `HKLM\SOFTWARE\FinBridge\Connect\Version` is the actual key/value the v3.1 installer writes (not assumed from v3.0) — an incorrect or loosely matched rule (e.g. "key exists" instead of "value equals 3.1") can make Intune report a device as successfully installed when it is still on v3.0, or vice versa.

### 3.5 Return codes

| Exit code | Meaning (typical defaults) |
|---|---|
| 0 | Success |
| 1707 | Success |
| 3010 | Soft reboot required (treated as success, pending restart) |
| 1641 | Hard reboot initiated (treated as success) |
| 1618 | Retry — another install is in progress |
| Anything else / non-zero not listed | Failed |

- Confirm with the FinBridge Connect packaging notes whether `FinBridgeConnect_Setup.exe` returns standard installer exit codes or a custom scheme; add/adjust entries in this table to match before relying on it for Ring exit-criteria reporting (per the rollout plan).
- ⚠ Verify: the default return code table pre-populated by Intune is a general Windows-installer convention, not guaranteed to match every custom `.exe` installer — check the vendor's documented exit codes for `FinBridgeConnect_Setup.exe` specifically.

---

## 4. Assignment basics

| Assignment type | Effect | Use for FinBridge Connect v3.1? |
|---|---|---|
| **Required** | Installs automatically, silently, on all devices/users in the assigned group — no user action needed. | Yes, for the pilot/test group in this step, and later for each rollout ring per the deployment plan. |
| **Available** | App is listed in Company Portal for the user to install voluntarily — not pushed automatically. | Not used here; FinBridge Connect is a required business tool, not an optional install. |
| **Uninstall** | Actively removes the app from any device/user in the assigned group. | Reserved for rollback scenarios (e.g. removing v3.1 from a group being reverted to v3.0) — not used at initial catalog setup. |

**Assign to a small pilot/test group first, not the full 10,000-device fleet:**
- A misconfigured install command, requirement, or detection rule (Sections 3.2–3.4) affects every device it's assigned to immediately — testing on ~10–20 devices first limits the blast radius of a packaging or detection mistake to a handful of machines instead of the entire fleet.
- This mirrors Ring 0 in the phased deployment plan: the pilot group here **is** that Ring 0 assignment, and its exit criteria (successful install, correct detection reporting, no incidents) must pass before assigning Ring 1 (Finance) or any wider group.
- Practically: create/select a small Azure AD security group (e.g. "Pilot-FinBridgeConnect") containing test devices or users, and assign **Required** to that group only in this step.

---

## 5. Verification steps

1. **Confirm the app appears correctly in the catalog.**
   - Path: **Apps > All apps** → search "FinBridge Connect v3.1".
   - Expected result: the app is listed with the correct name, publisher, and app type (Win32/LOB), and its **Assignment** column shows the pilot group only — not "All devices"/"All users".

2. **Check install status on an assigned test device.**
   - Path: **Apps > All apps** → **FinBridge Connect v3.1** → **Device install status** (or **Monitor > Device install status**, naming varies by tenant).
   - Expected result: the pilot test device(s) appear in the list with a status (see below) that updates within Intune's normal check-in interval — allow time for the device to sync before treating an unexpected result as a fault.
   - Alternative check directly on the device: confirm the registry key `HKLM\SOFTWARE\FinBridge\Connect\Version` is present and equals `3.1` after install, which is exactly what the detection rule (Section 3.4) is evaluating.

3. **Interpret the status values.**

   | Status | Meaning |
   |---|---|
   | **Installed** | The detection rule (Section 3.4) evaluated true on the device — Intune considers the app successfully present. |
   | **Failed** | The install command ran but either returned a failure exit code (Section 3.5) or completed and the detection rule still evaluated false — treat both causes as worth checking; they point to different problems (installer failure vs. detection rule mismatch). |
   | **Not applicable** | The device does not meet the assignment/requirements criteria (e.g. wrong architecture, below minimum OS version, or not a member of the assigned group) — this is expected and not an error for out-of-scope devices, but is worth double-checking on an in-scope device, since it usually means a Requirements field (Section 3.3) excluded it unintentionally. |

- ⚠ Verify: exact status wording ("Installed" vs "Succeeded", "Not applicable" vs "Not applicable/excluded") can differ slightly by tenant version — treat the meanings above as the intent to look for, not a guaranteed literal string match.

---

## Summary checklist

- [ ] App type selected: Windows app (Win32) / LOB with `.intunewin` upload — not Store app or Web link.
- [ ] App information filled in with version-specific name (v3.1).
- [ ] Install/uninstall commands and install behavior (System context) set per Section 3.2.
- [ ] Requirements (architecture, min OS, and RAM if available) set deliberately, not left default.
- [ ] Detection rule validated against the actual v3.1 registry value, not assumed from v3.0.
- [ ] Return codes reviewed/adjusted against the vendor's documented exit codes.
- [ ] Assigned as **Required** to a small pilot group only.
- [ ] Catalog entry, device install status, and on-device registry key all verified before proceeding to Ring 1 of the phased deployment plan.
