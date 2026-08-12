# Microsoft 365 Copilot — Support Ticket Triage

**Triaged by:** Endpoint Engineering  
**Date:** 2026-08-12  
**Triage rule:** Default to non-Copilot causes unless evidence genuinely rules them all out. Genuine Copilot fault is always last resort.

---

## Ticket 1 — Finance lead: Copilot won't summarise the Q3 board pack in SharePoint. "It's right there, I can see it myself."

**Likely cause (ranked)**

1. **Sensitivity label restriction** — Board packs in a Finance environment are the most probable candidate for a Highly Confidential or equivalent label that restricts Copilot processing. The file being visually accessible in the browser does not mean Copilot is permitted to process its content; label-based Copilot restrictions operate independently of read access.
2. **Permissions/access boundary** — The user may have read access via a direct link or inherited permission that does not surface in the file's effective permissions as a named member. Copilot evaluates the permission model, not the user's ability to open a file in browser.
3. **Data indexing lag** — If the board pack was recently uploaded or moved, the Microsoft Search index may not yet have processed it for Copilot retrieval.

**Fastest check**  
Open the file in SharePoint and check the sensitivity label displayed in the document header or the Information Protection bar. If it carries a Highly Confidential or Restricted label, that is the cause — no further investigation needed before escalating to the Purview/Compliance team.

**Is this actually a Copilot bug?**  
No. "I can see it" confirms browser read access only. Sensitivity label restrictions and permission boundary evaluations are by design. There is no evidence of a product fault.

---

## Ticket 2 — New hire (started yesterday): Copilot in Outlook seems to know nothing about my recent emails.

**Likely cause (ranked)**

1. **Licence/client prerequisite issue** — The Copilot add-on licence may not yet have been assigned to the new hire's account, or was assigned too recently for the service plan to have fully propagated.
2. **Data indexing lag** — Even with a licence correctly assigned, a brand-new mailbox with less than 24 hours of email has minimal content indexed. Copilot's Outlook grounding depends on the Microsoft Search mailbox index, which builds over time. A mailbox created yesterday will have an extremely thin index.
3. **Permissions/access boundary** — If the account was provisioned from a template with a non-standard Exchange configuration, delegate or policy settings could affect Copilot's mailbox access scope.

**Fastest check**  
Confirm in the Microsoft 365 admin centre that the Copilot add-on licence is assigned and showing as active on this user's account. Licence propagation can take up to 24 hours; check the assigned date.

**Is this actually a Copilot bug?**  
No. A new mailbox with near-zero indexed content behaving as if it "knows nothing" is expected. This is not a fault.

---

## Ticket 3 — HR manager: Asked Copilot in Word to pull data from a sensitive salary review spreadsheet, got "I don't have access to that content."

**Likely cause (ranked)**

1. **Sensitivity label restriction** — A salary review spreadsheet is exactly the type of document an organisation would label Highly Confidential — HR or equivalent. Labels configured to block Copilot processing will produce this exact error message regardless of the user's file access.
2. **Permissions/access boundary** — The HR manager may not have direct permissions to the file; they may have reached it previously via a sharing link that Copilot does not follow in the same way a browser does.
3. **Data indexing lag** — If the spreadsheet is stored in a location not yet fully indexed (e.g. recently created SharePoint library), Copilot cannot retrieve it.

**Fastest check**  
Check the sensitivity label on the spreadsheet. Then verify in SharePoint or OneDrive that the HR manager is a named member (or member of a group) with explicit access — not solely via a sharing link.

**Is this actually a Copilot bug?**  
No. The error message "I don't have access to that content" is a deliberate Copilot response when label or permission controls block processing. This is the system working as designed.

---

## Ticket 4 — Sales rep: Copilot in Teams can't find a client contract that was shared with her via a guest link from another org.

**Likely cause (ranked)**

1. **Guest/external sharing limitation** — Copilot does not index content shared via external guest links from another organisation's tenant. The file lives in the external org's SharePoint; Copilot operates within the boundaries of the user's own tenant index. This is a documented architectural limitation, not a bug.
2. **Permissions/access boundary** — Even if the file were in the home tenant, a guest-link share may not translate to the type of indexed permission that Copilot can act on.

**Fastest check**  
Confirm where the file lives: ask the sales rep to click the sharing link and check the URL domain. If it resolves to another organisation's SharePoint domain (e.g. `contoso.sharepoint.com` when her org is `fabrikam`), Copilot cannot reach it — by design.

**Is this actually a Copilot bug?**  
No. Cross-tenant guest link content is outside Copilot's indexing boundary. This is expected behaviour and should be communicated to the user as a platform limitation, not a fault to be raised.

---

## Ticket 5 — IT admin: Copilot suddenly stopped working for the whole Finance team this morning, was fine yesterday.

**Likely cause (ranked)**

1. **Licence/client prerequisite issue** — A bulk licence change, group membership change, or an Entra ID group-based licence assignment error affecting the Finance security group is the most probable cause of a sudden, team-wide outage. Check for any admin activity in the last 24 hours affecting the Finance group or the Copilot service plan.
2. **Permissions/access boundary** — A Conditional Access policy change or an Entra ID group modification could have altered what the Finance team can access, including Copilot service plans.
3. **Genuine Copilot fault** — A tenant-level or service-level incident affecting a specific group is unusual but possible. Should be checked against the Microsoft 365 Service Health dashboard only after licence and group changes are ruled out.

**Fastest check**  
Go to the Microsoft 365 admin centre → Service health → Microsoft 365 Copilot and check for any active incidents. Simultaneously check the audit log for any licence assignment or Entra ID group changes made in the last 24 hours affecting the Finance group.

**Is this actually a Copilot bug?**  
Unclear. A sudden team-wide failure is unusual for a permissions or label issue (those tend to be per-user or per-file). A service health incident or a group-level licence change are both credible. Do not assume a Copilot product fault until licence/group changes and the service health dashboard are both checked and clear.

---

## Ticket 6 — Manager: Copilot found and summarised a file I don't remember ever opening, from a folder I forgot I had access to.

**Likely cause (ranked)**

1. **Permissions/access boundary** — This is not a fault; it is Copilot functioning exactly as designed. The manager has read access to the folder (likely inherited, legacy, or role-based) and Copilot surfaced content within that access boundary. The user's surprise is a user-awareness issue, not a product issue.

**Fastest check**  
Navigate to the file's SharePoint location and review the permissions panel. Confirm the manager has explicit or inherited access. Document this as evidence of a permissions oversharing finding — this is precisely the scenario the pre-deployment permissions audit was designed to prevent.

**Is this actually a Copilot bug?**  
No. This is Copilot working correctly. However, this ticket should be **escalated as a permissions oversharing finding** to the data owner and Information Security immediately — especially in a Finance environment. If the file contains sensitive data the manager should not have access to, the permissions must be remediated. Copilot did not cause the access problem; it made it visible.

---

## Ticket 7 — Analyst: Copilot gives generic answers, doesn't seem to use any of our internal SharePoint content at all.

**Likely cause (ranked)**

1. **Data indexing lag** — The analyst's accessible SharePoint content may not be fully indexed by Microsoft Search, particularly if they were recently added to site permissions, recently migrated, or are accessing content via indirect/inherited permissions that index more slowly.
2. **Permissions/access boundary** — If the analyst's SharePoint access is primarily via broadly-inherited permissions rather than named group membership, Microsoft Search may have a shallow index for their accessible content scope.
3. **Licence/client prerequisite issue** — If the Copilot licence was recently assigned, the full grounding capability (particularly for SharePoint) can take 24–72 hours to fully activate.
4. **Sensitivity label restriction** — If the majority of Finance SharePoint content carries labels that restrict Copilot processing, the analyst would experience exactly this: Copilot falling back to generic LLM responses because no retrievable content is available.

**Fastest check**  
Open Microsoft Search in SharePoint (`sharepoint.com/_layouts/15/search.aspx`) and search for a document the analyst knows exists and has access to. If Search returns it, the index exists and the issue is likely label-based. If Search returns nothing, the index is the problem — check licence assignment date and Microsoft 365 indexing status.

**Is this actually a Copilot bug?**  
No. Generic responses when SharePoint content is expected are almost always an indexing, permissions, or label issue. There is no evidence of a product fault from this ticket description.

---

## Ticket 8 — Executive assistant: Copilot in Outlook can't see a shared mailbox's calendar that I manage on behalf of my director.

**Likely cause (ranked)**

1. **Permissions/access boundary** — Copilot in Outlook operates on the signed-in user's own mailbox context. Delegate access and "on behalf of" permissions are a different access model; Copilot does not automatically extend its grounding to shared mailboxes or delegate calendars in the same way a user manually navigating Outlook can.
2. **Licence/client prerequisite issue** — The shared mailbox itself does not hold a Copilot licence. Copilot cannot act as or on behalf of an unlicensed mailbox, even if the EA has delegate rights.

**Fastest check**  
Confirm whether the EA is trying to use Copilot *within* the shared mailbox context (opened as a separate mailbox in Outlook) or from their own primary mailbox. Copilot functions in the signed-in user's mailbox scope. Delegate/shared mailbox Copilot support is limited — check the current Microsoft documentation for the exact shared mailbox support boundary as this has changed across Copilot releases.

**Is this actually a Copilot bug?**  
No. Shared mailbox and delegate calendar access in Copilot is a known scope limitation, not a product defect. The EA should be advised that Copilot operates in their own mailbox context and directed to the current Microsoft support article on shared mailbox behaviour in Copilot for M365.

---

## Triage Summary

| ID | Primary Cause | Copilot Bug? | Action |
|----|---------------|--------------|--------|
| 1 | Sensitivity label restriction | No | Check label on board pack; escalate to Purview team if confirmed |
| 2 | Indexing lag / licence propagation | No | Check licence assignment date; advise user to wait 24–72 hrs |
| 3 | Sensitivity label restriction | No | Check label on spreadsheet; verify named permissions |
| 4 | Guest/external sharing limitation | No | Confirm file is in external tenant; advise platform limitation |
| 5 | Licence/group change or service incident | Unclear | Check service health and audit log for group/licence changes in last 24 hrs |
| 6 | Working as designed — permissions oversharing exposed | No | **Escalate as oversharing finding to data owner and InfoSec** |
| 7 | Indexing lag or label restriction | No | Test with SharePoint Search to distinguish index vs label cause |
| 8 | Shared mailbox/delegate scope limitation | No | Check current Microsoft docs on shared mailbox Copilot support boundary |

---

*Triage principle applied: Genuine Copilot product fault was not the primary diagnosis for any ticket. Ticket 5 carries an "Unclear" rating pending service health and audit log checks. Ticket 6 should be treated as a security finding, not a support ticket.*
