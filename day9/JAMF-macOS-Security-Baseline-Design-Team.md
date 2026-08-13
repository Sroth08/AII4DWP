# JAMF Configuration Profile — macOS Security Baseline
## DWP Design Team Fleet | 25 Devices | 2026-08-13

---

## How to Use This Document

Each section maps one baseline requirement to its JAMF configuration profile payload.
Deploy as a single scoped profile or as separate profiles per payload — either is valid;
separate profiles give finer scope and easier rollback.

> **Naming caution (read before applying):**  
> JAMF Pro's UI payload labels and sub-option wording change between releases.
> Where exact label names are uncertain relative to your JAMF version, this document
> flags the section with ⚠️ **Verify label in your JAMF instance**. Do not trust the
> exact string in this document — navigate to the payload yourself and confirm the
> setting before deploying. This is the same discipline applied in the Intune labs
> on Day 6: AI output is a starting point, not a click-for-click instruction.

---

## Baseline Settings

---

### 1. FileVault Disk Encryption

| Field | Detail |
|---|---|
| **Payload type** | **FileVault 2** (`com.apple.MCX.FileVault2`) |
| **Value** | Enable FileVault: `ON` · Defer enablement to user: `ON` (recommended for existing devices so the user's credentials key the volume) · Personal Recovery Key escrow: `Enabled` — escrow to JAMF Pro |
| **Effect** | Forces full-disk encryption on the macOS startup volume. Without it, data on a lost or stolen MacBook is readable without credentials. Deferring to the user avoids a hard block at enrolment while still ensuring encryption is enabled at next login/logout. |
| **False-positive risk** | Devices that have never been logged out since enrolment will not yet have FileVault activated when using deferred mode — they will report as non-compliant until the user logs out and back in. Also, devices with a Secure Token issue (often seen after MDM re-enrolment) will fail to enable FileVault; this requires a Secure Token grant before the payload takes effect. |

> ⚠️ **Verify label:** The escrow key configuration lives under the FileVault 2 payload's
> **Recovery Key** section. The exact sub-label for "escrow to JAMF Pro" vs
> "escrow to institution" has varied across JAMF Pro versions — confirm in your instance.

---

### 2. Gatekeeper — Identified Developers Only

| Field | Detail |
|---|---|
| **Payload type** | **Security & Privacy** (`com.apple.systempolicy.control`) |
| **Value** | Allow apps downloaded from: `App Store and identified developers` (maps to `assessmentEnable = true`, `GKAutoRearm = true`) |
| **Effect** | Blocks execution of unsigned or unnotarised binaries. Apps from the Mac App Store and apps signed with a valid Apple Developer ID are permitted. Fully unsigned or revoked apps are blocked at launch. |
| **False-positive risk** | Legacy in-house tools or third-party utilities distributed outside the App Store that are unsigned will be blocked. Common examples: older versions of developer tools, custom scripts packaged as apps, or vendor-supplied .pkg installers that drop unsigned helper tools. Test all internally distributed software against this setting before deployment. |

> ⚠️ **Verify label:** In some JAMF Pro versions this appears under a **Restrictions** payload
> rather than **Security & Privacy**, depending on macOS target version. The underlying
> preference domain is `com.apple.systempolicy.control`. Confirm which payload surfaces
> this in your JAMF version before deploying.

---

### 3. Minimum macOS Version

| Field | Detail |
|---|---|
| **Payload type** | **Restrictions** — OS X Restrictions (`com.apple.applicationaccess`) or a **JAMF Pro Smart Group + Compliance policy** |
| **Value** | Minimum OS version: set to **current stable release minus one point release**. As of this document's date (2026-08-13), verify the current Apple stable release and subtract one — do not hardcode a version number from this document as macOS releases update independently of this baseline. |
| **Effect** | Devices running a macOS version older than the floor are flagged non-compliant. Depending on enforcement level chosen, this can trigger an enrolment restriction (blocking full access) or a notification nudge to the user. |
| **False-positive risk** | Devices that have received the MDM command but are pending a user-initiated update (e.g. waiting for a restart) will incorrectly flag as non-compliant during the update window. Also, devices on older hardware that Apple has dropped from the latest releases will be permanently non-compliant — exclude them by serial number or hardware model if intentional support exceptions exist. |

> ⚠️ **Verify label:** JAMF Pro handles OS version enforcement through **Smart Group**
> criteria (`Operating System Version is less than X`) combined with a **Restricted
> Software** or **Compliance** trigger, or through the **macOS Security Compliance
> Project (mSCP)** integration in newer JAMF versions. A direct "minimum OS version"
> field inside a configuration profile payload does not exist natively in macOS MDM —
> enforcement is done at the JAMF management layer. Confirm your JAMF version's
> recommended approach.

---

### 4. Firewall

| Field | Detail |
|---|---|
| **Payload type** | **Security & Privacy** (`com.apple.security.firewall`) |
| **Value** | Enable Firewall: `ON` · Block all incoming connections: `OFF` (leave off to avoid breaking legitimate services; enable only if this fleet has no shared resources) · Enable Stealth Mode: `ON` (recommended — prevents responses to unsolicited probe packets) |
| **Effect** | Activates the macOS Application Layer Firewall. Incoming connection attempts to apps not explicitly allowed are blocked. Stealth mode prevents the device from responding to network probes that could reveal its presence on a network. |
| **False-positive risk** | Developer tools, screen-sharing software, or collaboration apps (e.g. Zoom, Teams) that legitimately listen for incoming connections will prompt the user for firewall exceptions after deployment if they were not pre-allowed. Pre-approve known tools in the firewall payload's application exceptions list to avoid user disruption. |

> ⚠️ **Verify label:** The **Stealth Mode** toggle and **Enable Firewall** checkbox have
> appeared under different sub-sections of the Security & Privacy payload depending on
> JAMF Pro version. In some versions Stealth Mode is a separate key
> (`EnableStealthMode`). Confirm both are present in your payload editor.

---

### 5. Login Password Required After Sleep or Screen Saver

| Field | Detail |
|---|---|
| **Payload type** | **Security & Privacy** → General (`com.apple.screensaver` + `com.apple.loginwindow`) |
| **Value** | Require password after sleep or screen saver begins: `Immediately` (or `5 seconds` maximum for usability; `Immediately` is the baseline-compliant value) |
| **Effect** | As soon as the screen saver activates or the lid is closed, the device requires the user's login password to unlock. Eliminates the window during which an unattended device is accessible without credentials. |
| **False-positive risk** | Managed devices that are used as digital signage or kiosk displays will be incorrectly locked. If any Design team devices serve a display/kiosk function, create a separate scope and exclude them from this payload. Also: if the user's account uses biometric unlock (Touch ID) without a password, some compliance checks will flag the device despite Touch ID satisfying the unlock requirement — confirm whether your compliance definition accepts Touch ID as equivalent. |

> ⚠️ **Verify label:** This setting spans two preference domains:
> `askForPassword` and `askForPasswordDelay` in the screensaver domain, and may also
> appear under the **Login Window** payload in some JAMF versions. Confirm which
> payload controls the lock timeout in your environment — applying it in the wrong
> payload may result in a user-visible preference that can still be overridden locally.

---

### 6. Automatic Security Updates

| Field | Detail |
|---|---|
| **Payload type** | **Software Update** (`com.apple.SoftwareUpdate`) |
| **Value** | Automatically check for updates: `ON` · Download new updates when available: `ON` · Install macOS updates: configurable — set to `ON` only if the team accepts automatic OS updates; otherwise set to `OFF` and enforce via a separate software update policy · **Install security responses and system files**: `ON` (this is the critical one — covers Apple Rapid Security Responses) · Install app updates from App Store: `ON` |
| **Effect** | Ensures Rapid Security Responses (Apple's fast-track security patches, typically delivered without a full OS update) and system file patches are applied automatically. Full OS version updates can be held for a staged rollout while still enforcing security patches. |
| **False-positive risk** | Devices that are offline for extended periods (e.g. leave, equipment storage) will have a backlog of updates on return and may report as non-compliant until they connect and update. Allow a 48-hour grace window in compliance reporting for recently online devices. Also: if JAMF's own software update deferral policies conflict with this payload's settings, JAMF's policy wins — ensure no conflicting deferral policies are scoped to this group. |

> ⚠️ **Verify label:** The **Install security responses and system files** toggle
> (covering Rapid Security Responses, introduced in macOS Ventura) may appear as a
> separate key (`AutomaticallyInstallAppUpdates` / `CriticalUpdateInstall`) depending
> on your JAMF Pro version and the macOS target. Confirm the specific key name in your
> JAMF payload editor — this is a newer addition and label consistency across JAMF
> versions is not guaranteed.

---

## Deployment Checklist

| Step | Action |
|---|---|
| 1 | Verify every payload label and sub-option in your JAMF Pro instance before saving |
| 2 | Scope to a test device or pilot group of 2–3 Design team Macs first |
| 3 | Test FileVault escrow — confirm recovery key appears in JAMF Pro inventory |
| 4 | Test Gatekeeper by attempting to open an unsigned app — confirm it is blocked |
| 5 | Test firewall — confirm known collaboration tools are not broken |
| 6 | Test screen lock — confirm screen locks immediately after sleep |
| 7 | Confirm Software Update payload does not conflict with any existing deferral policy |
| 8 | Roll out to remaining 22 devices after pilot validation |
| 9 | Set a Smart Group criterion to flag any device where FileVault = Off or Firewall = Off |

---

## Scope Note

This profile is scoped to the **Design Team** group (25 devices).
Do not apply to shared kiosk or display devices without reviewing items flagged under
False-positive risk in sections 5 and 3.

---

## Document Information

| Field | Detail |
|---|---|
| Prepared by | traininguser23@zippyops.in |
| Date | 2026-08-13 |
| JAMF Pro version targeted | Verify against your instance — labels flagged ⚠️ above must be confirmed |
| macOS version scope | Confirm current stable release at time of deployment — do not rely on version numbers from this document |
