# Root Cause Analysis (RCA): cthompson Login Failure

## Document Control
- Incident type: Single-user login failure
- Affected scope: `FINBRIDGE\cthompson` only — no other users reported affected
- Review window: 08:44-09:09 (incident), resolved 09:09
- Source host in events: DESKTOP-FB022; secondary unresolved source IP 10.10.8.112
- Analyst role: DWP Endpoint Analyst
- Date of analysis: 2026-08-06

## Executive Summary
`FINBRIDGE\cthompson` was unable to log in from ~08:40. Security event log review showed three consecutive wrong-password authentication failures against DESKTOP-FB022 (08:44:03-08:44:55), resulting in an account lockout at 08:44:56. Wrong-password Kerberos pre-authentication failures continued after the lockout from a second, unexplained source IP (10.10.8.112) at 08:45:44-08:46:33. Helpdesk remediation enabled the account (Event 4722) at 09:08:14, and cthompson successfully logged on from DESKTOP-FB022 at 09:09:01 (Event 4624). No other users were affected and no infrastructure change was in place, confirming this as an isolated, account-specific incident. Total time to resolution: ~29 minutes.

Root cause: `FINBRIDGE\cthompson`'s account was locked out following repeated wrong-password authentication attempts; resolution required helpdesk to enable the account before login succeeded.

## Scope Facts
- Symptom: User cthompson unable to log in.
- Who: cthompson only — no other users reported affected.
- Since: ~08:40 this morning.
- Change: Nil (no known/logged change).
- Resolution confirmed: 09:09 — user verified logging in to DESKTOP-FB022, no issues reported.

## What Each Event ID Records

### Event ID 4776 (Security) - Credential Validation
Records a domain controller's attempt to validate credentials for an account, with an error code identifying the failure reason (e.g., wrong password).

### Event ID 4625 (Security) - Failed Logon
Records a failed logon attempt, including account name, failure reason, logon type, and source workstation.

### Event ID 4740 (Security) - Account Locked Out
Records that a user account was locked out, and the caller computer that triggered the lockout.

### Event ID 4771 (Security) - Kerberos Pre-Authentication Failed
Records a failed Kerberos pre-authentication attempt, including a failure code and source IP address.

### Event ID 4722 (Security) - User Account Enabled
Records that a previously disabled account was re-enabled, and by whom.

### Event ID 4624 (Security) - Successful Logon
Records a successful logon, including account, logon type, and source.

## Timeline

| Time | Host/Source | Event | Detail |
|---|---|---|---|
| ~08:40 | DESKTOP-FB022 | Reported | cthompson first unable to log in |
| 08:44:01 | DESKTOP-FB022 | Event 4776 | Credential validation failed, `0xC000006A` (wrong password) |
| 08:44:03 | DESKTOP-FB022 | Event 4625 | Bad password, Logon type 2 (Interactive) |
| 08:44:28 | DESKTOP-FB022 | Event 4625 | Bad password, second attempt |
| 08:44:55 | DESKTOP-FB022 | Event 4625 | Bad password, third attempt |
| 08:44:56 | DESKTOP-FB022 | Event 4740 | Account locked out, caller computer DESKTOP-FB022 |
| 08:45:10 | DESKTOP-FB022 | Event 4625 | Failure reason "Account locked out", Logon type 7 (Unlock attempt) |
| 08:45:44 | 10.10.8.112 | Event 4771 | Kerberos pre-auth failed, `0x18` (wrong password), source IP differs from DESKTOP-FB022 (10.10.1.88) |
| 08:46:01 | 10.10.8.112 | Event 4771 | Kerberos pre-auth failed, second attempt |
| 08:46:33 | 10.10.8.112 | Event 4771 | Kerberos pre-auth failed, third attempt |
| 09:08:14 | — | Event 4722 | Account `FINBRIDGE\cthompson` enabled by `FINBRIDGE\helpdesk-admin` |
| 09:09:01 | DESKTOP-FB022 | Event 4624 | Successful logon, Logon type 2 (Interactive) |

## Hypothesis Elimination Summary
Five candidate causes were ranked from initial scope facts and tested against event log evidence:

1. **Account lockout** — Supported. Event 4740 at 08:44:56, preceded by three consecutive Event 4625 bad-password failures (08:44:03, 08:44:28, 08:44:55) and confirmed by the 08:45:10 Event 4625 "Account locked out".
2. **Password expired** — Contradicted. Failure codes throughout (`0xC000006A`, "Unknown user name or bad password") are wrong-password codes, not expired-password codes (e.g. `0xC0000071`).
3. **Disabled or expired account** — Contradicted at the time of the initial failures (0xC000006A/bad password, not `0xC0000072`/disabled or `0xC0000193`/expired). Note: the eventual fix (Event 4722, "account enabled") shows the account was, at some point, in a disabled state — see Additional Finding below.
4. **Credential/cache issue on cthompson's specific device** — Neutral-to-contradicted. Initial failures originate from DESKTOP-FB022, but the 08:45:44-08:46:33 Event 4771 wrong-password failures come from a different source IP (10.10.8.112) after lockout, showing the pattern is not confined to one device.
5. **Conditional Access / MFA / group policy restriction** — Contradicted. All entries are on-prem AD password/Kerberos failure codes; no MFA challenge or policy-block event is present.

## Detailed 5-Why Analysis

### Problem Statement
`FINBRIDGE\cthompson` was unable to log in to DESKTOP-FB022 from ~08:40 until remediated at 09:09.

### Why 1
Why couldn't cthompson log in?
- Because the account became locked out.
- Evidence: Event 4740 at 08:44:56, and the 08:45:10 Event 4625 with failure reason "Account locked out".

### Why 2
Why did the account lock out?
- Because three consecutive wrong-password authentication attempts were submitted against it within under a minute.
- Evidence: Event 4776 (08:44:01) and Event 4625 (08:44:03, 08:44:28, 08:44:55), all failure reason "wrong password"/"bad password".

### Why 3
Why were wrong-password attempts being submitted?
- Not fully confirmed. The first three attempts came from DESKTOP-FB022 (logon type 2, interactive), consistent with a manually mistyped or stale cached password. However, three further wrong-password Kerberos attempts (08:45:44-08:46:33) came from a second source IP (10.10.8.112), not DESKTOP-FB022, after the account was already locked — indicating a second, unidentified source was also submitting the wrong password.
- Evidence: Event 4771 x3, source IP 10.10.8.112, differing from DESKTOP-FB022's 10.10.1.88.

### Why 4
Why was the second source (10.10.8.112) submitting the wrong password?
- Not confirmed from available evidence — this requires follow-up (e.g., device identification, Credential Manager/mapped-drive/scheduled-task review, or a possible external/credential-stuffing attempt). No data in the current log identifies this host.
- Evidence: No hostname, device type, or owner is present in the log; flagged as an open item, not resolved by this incident.

### Why 5
Why did resolution require the account to be enabled (Event 4722) rather than simply unlocked?
- Not fully confirmed from available evidence. Event 4722 specifically records reversing a disabled state, not a lockout — no Event 4725 (account disabled) or 4767 (account unlocked) entry was provided in the log. This suggests either the account was independently disabled at some point outside the reviewed window, or "Enable Account" was used by helpdesk as part of a standard remediation bundle regardless of the specific locked/disabled state.
- Evidence: Event 4722 at 09:08:14, "A user account was enabled", actioned by `FINBRIDGE\helpdesk-admin`.

## Root Cause
Primary root cause: `FINBRIDGE\cthompson`'s account was locked out at 08:44:56 following three consecutive wrong-password authentication attempts from DESKTOP-FB022. The account remained inaccessible until helpdesk enabled it (Event 4722) at 09:08:14, after which login succeeded (Event 4624) at 09:09:01.

Unresolved element: the mechanism producing the wrong-password attempts — particularly the three further attempts from unidentified source IP 10.10.8.112 after lockout, and why the remediation action was an account "enable" rather than an "unlock" — is not confirmed by the available evidence and is carried forward as an open follow-up.

## Contributing Factors
- No visibility into what device/service 10.10.8.112 corresponds to, preventing confirmation of whether a stale cached credential, a second device, or an external actor caused the repeated wrong-password attempts.
- No Event 4725 (account disabled) or 4767 (unlock) entry was captured/provided, leaving a gap between the lockout event and the enable action used to resolve it.
- Reliance on user-reported symptom to identify the incident, rather than proactive lockout alerting.

## Corrective Actions Taken
- Helpdesk enabled `FINBRIDGE\cthompson`'s account (Event 4722, 09:08:14).
- User confirmed able to log in to DESKTOP-FB022 (Event 4624, 09:09:01).
- No issues reported since resolution.

## Preventive Actions
1. Detection and alerting:
   - Alert on Event 4740 (account lockout) in near-real-time so lockouts are caught and triaged before the affected user needs to report the issue.
   - Alert on repeated Event 4625/4771 failures against a single account from multiple distinct source IPs/hosts within a short window, as a possible indicator of a stale credential or credential-stuffing attempt.

2. Investigation follow-up:
   - Identify the device/service behind source IP 10.10.8.112 and determine why it was submitting the old/wrong password for cthompson; remediate the stale credential if found, or escalate to security if unrecognized.
   - Confirm whether the account was administratively disabled at any point before 09:08:14, to close the gap between the lockout (4740) and the enable action (4722).

3. Process improvement:
   - Standardize helpdesk remediation steps for lockout tickets to record explicit unlock (4767) vs enable (4722) actions taken, so the RCA trail matches the account state precisely.

## Validation and Closure Criteria
- Confirm no further Event 4625/4740/4771 entries for `FINBRIDGE\cthompson` in the next monitoring window.
- Confirm the identity and legitimacy of source IP 10.10.8.112 before fully closing the incident.
- Status: Resolved and verified at 09:09 — user logging in to DESKTOP-FB022, no issues reported (follow-up on secondary source IP still open).

## Limitations of Current Evidence
- Only the 08:44-09:12 event log excerpt was reviewed; no logs outside this window were available.
- No Event 4725 (account disabled) was provided, so the exact point at which the account became disabled (if distinct from the lockout) is unconfirmed.
- Source IP 10.10.8.112 could not be resolved to a device/owner from the data provided.
- No confirmation yet of whether cthompson's password was recently changed, which would explain a stale cached credential as the trigger for the wrong-password attempts.

Despite these limitations, the event evidence clearly and consistently supports account lockout (driven by repeated wrong-password attempts) as the proximate cause of the login failure, with the account-enable action and successful logon confirming resolution at 09:09.
