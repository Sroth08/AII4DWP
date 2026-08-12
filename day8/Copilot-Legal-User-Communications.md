# Microsoft 365 Copilot — User Communications (Legal Team)

**From:** IT Support / Endpoint Engineering  
**To:** Individual users (see each section)  
**Date:** 2026-08-12  

---

## Ticket 1 — Paralegal: Copilot won't summarise the client NDA

**To:** Paralegal  
**Subject:** Copilot and the Client NDA — What's Happening and What to Do

Hi,

Thank you for getting in touch. We have looked into this and want to explain what is going on.

When Copilot says "I don't have access to that content", it is telling you something important: it cannot reach a file unless you personally have permission to open it. You mentioned you heard about this folder in a meeting but have not actually opened it before — which suggests your account may not currently have access to it.

This is not a Copilot problem. It is simply that Copilot can only work with files you are already authorised to see.

**What to do next:**

1. Try navigating to the folder directly in SharePoint. If you see an "Access Denied" message, that confirms you do not have access to it yet.
2. If you need access to this folder as part of your work, please contact your matter supervisor or team lead and ask them to request access for you through the normal channel.
3. Once access has been granted and confirmed, try Copilot again — it should be able to help you at that point.

If you do have access and are still seeing the error, please reply to this message and we will investigate further.

---

## Ticket 2 — New Associate: Copilot can't find case emails

**To:** New Associate  
**Subject:** Copilot in Outlook — What to Expect in Your First Week

Hi, and welcome to the team.

This is completely normal for a new account and nothing to worry about. Here is what is happening:

Copilot works by reading an index — a behind-the-scenes searchable copy of your emails and calendar that Microsoft 365 builds automatically. Because your account is brand new, that index is still being built. Until it is ready, Copilot has very little to work with, which is why it cannot find the emails you are looking for.

**What to do next:**

1. Give it 24 to 72 hours. That is the typical time it takes for a new account's mailbox to be fully indexed.
2. After that, try asking Copilot something simple — for example: *"Summarise my emails from the last two days"* — and see if it responds with your actual content.
3. If it is still not working after 72 hours, please reply to this message and we will check that your Copilot licence is fully set up on our end.

No action needed from you right now — just give it a little time and it should sort itself out.

---

## Ticket 3 — Partner: Copilot surfaced a document from a matter you are not assigned to

**To:** Partner  
**Subject:** Important — Regarding the Document Copilot Surfaced

Hi,

Thank you for flagging this straight away. You did exactly the right thing by reporting it.

We want to be clear: Copilot has not done anything wrong here, and neither have you. Copilot can only show you files your account already has permission to access. The fact that it surfaced this document means your account has read access to that folder — most likely through permissions that were set up some time ago and not reviewed since. Copilot made that existing access visible; it did not create it or bypass any controls.

However, this is something we need to act on promptly. In a legal environment, access to documents from matters you are not assigned to — even accidental access — needs to be reviewed and corrected. We are treating this as a permissions finding and escalating it accordingly.

**What we need from you:**

1. Please do not share, copy, or act on the content of that document.
2. If you can, note the name and location of the file (or a brief description) and reply to this message — this will help us identify the folder quickly.
3. We will review the permissions, restrict access appropriately, and let you know once it is resolved.

We are also notifying the matter supervisor and the Information Security team so they are aware.

Thank you again for reporting this — it is genuinely helpful and means we can fix the underlying issue before it becomes a larger problem.

---

## Ticket 4 — Legal Ops Manager: The whole Legal team has lost Copilot access

**To:** Legal Ops Manager  
**Subject:** Legal Team Copilot Outage — What We Are Doing

Hi,

We have picked this up as a priority. A sudden loss of access for the whole team at once is unusual and we are investigating it now.

The most likely cause is a change to the group or licence setup that took effect overnight — for example, the Legal team's group may have been updated in a way that accidentally affected Copilot access. We are also checking whether Microsoft has reported any issues on their end this morning.

**What we are doing right now:**

1. Checking Microsoft's service status page for any active Copilot issues affecting our organisation.
2. Reviewing the admin activity log for any changes made to the Legal team's group or licence settings in the last 24 hours.

**What you can ask the team to try in the meantime:**

- Sign out of all Microsoft 365 apps completely (Outlook, Teams, Word) and sign back in, then test Copilot again. If a licence was recently adjusted, a fresh sign-in sometimes picks up the change.

We will update you as soon as we have identified the cause. If this turns out to be a Microsoft service issue, we will share the incident reference and expected fix time. We aim to have an update to you within the hour.

---

## Ticket 5 — Contract Specialist: Copilot gives generic answers about contract template clauses

**To:** Contract Specialist  
**Subject:** Copilot and the Contract Templates Library — What's Happening

Hi,

Thank you for raising this. If Copilot is giving you generic answers instead of referencing the actual content of your contract templates, there are a couple of likely reasons — and some quick things we can try to narrow it down.

**What is probably happening:**

Either the template documents carry a confidentiality classification that prevents Copilot from reading their contents (even though you can open them yourself), or the templates library has not yet been fully indexed for your account — meaning Copilot simply cannot find the documents to draw on.

**What you can do to help us find out which one it is:**

1. Go to the contract templates library in SharePoint and use the search bar at the top to search for a word or phrase you know appears in one of the templates. Does it appear in the search results?
   - **If yes:** The index is fine — the issue is likely a label restriction. Reply to this message and we will check the classification settings on that library.
   - **If no:** The search index is the problem. Let us know and we will investigate why your account is not returning results from that library.

2. In the meantime, there is a workaround that often helps: open a specific template document directly in Word, then use Copilot from *within that document* — for example, ask it to *"summarise the key clauses in this document"* or *"find any references to termination conditions in this file."* This approach works even when Copilot cannot find the document on its own.

Please reply with what you find from step 1 and we will take it from there.

---

*These communications were prepared by IT Endpoint Engineering. If you have further questions after reading your message above, please reply to your original support ticket or contact the IT helpdesk.*

*FinBridge IT Endpoint Engineering — 2026-08-12*
