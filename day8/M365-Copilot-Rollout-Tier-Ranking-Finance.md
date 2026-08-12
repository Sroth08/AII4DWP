# Microsoft 365 Copilot Rollout — Tier Ranking for Finance Department

**References:** M365-Copilot-Readiness-Checklist-Finance.md  
**Department:** Finance (~200 users)  
**Date:** 2026-08-12  

---

## Why Permissions and Oversharing is a MUST — Not Just Another Checkbox

Before the tier list, this section answers the question directly.

Licensing verification and client version checks are administratively simpler, but they carry **zero data risk if skipped temporarily**. A user without a Copilot licence simply cannot use Copilot. A user on an older Office build gets a degraded or blocked experience. Neither outcome causes harm to the organisation.

Unaudited SharePoint permissions in a Finance environment are categorically different.

**Copilot does not create new access — it accelerates existing access.** When a user prompts Copilot, it queries everything that user can already read: SharePoint sites, OneDrive files, Teams messages, emails. If a Finance analyst inherited read access to the payroll library, the M&A working papers folder, or the board pack archive in 2019 — and that access was never revoked — Copilot will surface that content in response to a natural-language question. The user does not need to know the file path, remember the site exists, or even intend to access it. They might type *"summarise our cost reduction targets for this year"* and receive a synthesis drawn from a board pack they were never supposed to see.

In a standard department this is a concern. In Finance, with payroll data, M&A documents, client financial records, and executive compensation files in scope, it becomes a regulatory and legal exposure. UK GDPR, FCA data handling obligations, and internal information barriers (especially around M&A) mean that inadvertent disclosure via Copilot cannot be treated as a minor configuration issue after the fact.

The 2019 migration inheritance compounds this. Migrations routinely grant broad access to ensure continuity, with the expectation that permissions will be tightened post-migration. If that tightening never happened, seven years of joiners, movers, and leavers have accumulated entitlements that no longer reflect their roles. Copilot deployment without auditing this is not a calculated risk — it is an unknown risk, which is worse.

**Licensing and client version checks are quick wins that should be done in parallel. Permissions remediation is the gate that must close before licences go live.**

---

## Tier 1 — MUST Complete Before Rollout (Blocking)

These items must be fully completed and verified before any Copilot licence is assigned. Proceeding without them creates data exposure, compliance failure, or a broken product that cannot function.

### Permissions and Oversharing Audit (Section 2 — entire section)

| Item | Why it blocks rollout |
|------|-----------------------|
| Run SharePoint permissions report across all Finance sites | Without this, the blast radius of inherited access is unknown. You cannot make a risk decision on unknown scope. |
| Identify and remove "Everyone" / "Everyone except external users" access | Copilot will query this content for every Finance user. Payroll and M&A data surfaced at scale is an immediate regulatory incident. |
| Remove anonymous and company-wide sharing links | These links represent content with no access control. Copilot treats linked content as accessible. |
| Break inheritance on payroll, M&A, board pack, and client financial data libraries | Role-based, explicit permissions are the minimum control required before Copilot indexes these libraries. |
| Expire/delete stale sharing links older than 90 days | Stale links are invisible entitlements. They will not appear in role reviews but Copilot will follow them. |
| Re-run permissions report to validate remediation | Remediation without verification is not remediation. This is the evidence item for audit. |
| Section 2 sign-off from Finance Data Owner and Information Security | Organisational accountability must be established before deployment proceeds. IT cannot self-certify this section. |

### Identity and MFA (Section 3 — critical items)

| Item | Why it blocks rollout |
|------|-----------------------|
| MFA enforced via Conditional Access for all 200 Finance users | Copilot operates under the user's identity. An account without MFA is a single-credential exposure point for all Finance Copilot output. |
| No Finance accounts excluded from MFA CA policy | Post-migration exemptions are a common oversight. One unprotected account in Finance is unacceptable given the data in scope. |
| All users on Entra ID — no on-premises-only accounts | Copilot requires cloud identity. On-prem-only accounts will fail silently or produce inconsistent behaviour. |

### Licensing (Section 1 — assignment gate only)

| Item | Why it blocks rollout |
|------|-----------------------|
| Do not assign Copilot add-on licences until Tier 1 permissions sign-off is complete | This is the enforcement mechanism for the entire tier. Licence assignment is the point of no return for user access. |

---

## Tier 2 — SHOULD Complete Before Rollout (High Risk if Skipped)

These items do not technically prevent Copilot from functioning, but skipping them materially increases the risk of data mishandling, compliance gaps, or a poor and potentially harmful deployment.

### Sensitivity Labelling (Section 5)

| Item | Risk if skipped |
|------|-----------------|
| Sensitivity labels published to Finance users | Without labels, Copilot has no signal to differentiate a payroll spreadsheet from a canteen menu. DLP policies cannot fire on unlabelled content. |
| Auto-labelling policies active for Finance content types | Manual labelling compliance in a 200-user Finance team will not be consistent. Auto-labelling is the realistic control. |
| Content Explorer scan for unlabelled/mislabelled documents | Deploying Copilot before understanding the labelling state means you cannot confidently answer a post-incident question about what Copilot could access. |
| DLP policies active for Highly Confidential Finance content | DLP is a backstop against Copilot-assisted exfiltration. Should be live before users start prompting. |

### Licensing Prerequisites (Section 1 — verification items)

| Item | Risk if skipped |
|------|-----------------|
| Confirm all 200 users on M365 E5 — no mixed licences | Mixed licences cause inconsistent feature availability. Finance users on different licence tiers will have different Copilot behaviour, creating support overhead and potential confusion about what Copilot "knows". |
| Confirm no data residency restrictions apply to Finance data | If Finance data is subject to a residency restriction incompatible with Copilot's processing regions, this is a compliance issue that surfaces after deployment. |

### End-User Communications (Section 6 — pre-deployment items)

| Item | Risk if skipped |
|------|-----------------|
| Pre-deployment communication sent to Finance users | Users who encounter Copilot without preparation may misuse it, share outputs inappropriately, or attempt to probe it for access they know they shouldn't have. |
| Guidance on not pasting raw payroll/M&A text into prompts | This is the most likely day-one misuse vector in Finance. Users will naturally paste data into prompts without this instruction. |
| Mandatory AI acceptable use training completed | Without this, the organisation has no evidence base for enforcing the acceptable use policy if an incident occurs. |

---

## Tier 3 — CAN Complete During or After Rollout (Lower Risk)

These items improve the deployment, governance posture, or user experience but do not represent a blocking risk. They should be scheduled with clear owners and target dates rather than treated as optional.

### Ongoing Permissions Governance (Section 2c)

| Item | Notes |
|------|-------|
| Enable SharePoint Advanced Management DAG reports | Important for long-term health; not needed on day one if Tier 1 remediation is complete. |
| Set quarterly permissions review cadence for Finance sites | Process establishment — can be set up during the first month of operation. |
| Enable access request notifications routing to Finance data owner | Improvement to governance; default routing to IT is acceptable short-term. |
| Document residual permission exceptions with business justification | Should be completed within 30 days of go-live; cannot be indefinitely deferred. |

### Identity (Section 3 — lower-urgency items)

| Item | Notes |
|------|-------|
| SSPR registration verified for all Finance users | Helpful for self-service recovery; not a Copilot-specific blocker. |
| Entra ID Protection sign-in risk policies active | Best practice identity hardening; not unique to Copilot deployment. |
| Microsoft Authenticator registration confirmed for all users | Preferred MFA method but any MFA method satisfies the Tier 1 gate. |

### Client Version and Apps Health (Section 4)

| Item | Notes |
|------|-------|
| M365 Apps health dashboard review for Finance cohort | Useful monitoring; individual device compliance check at Tier 1 is sufficient for go-live. |
| WebView2 Runtime deployed to all Finance endpoints | Required for full Copilot UI; devices missing it will get a degraded experience but this can be pushed via Intune post-launch. |
| Teams desktop client on new Teams (2.x) | Recommended; Copilot in Teams functions on current Teams client. Migration to new Teams can be phased. |

### End-User Enablement (Section 6 — post-launch items)

| Item | Notes |
|------|-------|
| Finance prompt library published | High value for adoption; develop based on real user questions in the first two weeks. |
| Finance-specific Copilot onboarding session delivered | Can occur on day one or within the first week; does not need to precede licence assignment. |
| Feedback channel established | Should be live on day one of rollout, but setup is quick and low-risk to complete last. |
| 2-week post-go-live review scheduled | Schedule this before go-live; conduct it two weeks after. |

---

## Summary View

| Section | Tier 1 MUST | Tier 2 SHOULD | Tier 3 CAN |
|---------|-------------|---------------|------------|
| Permissions & Oversharing | ✅ Entire section | — | Governance cadence items |
| Identity & MFA | MFA CA enforcement, Entra ID cloud accounts, no CA exclusions | — | SSPR, risk policies, Authenticator preference |
| Licensing | Licence assignment gate | E5 verification, residency check | — |
| Sensitivity Labelling | — | Labels, auto-labelling, DLP, Content Explorer scan | — |
| M365 Apps Client Version | — | — | Apps health dashboard, WebView2, Teams version |
| End-User Comms | — | Pre-comms, raw data paste guidance, AUP training | Prompt library, onboarding session, feedback channel, post-go-live review |

---

*This document should be read alongside M365-Copilot-Readiness-Checklist-Finance.md. Tier assignments reflect the Finance department's specific data sensitivity and the known unaudited permissions inherited from the 2019 migration.*
