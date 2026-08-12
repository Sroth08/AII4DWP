# Microsoft 365 Copilot — Legal Team Support Ticket Triage

**Triaged by:** Endpoint Engineering  
**Date:** 2026-08-12  
**Triage rule:** Default to non-Copilot causes unless evidence genuinely rules them all out. Genuine Copilot fault is always last resort.

---

## Ticket 1 — Paralegal: "I don't have access to that content" on a client NDA

**Likely cause (ranked)**
1. **Permissions/access boundary** — The paralegal states she has *never opened the folder before* and only heard about it in a meeting. She almost certainly does not have permissions to it. Copilot correctly reflects that boundary — it cannot access content the user cannot access.
2. **Sensitivity label restriction** — NDAs are exactly the document type likely to carry a high-confidentiality label that blocks Copilot processing, even for users who do have read access.

**Fastest check**  
Ask the paralegal to navigate directly to the SharePoint folder in her browser. If she gets an "Access Denied" page, permissions are the answer — no further investigation needed.

**Is this actually a Copilot bug?**  
No. "I heard about it in a meeting" is not the same as having access to it. Copilot returning "I don't have access" when the user has no permissions is the system working correctly.

---

## Ticket 2 — New Associate: Copilot can't find case emails

**Likely cause (ranked)**
1. **Data indexing lag** — The associate started this week. A brand-new mailbox has a minimal index. Microsoft Search builds the mailbox index incrementally; for a new account there is very little for Copilot to retrieve, regardless of what emails are present.
2. **Licence/client prerequisite issue** — The Copilot add-on may not yet have been assigned to the new account, or was assigned too recently for the service plan to have fully propagated.

**Fastest check**  
Check in the Microsoft 365 admin centre that the Copilot licence is assigned to this user and note the date it was assigned. If it was assigned within the last 24–48 hours, indexing lag is the primary cause.

**Is this actually a Copilot bug?**  
No. A near-empty index on a week-old account producing limited results is expected behaviour.

---

## Ticket 3 — Partner: Copilot surfaced a draft settlement from a matter they are not assigned to ⚠️ ESCALATE IMMEDIATELY

**Likely cause (ranked)**
1. **Permissions/access boundary** — Copilot only surfaces content the user can already access. The partner has read permissions to that folder, almost certainly via inherited or broadly-scoped matter permissions that were never tightened. Copilot did not breach anything — it made existing, overlooked access visible.

**Fastest check**  
Navigate to the settlement document in SharePoint and open the permissions panel. Confirm whether the partner is a named member, in a group with access, or whether broad inheritance from a parent site is granting access.

**Is this actually a Copilot bug?**  
No. This is an **oversharing/permissions finding, not a Copilot fault.** Copilot surfacing the document is correct behaviour given the current permissions state. This ticket should be immediately escalated to the matter supervisor and Information Security — the permissions on that folder need to be reviewed and tightened. In a legal environment, inadvertent access to a draft settlement from an unrelated matter has professional conduct and privilege implications well beyond a standard IT issue.

---

## Ticket 4 — Legal Ops Manager: Entire Legal team lost Copilot access this morning

**Likely cause (ranked)**
1. **Licence/client prerequisite issue** — A sudden, team-wide loss of access is the classic signature of a group-level licence change: the Legal team's security group may have been modified, removed from the Copilot licence assignment, or had the service plan toggled. Check for any admin activity against the Legal group or the Copilot service plan in the last 24 hours.
2. **Genuine Copilot fault** — A service-level incident affecting a specific group is unusual but cannot be ruled out until the licence and group audit log is checked.

**Fastest check**  
Check the Microsoft 365 Service Health dashboard for any active Copilot incidents, and simultaneously review the audit log for any changes to the Legal security group or Copilot licence assignments in the last 24 hours. Run both checks in parallel — they take under two minutes each.

**Is this actually a Copilot bug?**  
Unclear. A team-wide simultaneous loss does not fit the pattern of a per-user permissions or label issue. A group licence change or a service incident are both credible. Do not conclude product fault until the audit log and service health are both clear.

---

## Ticket 5 — Contract Specialist: Vague, generic answers about contract template clauses

**Likely cause (ranked)**
1. **Sensitivity label restriction** — Contract templates in a legal environment are strong candidates for confidentiality labels that restrict Copilot from processing document content. If the majority of the templates library is labelled at a restricting level, Copilot falls back to generic LLM responses because no retrievable content is available to it.
2. **Data indexing lag** — If the contract templates library was recently migrated, restructured, or if the specialist was recently granted access to it, the Microsoft Search index for that content may be shallow or incomplete.
3. **Permissions/access boundary** — If access was granted via a broad inherited permission rather than named group membership, indexing of accessible content can be less reliable.

**Fastest check**  
Go to SharePoint and use the search bar to search for a specific phrase from a contract template the specialist knows exists. If SharePoint Search finds it, the index is fine and labels are the likely cause. If SharePoint Search returns nothing, the index is the problem.

**Is this actually a Copilot bug?**  
No. Generic responses when document-grounded answers are expected are almost always a label or indexing issue. There is no evidence of a product fault from this ticket.

---

## Triage Summary

| ID | User | Primary Cause | Bug? | Priority Action |
|----|------|---------------|------|-----------------|
| 1 | Paralegal | Permissions/access boundary | No | Confirm access denied in browser; advise user to request access through the correct channel |
| 2 | New associate | Indexing lag / licence propagation | No | Check licence assignment date; advise 24–72 hr wait |
| 3 | Partner | Permissions oversharing — working as designed | No | **Escalate immediately to matter supervisor and InfoSec; review and restrict folder permissions** |
| 4 | Legal ops manager | Group licence change or service incident | Unclear | Check service health dashboard and audit log for group/licence changes in last 24 hrs |
| 5 | Contract specialist | Sensitivity label restriction or indexing lag | No | Test with SharePoint Search to distinguish index vs label cause |

---

> **Ticket 3 requires immediate escalation.** In a legal context, a partner accessing a draft settlement from an unrelated matter — even inadvertently — raises privilege and professional conduct concerns that go beyond IT. It should not sit in the support queue.

*Triage principle applied: Genuine Copilot product fault was not the primary diagnosis for any ticket. Ticket 4 carries an "Unclear" rating pending service health and audit log checks.*
