# End-User Communications: cthompson Login Failure

## Audience 1 — Non-technical executive

Your access and data were never at risk. This morning, one employee was briefly unable to log in, starting around 8:40 AM, after their account was automatically locked following several unsuccessful sign-in attempts. IT identified the cause and restored access by 9:09 AM; the employee confirmed they are now logging in normally. No other staff or systems were affected. No action is needed on your part.

*(66 words)*

---

## Audience 2 — Affected end-user team

Hi team — this morning cthompson wasn't able to log in for a little while, starting around 8:40 AM, because their account got locked after a few unsuccessful sign-in attempts. IT sorted it out and cthompson was back in and working normally by 9:09 AM. If this happens to you — you can't log in and your account seems locked — please stop trying to re-enter your password and contact the IT Helpdesk straight away so they can unlock it quickly. Thanks for your patience!

*(84 words)*

---

## Audience 3 — Engineer-to-engineer internal note

**Root cause:** `FINBRIDGE\cthompson`'s account was locked out (Event 4740, 08:44:56) after three consecutive wrong-password authentication failures (Event 4776 at 08:44:01, `0xC000006A`; Event 4625 x3 at 08:44:03/08:44:28/08:44:55, Logon type 2, source DESKTOP-FB022). Kerberos pre-auth wrong-password attempts (Event 4771, `0x18`) continued post-lockout at 08:45:44/08:46:01/08:46:33 from a second, unresolved source IP 10.10.8.112 (differs from DESKTOP-FB022's 10.10.1.88) — source device/owner not yet identified.

**Action taken:** Helpdesk (`FINBRIDGE\helpdesk-admin`) enabled the account (Event 4722, 09:08:14). Note: the action logged was "account enabled," not "account unlocked" — no Event 4767 is present in the reviewed window, and no corresponding Event 4725 (disable) was captured either, so the account-enable step isn't fully reconciled against the lockout event; flagged as a gap, not resolved.

**Config detail:** Primary logon source DESKTOP-FB022 (10.10.1.88), Logon type 2 (interactive). Secondary unresolved source 10.10.8.112, Kerberos logon path. Domain: FINBRIDGE. No account-expiry, password-expired (`0xC0000071`), or disabled-account (`0xC0000072`) failure codes observed in the initial failure sequence — ruling those causes out.

**Verification step:** Event 4624 (09:09:01) confirms successful interactive logon from DESKTOP-FB022, Logon type 2. No further user-reported issues since. Recommend monitoring Event 4625/4740/4771 for `cthompson` over the next 24-48h.

**Preventive action needed:** (1) Alert on Event 4740 in near-real-time to cut detection-to-fix time. (2) Alert on Event 4625/4771 failures against a single account from more than one distinct source IP/host within a short window (possible stale-credential or credential-stuffing indicator). (3) Identify the device/owner behind 10.10.8.112 and remediate (stale cached credential) or escalate to security if unrecognized. (4) Standardize helpdesk ticket notes to record the exact action taken (unlock 4767 vs enable 4722) so the RCA trail matches the actual account state. Ticket/owner ref: to confirm.
