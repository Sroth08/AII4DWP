# Ranked Cause Analysis: cthompson Login Failure

## Scope facts
- Symptom: User cthompson unable to log in.
- Who: cthompson only — no other users reported affected.
- Since: ~08:40 this morning.
- Change: Nil (no known/logged change).

## Discriminating fact
Impact is isolated to a single account with no associated change record. This weakens causes that would be expected to affect multiple users (e.g., broad infrastructure, network, or system-wide changes) and strengthens causes that are inherently account-specific.

## Ranked likely causes (most probable first, not yet confirmed)

### 1. Account lockout (e.g., failed password attempts, AD lockout policy triggered)
- Why it fits: Single-user, sudden-onset symptom with no change is the classic signature of an account lockout — often self-inflicted (typed cached/old password, expired password) rather than caused by any system change.
- Fastest check: Check the user's AD account status (Locked Out flag) and badPwdCount/lockout event (Event ID 4740) on the domain controller around 08:40.

### 2. Password expired
- Why it fits: Explains a sudden, isolated failure for one user with zero infrastructure change — expiry is user/account-specific and time-triggered, matching the "since 08:40" onset.
- Fastest check: Check the account's "pwdLastSet"/password expiry date in AD (or `net user cthompson /domain`) against the domain password policy max age.

### 3. Disabled or expired account (e.g., HR/leaver action, account expiration date reached)
- Why it fits: Fully isolated to one user, requires no infrastructure change, and can trigger abruptly at a specific time if an expiration date or an admin action set it.
- Fastest check: Check AD account properties for "Account is disabled" flag or an "Account expires" date around today.

### 4. Credential/cache issue on cthompson's specific device (corrupted cached credentials, cert, or profile)
- Why it fits: Localized to this one user's login path only; no change elsewhere needed since the fault lives in the user's device/profile/session state.
- Fastest check: Confirm whether cthompson can log in to a different device or via a different session type (e.g., webmail/portal); success there isolates the fault to the original device.

### 5. Conditional Access / MFA / group policy restriction newly applying to this user (e.g., group membership change, device compliance drift)
- Why it fits: Can produce a sudden single-user failure without a formal "change" being logged if it stems from an automated policy evaluation (e.g., device fell out of compliance, license/group sync) rather than a manual change.
- Fastest check: Review sign-in logs (e.g., Azure AD/Entra sign-in log) for cthompson at ~08:40 for the specific failure reason code (e.g., conditional access block, MFA failure).

## Status
Not yet committed to one cause. Account lockout and password expiry are ranked highest as they best fit a single-user, no-change, sudden-onset symptom. Next step: check AD account status/lockout and password expiry for cthompson.

## Event log evidence (2024-03-15 08:44-09:12)

### DESKTOP-FB022 — Security Event Log
- 08:44:01 — Event 4776 (Audit Failure): DC credential validation for `FINBRIDGE\cthompson` failed, Error Code `0xC000006A` (wrong password), source workstation DESKTOP-FB022.
- 08:44:03 — Event 4625 (Audit Failure): `FINBRIDGE\cthompson`, "Unknown user name or bad password", Logon type 2 (Interactive), Source DESKTOP-FB022.
- 08:44:28 — Event 4625 (Audit Failure): Same as above, second attempt.
- 08:44:55 — Event 4625 (Audit Failure): Same as above, third attempt.
- 08:44:56 — Event 4740 (Audit Failure): Account `FINBRIDGE\cthompson` locked out, caller computer DESKTOP-FB022.
- 08:45:10 — Event 4625 (Audit Failure): `FINBRIDGE\cthompson`, failure reason "Account locked out", Logon type 7 (Unlock attempt), Source DESKTOP-FB022.
- 08:45:44 — Event 4771 (Audit Failure): Kerberos pre-authentication failed, `FINBRIDGE\cthompson`, Failure code `0x18` (wrong password), Source IP 10.10.8.112 (differs from DESKTOP-FB022's 10.10.1.88).
- 08:46:01 — Event 4771 (Audit Failure): Same as above, second attempt, Source IP 10.10.8.112.
- 08:46:33 — Event 4771 (Audit Failure): Same as above, third attempt, Source IP 10.10.8.112.

## Hypothesis evaluation against evidence

1. **Account lockout** — Supports. Cite 08:44:56 Event 4740 (account locked out) preceded by three consecutive bad-password 4625s (08:44:03, 08:44:28, 08:44:55) and confirmed by the 08:45:10 Event 4625 with failure reason "Account locked out". This is a direct, unambiguous match.
2. **Password expired** — Contradicts. Cite 08:44:01 Event 4776 (`0xC000006A`, wrong password) and the 4625 failure reason "Unknown user name or bad password" at 08:44:03/28/55 — these are wrong-password codes, not the expired-password codes (e.g. `0xC0000071`) that a true expiry would produce.
3. **Disabled or expired account** — Contradicts. Same 08:44:01–08:44:55 entries show "bad password" failure reasons, not "account disabled" (`0xC0000072`) or "account expired" (`0xC0000193`); a disabled/expired account would fail before password is even evaluated, not on wrong-password codes.
4. **Credential/cache issue on cthompson's specific device** — Neutral-to-contradicts. The 08:44:01–08:45:10 failures do originate from DESKTOP-FB022, consistent with a device-side cached credential; however, the 08:45:44, 08:46:01, and 08:46:33 Event 4771 wrong-password failures come from a different source IP (10.10.8.112, not DESKTOP-FB022's 10.10.1.88) after the account was already locked, showing the same wrong-password pattern is not confined to that one device.
5. **Conditional Access / MFA / group policy restriction** — Contradicts. All entries (4776, 4625, 4771) are on-prem AD password/Kerberos failure codes with no MFA challenge, conditional access block, or policy-evaluation event present; the account was not denied by policy, it failed on wrong credentials and then locked out.

## Status (updated)
Not yet committed to one cause. Evidence strongly favors cause 1 (account lockout, itself triggered by repeated wrong-password attempts) and weakens causes 2, 3, and 5. Cause 4 is only partially undermined — the second source IP (10.10.8.112) attempting the same wrong password after lockout is an open discriminating fact that needs follow-up (e.g., a synced mobile device, mapped drive, or second host using stale/incorrect saved credentials for cthompson) before it can be ruled fully in or out.

## Surviving hypothesis
**Account lockout (Event 4740 at 08:44:56), triggered by repeated wrong-password authentication attempts against `FINBRIDGE\cthompson`** — confirmed by three consecutive Event 4625 bad-password failures (08:44:03, 08:44:28, 08:44:55) from DESKTOP-FB022, the resulting 08:44:56 Event 4740 lockout, and the 08:45:10 Event 4625 "Account locked out" confirmation. Root trigger of the wrong-password attempts is not yet fully explained — attempts continue post-lockout (08:45:44, 08:46:01, 08:46:33 Event 4771) from a second source IP (10.10.8.112), which must be identified before full closure.

## Resolution steps

### Immediate mitigation
1. Unlock `FINBRIDGE\cthompson` in AD (or wait out the lockout observation window) once the source of the bad attempts is understood — do not unlock blindly while an unexplained second source is still submitting wrong passwords.
2. Reset cthompson's password if there is any suspicion the credential itself is compromised or the user is unsure of the current value.
3. Notify cthompson directly: confirm whether they (a) mistyped/used an old cached password on DESKTOP-FB022, and (b) recognize or own any device/service tied to source IP 10.10.8.112 (e.g., phone, mapped drive, second PC, scheduled task).

### Root cause fix (identify the wrong-password source)
4. Resolve source IP 10.10.8.112 to a hostname/device (DHCP lease/DNS lookup) and identify what is running there.
5. On DESKTOP-FB022, check Credential Manager, mapped drives, scheduled tasks, and any saved-password apps (e.g., Outlook, VPN client) for a stale cached password for cthompson that could auto-retry after a password change.
6. If 10.10.8.112 is a personal/mobile device or second workstation, check it the same way for stored/cached credentials (e.g., synced mail profile, RDP saved credentials) using the old password.
7. Confirm whether cthompson's password was recently changed (self-service or admin reset) — a stale credential on a second device is the most common cause of this exact pattern (one device with fresh password, another silently retrying the old one).
8. Rule out external/malicious origin: if 10.10.8.112 is unrecognized and not one of cthompson's known devices, treat as a possible credential-stuffing/brute-force attempt and escalate to security for investigation (check for repeated failures against other accounts from the same IP).

### Validation before closure
9. After root cause is identified and any stale credential/device is corrected (or password reset propagated), unlock the account and have cthompson log in from DESKTOP-FB022 to confirm success.
10. Monitor Security event log for `FINBRIDGE\cthompson` for 24 hours for any further Event 4625/4771/4740 entries, particularly from 10.10.8.112.

### Closure
11. Document the confirmed trigger device/cause for the wrong-password attempts and the fix applied (e.g., credential updated on the offending device, or security incident logged if malicious).
12. If the second source IP is confirmed malicious, log as a security incident separately and ensure it is not closed merely as a routine lockout.
