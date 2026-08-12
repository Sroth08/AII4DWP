# Microsoft 365 Copilot — User Communications

**From:** IT Support / Endpoint Engineering  
**To:** Individual users (see each section)  
**Date:** 2026-08-12  

---

## Ticket 1 — Finance Lead: Copilot won't summarise the Q3 board pack

**To:** Finance Lead  
**Subject:** Copilot and the Q3 Board Pack — What's Happening and What to Do

Hi,

Thank you for raising this. We understand it's frustrating when you can see a file clearly but Copilot won't engage with it.

Here's what's most likely happening: the board pack has a **sensitivity label** applied to it — a classification tag that tells Microsoft 365 how to handle the document based on how confidential it is. When a document is labelled at a high confidentiality level (such as "Highly Confidential" or "Restricted"), Copilot is intentionally blocked from reading or summarising it. This is a security control, not a fault. The label applies even if you personally have permission to open and read the file.

**What you can do:**

1. Open the document in SharePoint or in the desktop Word/Excel app and look at the label shown at the top of the screen (usually a coloured banner near the toolbar). Note what it says.
2. Reply to this message with the label name you see, and we will check whether that label is correctly applied or whether it needs reviewing.
3. If the label is correct and the restriction is intentional, IT cannot override it — you would need to speak to your data owner or line manager about whether the document needs to be reclassified.

We will follow up once we hear back from you.

---

## Ticket 2 — New Hire: Copilot seems to know nothing about recent emails

**To:** New Starter  
**Subject:** Copilot in Outlook — What to Expect in Your First Few Days

Hi, and welcome to the team.

This is completely normal and nothing to worry about. Here's the simple explanation:

Copilot learns from your emails and calendar by reading an index — essentially a searchable copy of your mailbox that Microsoft 365 builds behind the scenes. Because your account was created very recently, that index is still being built. Until it is ready, Copilot has very little to work with and will appear to "not know" anything about your emails.

**What you can do:**

1. Give it 24 to 72 hours. This is how long the mailbox index typically takes to build for a new account.
2. After that time, try asking Copilot something simple — for example, "Summarise my emails from today" — and see if it responds with your actual content.
3. If it still seems to know nothing after 72 hours, please reply to this message and we will check that your Copilot licence is fully set up on our end.

No action needed from you right now — just give it a little time.

---

## Ticket 3 — HR Manager: "I don't have access to that content" error on a salary spreadsheet

**To:** HR Manager  
**Subject:** Copilot and the Salary Review Spreadsheet — Why You're Seeing That Message

Hi,

The message "I don't have access to that content" sounds like an error, but it is actually Copilot doing exactly what it is supposed to do.

Salary review documents are among the most sensitive files in the organisation. It is very likely that this spreadsheet has been given a high-level sensitivity classification — a label that specifically prevents Copilot from reading, processing, or summarising the content, even for users who are authorised to open the file manually. This is a deliberate protection, not a technical fault.

**What you can do:**

1. Open the spreadsheet and check the sensitivity label shown at the top (usually a coloured banner). Note the label name.
2. Check that you are accessing the file as a named user with direct permissions — not via a link someone sent you. Copilot handles direct permissions differently from shared links.
3. If you believe Copilot should be able to work with this document as part of your role, please raise this with your line manager and your data owner. They would need to review whether the classification level is appropriate.
4. If you just need the data for a specific task right now, you can open the file directly and work with it manually — Copilot restrictions do not affect your ability to open or edit the file yourself.

---

## Ticket 4 — Sales Rep: Copilot can't find a client contract shared via a guest link

**To:** Sales Representative  
**Subject:** Copilot and the Client Contract — Why It Can't See That File

Hi,

We have looked into this and want to explain why Copilot is unable to find the contract.

The file was shared with you via a guest link from another company's system. That means the document lives on **their** Microsoft 365 system, not ours. Copilot can only search and work with files that are stored within our organisation's own environment. It cannot reach across into another company's system, even if you have been given a link to access it.

This is not a bug — it is how Copilot is designed to work, and it is actually an important security boundary.

**What you can do:**

1. To work with the contract using Copilot, you would need a copy of the file saved into our own SharePoint or OneDrive. Please check with the client or your manager whether it is appropriate to save a local copy.
2. If saving a copy is not appropriate (for example, due to confidentiality terms), you will need to review the contract directly via the link you were sent rather than through Copilot.
3. If you need help saving files to the right location in SharePoint, please let us know and we can point you to the right place.

---

## Ticket 5 — IT Admin: Copilot stopped working for the whole Finance team this morning

**To:** IT Admin  
**Subject:** Finance Team Copilot Outage — Investigation Update

Hi,

We have picked this up as a priority given it is affecting the whole Finance team.

A sudden, team-wide loss of Copilot access is most commonly caused by one of two things: a change to the group or licence setup overnight, or a service issue on Microsoft's side. We are checking both.

**What we are doing right now:**

1. Checking the Microsoft 365 Service Health dashboard for any active Copilot incidents affecting our tenant.
2. Reviewing the admin audit log for any changes made to the Finance security group or Copilot licence assignments in the last 24 hours.

**What you can do in the meantime:**

- Ask one or two Finance users to sign out of all Microsoft 365 apps and sign back in, then test Copilot again. Occasionally a licence change takes effect only after a fresh sign-in.
- If you have access to the admin centre, check whether the Finance group still appears as the assigned group for the Copilot service plan under **Billing → Licences → Microsoft 365 Copilot**.

We will update you as soon as we have identified the cause. If this is a Microsoft service incident, we will share the incident reference number and estimated resolution time.

---

## Ticket 6 — Manager: Copilot found a file I didn't expect it to find

**To:** Manager  
**Subject:** Important — About the File Copilot Surfaced

Hi,

Thank you for letting us know about this — and we want to be clear that **you have done the right thing by reporting it**.

What happened is not a Copilot error. Copilot can only show you files you already have permission to access. The fact that it surfaced a file you had forgotten about means that your account has access to a folder or document library that you may not have expected. Copilot made that existing access visible, but it did not create or bypass any permissions.

However, this is something we need to investigate. In a Finance environment, access to certain files and folders should be strictly controlled. If there are files in that location that contain sensitive data — payroll information, financial reports, executive documents — and your account has access it should not have, that is something IT and the data owner need to review and correct.

**What we need from you:**

1. Please do not share, copy, or act on the content of that file if you believe you should not have access to it.
2. Reply to this message with the name and location of the file (or a brief description if you are not sure of the exact path).
3. We will review the permissions on that file and folder and let you know the outcome.

This kind of report is genuinely valuable — it helps us find and fix access issues before they become larger problems. Thank you again for flagging it.

---

## Ticket 7 — Analyst: Copilot gives generic answers, not using internal content

**To:** Analyst  
**Subject:** Copilot Not Using Internal Content — What's Happening

Hi,

If Copilot is giving you generic answers instead of drawing on documents and data from our SharePoint, there are a couple of likely reasons and some quick things we can try.

**The most common causes:**

- The content index for your account is still being built or refreshed. This can happen after a permissions change, a recent migration, or if you were recently added to new SharePoint sites.
- The documents you are asking about may carry a sensitivity classification that prevents Copilot from processing them, even though you can open them.

**What you can do to help us investigate:**

1. Go to our SharePoint and use the search bar at the top to search for a document you know you have access to — something you opened recently. Does it appear in the search results? If yes, let us know. If no, the issue is with how your access is indexed.
2. Think of a specific document you expected Copilot to reference. Open it, and check whether it has a sensitivity label shown at the top of the file.
3. Reply to this message with what you found and we will take it from there.

In the meantime, you can still use Copilot effectively by opening a specific document first and then using Copilot within that document — for example, opening a report in Word and asking Copilot to summarise it from there, rather than asking Copilot to find it.

---

## Ticket 8 — Executive Assistant: Copilot can't see the director's shared mailbox calendar

**To:** Executive Assistant  
**Subject:** Copilot and the Shared Mailbox Calendar — How This Works

Hi,

Thank you for raising this. We want to explain how Copilot handles shared mailboxes and delegate access, as it works slightly differently from what you might expect.

Copilot in Outlook is designed to work within **your own mailbox** — your emails, your calendar, your tasks. When you access your director's shared mailbox or manage their calendar on their behalf, you are doing so as a delegate. Copilot does not currently extend fully into delegate or shared mailbox contexts in the same way that Outlook itself does. This means it may not be able to see or reference calendar items from the shared mailbox even though you can view them manually.

This is a current platform limitation, not a fault with your setup.

**What you can do:**

1. For tasks related to your own mailbox and calendar, Copilot should work normally — try asking it to help with emails or meetings in your primary inbox.
2. For tasks involving the director's calendar specifically, you will need to manage these directly in Outlook for now rather than through Copilot.
3. Microsoft is continuing to develop shared mailbox and delegate support in Copilot. We will communicate any updates when this capability becomes available in our tenant.

If there is a specific task you were hoping Copilot could help with, let us know and we can suggest the best current workaround.

---

*These communications were prepared by IT Endpoint Engineering. If you have further questions after reading your message above, please reply to your original support ticket or contact the IT helpdesk.*
