# Root Cause Analysis (RCA): jsmith Account Lockout Incident

## Document Control
- Incident type: User account lockout
- User account: jsmith
- Review window: 08:02:14 to 08:23:44 (about 22 minutes inside provided 30-minute window)
- Source host in events: DESKTOP-FB001
- Analyst role: DWP Endpoint Analyst
- Date of analysis: 2026-08-05

## Executive Summary
During the reviewed window, user `jsmith` entered incorrect credentials multiple times at the local workstation sign-in screen. Those failures triggered an account lockout event. A later unlock attempt failed because the account was still locked. Helpdesk then re-enabled/unlocked the account, after which the user logged on successfully with interactive logon.

Most likely cause: repeated bad password attempts on `DESKTOP-FB001` (likely mistyped password and/or stale remembered password at console), which exceeded lockout threshold and caused automatic lockout.

## What Each Event ID Records

### Event ID 4625 (Audit Failure) - Failed Logon
Records a failed authentication attempt. Key fields include account name, failure reason/status, source workstation, and logon type.

In this incident:
- 08:02:14: Failed interactive sign-in (`Logon Type 2`) for `jsmith` from `DESKTOP-FB001` with reason `Unknown username or bad password`.
- 08:04:22: Another failed interactive sign-in (`Logon Type 2`) for `jsmith` from `DESKTOP-FB001` with the same bad password reason.
- 08:07:45: Failed unlock attempt (`Logon Type 7`) for `jsmith` from `DESKTOP-FB001` with reason `Account locked out`.

### Event ID 4740 (Audit Failure) - Account Locked Out
Records that an account was locked due to lockout policy threshold being met. Includes the target account and the computer name where the triggering attempt came from.

In this incident:
- 08:06:01: `jsmith` account locked out. Calling computer: `DESKTOP-FB001`.

### Event ID 4722 (Audit Success) - Account Enabled/Unlocked by Admin Action
Records that an account was enabled by an administrator (often appears during lockout remediation workflows depending on domain tooling/process).

In this incident:
- 08:22:10: `jsmith` account enabled by `FINBRIDGE\helpdesk-admin`.

### Event ID 4624 (Audit Success) - Successful Logon
Records a successful authentication/logon, including logon type.

In this incident:
- 08:23:44: Successful interactive logon (`Logon Type 2`) for `jsmith`.

## Reconstructed Sequence (Plain English)
1. At 08:02, the user tried to sign in at the machine console and entered credentials that were not accepted (bad password).
2. At 08:04, the user tried again at the console and failed for the same reason.
3. By 08:06, enough failed attempts had occurred to hit account lockout policy, and the account became locked.
4. At 08:07, the user attempted to unlock/sign in again, but this failed because the account was already locked.
5. At 08:22, helpdesk administrator `FINBRIDGE\helpdesk-admin` enabled/unlocked the account.
6. At 08:23, the user signed in successfully at the console.

## Most Likely Cause With Evidence

### Most Likely Cause
Repeated invalid password attempts from `DESKTOP-FB001` caused domain/local account lockout per configured lockout policy.

### Evidence
- Multiple failed logons for `jsmith` with bad password reason:
  - 08:02:14, Event 4625, Logon Type 2, source `DESKTOP-FB001`.
  - 08:04:22, Event 4625, Logon Type 2, source `DESKTOP-FB001`.
- Explicit lockout event:
  - 08:06:01, Event 4740, account locked out, called from `DESKTOP-FB001`.
- Post-lockout failed unlock confirms locked state:
  - 08:07:45, Event 4625, Logon Type 7, failure reason `Account locked out`.
- Admin intervention and recovery:
  - 08:22:10, Event 4722 by `FINBRIDGE\helpdesk-admin`.
  - 08:23:44, Event 4624 successful interactive logon.

### Why this is the strongest conclusion
All relevant failures and lockout attribution point to the same endpoint (`DESKTOP-FB001`) in a tight sequence, and no alternate source host is shown. The account immediately works after helpdesk action, which is consistent with lockout remediation rather than account disablement from security compromise.

## Detailed 5-Why Analysis

### Problem Statement
`jsmith` was locked out and unable to access the machine during the incident window.

### Why 1
Why was `jsmith` unable to sign in?
- Because the account became locked (Event 4740 at 08:06:01), and subsequent unlock attempt failed with `Account locked out` (Event 4625, Logon Type 7 at 08:07:45).

### Why 2
Why did the account become locked?
- Because repeated failed authentication attempts exceeded the account lockout threshold.
- Evidence: two explicit bad-password failures are logged before lockout (08:02:14 and 08:04:22), and lockout event follows from same endpoint.

### Why 3
Why were there repeated failed authentication attempts?
- Most likely the user entered an incorrect password multiple times at console logon/unlock.
- Alternate but less provable possibility: a stale cached credential in a local process at sign-in.
- Evidence weighting favors manual console attempts because failures are `Logon Type 2` and `Logon Type 7` from the same desktop.

### Why 4
Why did this lead to service interruption instead of quick self-recovery?
- Because lockout policy enforcement prevents further attempts until admin action or lockout duration expiry.
- Helpdesk had to intervene (`FINBRIDGE\helpdesk-admin` at 08:22:10), delaying restoration.

### Why 5
Why is this pattern recurring risk in endpoint environments?
- Users may not have immediate visibility into remaining attempts before lockout.
- Sign-in UX and support guidance may not direct users early enough to password reset or verification steps.
- Operational controls may rely on manual helpdesk unlock rather than self-service password workflows.

## Root Cause
Primary root cause: repeated invalid password submissions for `jsmith` at `DESKTOP-FB001` triggered account lockout policy.

## Contributing Factors
- User uncertainty about current password validity (possible typo/stale memory).
- No evidence in provided sample of proactive warning before threshold reached.
- Dependency on helpdesk action for recovery (admin unlock path).

## Corrective Actions Taken
- Helpdesk re-enabled/unlocked account at 08:22:10 (Event 4722).
- User successfully logged on at 08:23:44 (Event 4624).

## Preventive Actions
1. User-side:
- Encourage immediate password verification/reset after first failed attempts.
- Provide quick reference for lockout-safe troubleshooting steps.

2. Helpdesk process:
- Standardize lockout triage checklist: verify source host, failed logon types, and recent password changes.
- Capture and trend lockout incidents by endpoint and user.

3. Policy and tooling:
- Evaluate whether lockout threshold and lockout duration are balanced for security vs usability.
- Consider self-service unlock/reset flows where policy allows.
- Add endpoint guidance banner after repeated failures (if supported by environment tooling).

## Validation and Closure Criteria
- Confirm no additional 4625 failures for `jsmith` from `DESKTOP-FB001` in next monitoring window.
- Confirm user can log on and unlock session successfully.
- Confirm no lockout recurrence within agreed observation period.

## Limitations of Current Evidence
- Only a subset of events for a 30-minute window was provided.
- No full status/substatus codes or AD policy values were provided.
- No corroborating logs from identity provider, VPN, or credential manager were provided.

Despite these limitations, available events are internally consistent and strongly support bad-password lockout originating from `DESKTOP-FB001`.
