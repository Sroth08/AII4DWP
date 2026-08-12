# Microsoft 365 Copilot Readiness Checklist — Finance Department

**Department:** Finance (~200 users)  
**Licensing baseline:** M365 E5 (Copilot add-on not yet assigned)  
**Data sensitivity:** Payroll, board packs, M&A documents, client financial data  
**Known risk:** SharePoint permissions inherited from 2019 migration — never audited  
**Prepared by:** Endpoint Engineering  
**Date:** 2026-08-12  

---

> **Priority note:** The permissions and oversharing section is ranked highest. Copilot surfaces content the user can already access. If oversharing exists in SharePoint/OneDrive, Copilot will expose it at scale — instantly and silently. All other checklist sections should proceed in parallel, but **no Copilot licences should be assigned until Section 2 is signed off by the data owner and Information Security.**

---

## Section 1 — Licensing Prerequisites

- [ ] Confirm all ~200 Finance users hold an active **M365 E5** licence in the Microsoft 365 admin centre.
- [ ] Confirm no users are on legacy E3 or mixed-licence plans that would block Copilot eligibility.
- [ ] Procure and stage **Microsoft 365 Copilot add-on licences** (one per user) — do not assign until Section 2 sign-off.
- [ ] Verify Microsoft 365 Copilot is available in your tenant region and that no data residency restrictions apply to Finance data.
- [ ] Confirm the tenant has **Microsoft 365 Copilot service plan** enabled at tenant level (admin centre → Settings → Copilot).
- [ ] Check for any conditional licence blocks applied to the Finance OU or Entra ID group that would prevent add-on assignment.

---

## Section 2 — SharePoint / OneDrive Permissions and Oversharing Audit ⚠️ HIGHEST PRIORITY — SIGN-OFF REQUIRED BEFORE LICENCE ASSIGNMENT

> Copilot indexes everything the user can access. Inherited permissions from the 2019 migration mean users may silently have read access to payroll files, M&A folders, board packs, and client financial data outside their role. Copilot will query all of it.

### 2a — Enumerate Inherited Permissions

- [ ] Run the **SharePoint Assessment tool** (`Microsoft.SharePoint.Migration.Scan`) or use **SharePoint Advanced Management** to generate a permissions report across all Finance site collections.
- [ ] Export a full site-by-site permissions report identifying:
  - Sites/libraries with **"Everyone"** or **"Everyone except external users"** access.
  - Sites with **"Company-wide"** sharing links outstanding.
  - Inherited permissions chains traceable back to pre-2019 group membership.
- [ ] Cross-reference current group memberships against the 2019 migration manifest to identify stale entitlements.
- [ ] Flag any site or library containing payroll, M&A, or board pack data that has **more than the minimum expected membership**.

### 2b — Oversharing Remediation

- [ ] Remove or convert all **"Anyone" / anonymous** sharing links on Finance SharePoint sites.
- [ ] Remove **"Everyone except external users"** from Finance site permissions where present.
- [ ] Break inheritance on libraries containing: payroll, executive compensation, M&A working papers, board packs, and client financial data. Assign explicit, role-based groups only.
- [ ] Delete or expire all **stale sharing links** older than 90 days across Finance OneDrive accounts.
- [ ] Enforce **site-level sharing settings** on Finance sites to restrict to "Existing access" or "Specific people" — disable "Anyone with the link".
- [ ] Review and restrict **OneDrive personal sharing** for Finance users: set tenant policy to prevent sharing outside the Finance security group for files classified Confidential or above.
- [ ] Validate remediation: re-run the permissions report and confirm no residual broad-access entries before proceeding.

### 2c — Ongoing Governance Controls

- [ ] Enable **SharePoint Advanced Management — Data Access Governance (DAG) reports** to detect future oversharing automatically.
- [ ] Set a **quarterly permissions review** cadence for Finance sites, owned by the Finance data owner.
- [ ] Enable **access request notifications** to route to the Finance data owner, not IT.
- [ ] Document residual exceptions with a business justification, data owner sign-off, and expiry date.

**Section 2 sign-off:**

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Finance Data Owner | | | |
| Information Security | | | |
| IT Service Owner | | | |

---

## Section 3 — Identity and MFA Readiness

- [ ] Confirm all ~200 Finance users are fully migrated to **Entra ID (Azure AD)** — no on-premises-only accounts.
- [ ] Verify **MFA is enforced** for all Finance users via Conditional Access policy (not just per-user MFA legacy setting).
- [ ] Confirm **SSPR (Self-Service Password Reset)** is enabled and Finance users have registered at least two authentication methods.
- [ ] Check no Finance accounts are excluded from MFA Conditional Access policies (common post-migration exemption that is often forgotten).
- [ ] Verify **Privileged Identity Management (PIM)** or equivalent is in place for any Finance users with elevated SharePoint/admin roles.
- [ ] Confirm **sign-in risk policies** are active: block or challenge sign-ins flagged as high-risk (Entra ID Protection).
- [ ] Ensure all Finance users have completed registration for the **Microsoft Authenticator app** (preferred MFA method for Copilot workflows).

---

## Section 4 — Microsoft 365 Apps Client Version Requirements

- [ ] Confirm all Finance endpoints are running **Microsoft 365 Apps for Enterprise, Current Channel or Monthly Enterprise Channel**.
- [ ] Minimum required build: **Version 2302 (Build 16130.20218)** or later — verify via Intune device compliance report or Microsoft 365 Apps admin centre.
- [ ] Confirm **Office update channel** is set to Current Channel or Monthly Enterprise Channel in Intune/Group Policy — Semi-Annual Channel does not receive Copilot features promptly.
- [ ] Verify **Click-to-Run** is in use (not MSI/perpetual Office) across all Finance devices.
- [ ] Confirm **Microsoft Teams desktop client** is on a supported version (Teams 2.x/new Teams preferred).
- [ ] Check for any devices still running **Office 2019 or Office 2021 perpetual** — these do not support Copilot; replace or migrate.
- [ ] Validate that **WebView2 Runtime** is deployed on all Finance endpoints (required by Copilot UI components).
- [ ] Run a compliance report from the **Microsoft 365 Apps health dashboard** (admin centre → Health → Microsoft 365 Apps health) for the Finance device cohort.

---

## Section 5 — Sensitivity Labelling Readiness

> Copilot respects sensitivity labels at query time. Unlabelled or mislabelled Finance data will not receive the correct access or handling controls.

- [ ] Confirm **Microsoft Purview Information Protection** sensitivity labels are published to Finance users via a scoped label policy.
- [ ] Verify the Finance label taxonomy covers at minimum: `Internal`, `Confidential`, `Highly Confidential — Finance`, `Restricted` (or equivalent aligned to your classification scheme).
- [ ] Confirm **auto-labelling policies** are configured for high-sensitivity Finance content types (payroll, financial statements, M&A) in SharePoint and OneDrive.
- [ ] Run a **Content Explorer** scan (Purview → Data Classification → Content Explorer) to identify unlabelled or mislabelled Finance documents — remediate before Copilot deployment.
- [ ] Verify that **label inheritance** is configured: documents inherit the label of their parent site/library when no explicit label is applied.
- [ ] Confirm **DLP policies** are active for Finance data: block or restrict sharing of Highly Confidential content outside the organisation.
- [ ] Verify Copilot will respect labels: test that a user without access to a `Highly Confidential — Finance` document cannot surface its content via Copilot prompt.
- [ ] Confirm the **Finance data owner** has reviewed and approved the label taxonomy and auto-labelling scope.

---

## Section 6 — End-User Communications and Enablement

- [ ] Draft and issue a **pre-deployment communication** to Finance users explaining: what Copilot is, what data it can access (their own accessible content only), and what it cannot do (not a compliance bypass, not a data exfiltration tool).
- [ ] Include clear guidance on **responsible use**: do not use Copilot to attempt to access documents outside normal role scope; report unexpected content surfaced by Copilot to IT Security immediately.
- [ ] Schedule a **Finance-specific Copilot onboarding session** (30–60 min) covering: Word, Excel, Outlook, and Teams use cases relevant to Finance workflows.
- [ ] Publish a **Finance prompt library** of approved, tested Copilot prompts relevant to the department (budget summaries, meeting notes, data analysis tasks).
- [ ] Communicate the **data handling boundaries**: remind users that payroll, M&A, and board pack data must not be copy-pasted into Copilot prompts as raw text — reference documents via normal file access instead.
- [ ] Confirm users have completed any mandatory **AI acceptable use training** required by your organisation's AI policy before licences are activated.
- [ ] Establish a **feedback channel** (e.g. shared mailbox or Teams channel) for Finance users to report Copilot issues, unexpected data surfacing, or concerns.
- [ ] Plan a **2-week post-go-live review** with the Finance lead to assess adoption, surface any permission anomalies identified via Copilot, and tune prompt guidance.

---

## Final Go / No-Go Gate

| Gate | Status | Owner | Date |
|------|--------|-------|------|
| Section 2 permissions audit complete and signed off | ☐ | Finance Data Owner + InfoSec | |
| No "Everyone" or anonymous sharing links outstanding | ☐ | IT Engineer | |
| MFA enforced for all 200 Finance users | ☐ | Identity Team | |
| M365 Apps at minimum supported build on all Finance devices | ☐ | Endpoint Team | |
| Sensitivity labels published and auto-labelling active | ☐ | Purview/Compliance Team | |
| End-user comms sent and training completed | ☐ | Change Manager | |
| **Copilot licences assigned** | ☐ | IT Admin — ONLY after all gates above are green | |

---

*This checklist should be reviewed by Information Security and the Finance data owner before any licence assignment. Permissions remediation findings should be retained as evidence for audit purposes.*
