# Root Cause Analysis (RCA): RDP Authentication Failures and Account Lockout Incident (Exercise)

## Document Control
- Incident type: Remote access authentication / account lockout incident
- Affected service: Remote Desktop (RDP) interactive logon
- Analysis window: 2024-03-15 14:01:02 to 14:22:09
- Primary host context: Windows endpoint/server receiving RDP sessions
- Analyst role: DWP Endpoint Analyst
- Date of analysis: 2026-08-05

## Executive Summary
The same client IP (10.10.5.44) attempted multiple Remote Desktop logons for account FINBRIDGE\bwalker using invalid credentials. Security log Event ID 4625 was generated repeatedly for logon type 10 (RemoteInteractive), culminating in Event ID 4740 account lockout at 14:05:34. After lockout handling and credential correction, the same client established a new TCP session and achieved successful remote interactive sign-in (Event ID 4624) at 14:22:09.

Most likely cause: repeated RDP authentication attempts using an incorrect or stale password from client 10.10.5.44, likely via cached/saved credentials or repeated manual retries, triggered domain lockout policy; once credentials/account state were corrected, login succeeded.

## Event ID Explanations

### Event ID 56 (Source: TermDD)
Records an RDP protocol/security-layer stream error that causes the server to disconnect the client session. This indicates the connection handshake/security exchange was not completed cleanly.

What it shows here:
- Security layer detected protocol-stream error.
- Client 10.10.5.44 was disconnected at 14:01:02.

### Event ID 140 (Source: RemoteDesktopServices-RdpCoreTS)
Records that an incoming RDP connection attempt failed authentication because username/password validation failed.

What it shows here:
- Client 10.10.5.44 failed connection due to invalid username or password.

### Event ID 4625 (Security)
Records a failed logon attempt.

What it shows here:
- Account: FINBRIDGE\bwalker
- Failure reason: Unknown username or bad password
- Logon type: 10 (RemoteInteractive, RDP)
- Source IP: 10.10.5.44
- Repeated at 14:01:04, 14:03:18, and 14:05:33.

### Event ID 4740 (Security)
Records that a user account was locked out.

What it shows here:
- Account FINBRIDGE\bwalker was locked out.
- Caller computer/IP associated with trigger: 10.10.5.44.

### Event ID 131 (Source: RemoteDesktopServices-RdpCoreTS)
Records acceptance of a new incoming TCP connection for RDP.

What it shows here:
- Server accepted a new TCP session from 10.10.5.44:52341 at 14:22:07.

### Event ID 4624 (Security)
Records a successful logon.

What it shows here:
- Account: FINBRIDGE\bwalker
- Logon type: 10 (RemoteInteractive)
- Source IP: 10.10.5.44
- Confirms successful RDP authentication at 14:22:09.

## Reconstructed Sequence (Plain English)
1. At 14:01:02, the RDP security/protocol stream failed and the client at 10.10.5.44 was disconnected (Event 56).
2. At the same second, RDP core logging recorded that the connection failed due to incorrect username/password (Event 140).
3. At 14:01:04, Security log recorded failed remote interactive logon for FINBRIDGE\bwalker from 10.10.5.44 (Event 4625).
4. Additional failed logons from the same account and same IP occurred at 14:03:18 and 14:05:33 (Event 4625 repeated).
5. Immediately after the third listed failed attempt, at 14:05:34, FINBRIDGE\bwalker was locked out by policy threshold enforcement (Event 4740).
6. After approximately 16 minutes, at 14:22:07, the same client opened a fresh TCP RDP connection (Event 131).
7. At 14:22:09, remote interactive logon succeeded for FINBRIDGE\bwalker from 10.10.5.44 (Event 4624), showing the credentials/account state issue had been resolved.

## Most Likely Cause With Evidence

### Most Likely Cause
Repeated bad credential submissions for FINBRIDGE\bwalker from client 10.10.5.44 caused account lockout under domain policy, likely driven by saved/cached outdated password in RDP client or repeated manual password retries.

### Why this is most likely
- Failure reason is explicit and consistent: bad username/password (Events 140 and 4625).
- All failed attempts came from same source IP and same account.
- Lockout event immediately follows repeated failures.
- Later success from same source confirms path/connectivity was viable and issue was credential/account-state related, not persistent network failure.

### Evidence points
- 14:01:02 Event 56 (TermDD): protocol/security disconnect.
- 14:01:02 Event 140: invalid username/password.
- 14:01:04, 14:03:18, 14:05:33 Event 4625: repeated failed RDP logons.
- 14:05:34 Event 4740: account lockout.
- 14:22:07 Event 131: new TCP connection accepted.
- 14:22:09 Event 4624: successful RDP logon.

## Detailed 5-Why Analysis

### Problem Statement
User FINBRIDGE\bwalker could not access RDP and the account became locked.

### Why 1
Why could the user not sign in by RDP initially?
- Because remote interactive logons failed with bad username/password (Event 4625, Event 140).

### Why 2
Why were credentials rejected multiple times?
- The system received repeated invalid credential attempts from 10.10.5.44 for the same account.

### Why 3
Why did repeated invalid attempts continue?
- Most likely the client used stale cached/saved credentials or the user retried with an incorrect password several times.

### Why 4
Why did this become a larger incident instead of a single failed attempt?
- Domain account lockout policy threshold was reached, which automatically locked the account (Event 4740).

### Why 5
Why was the root behavior not prevented before lockout?
- Controls/process gaps likely existed around credential hygiene and user guidance (for example, no immediate purge of saved RDP credentials and no early self-service prompt to validate password reset state before repeated retries).

## Root Cause
Primary root cause: repeated invalid RDP credential attempts from client 10.10.5.44 for FINBRIDGE\bwalker triggered account lockout policy.

## Contributing Factors
- Potential stale stored credentials in RDP Credential Manager or .rdp profile.
- User uncertainty after password change or expired password event.
- Lack of immediate lockout-prevention guidance after first failed attempts.
- Event 56 protocol-stream error may have added user confusion but does not outweigh credential-failure evidence.

## Corrective Actions (Recommended)
1. Immediate containment
- Unlock FINBRIDGE\bwalker account and confirm AD lockout status clear.
- Validate user enters current password manually (no autofill).

2. Client-side remediation
- Remove saved credentials for target host from Windows Credential Manager.
- Review and update .rdp files or connection manager profiles using old credentials.

3. Policy and monitoring
- Correlate lockout events (4740) with failed logons (4625) by source IP for rapid triage.
- Add alerting for repeated RDP failures from a single source against one account.

4. User enablement
- Provide standard runbook: after password change, clear cached credentials before RDP retries.
- Communicate lockout threshold and recovery steps to reduce repeated failed attempts.

5. Hardening and assurance
- Confirm NLA and RDP security settings are consistent across endpoints.
- Investigate if Event 56 frequency is elevated for this host/client pair and remediate any TLS/protocol mismatches if found.

## Validation and Closure Criteria
- Successful RDP sign-in verified for FINBRIDGE\bwalker without further 4625 events in monitoring window.
- No new 4740 lockouts for the account after remediation.
- Client 10.10.5.44 confirms stable reconnect behavior.
- Evidence captured in incident record (timestamps, source IP, account, actions taken).

## Residual Risk
If other devices or services still store old credentials for FINBRIDGE\bwalker, lockout may recur from a different source.

## Assumptions and Evidence Limits
- Provided logs are a subset and may not include full domain controller lockout correlation details.
- No direct credential-manager inventory from client 10.10.5.44 was supplied.
- Conclusions therefore prioritize strongest available evidence: repeated 4625 failures from same IP followed by 4740 and later 4624 success.
