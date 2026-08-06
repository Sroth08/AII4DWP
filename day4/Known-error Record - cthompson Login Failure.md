# Known-Error Record: cthompson Login Failure

**Symptom:** User `FINBRIDGE\cthompson` is unable to log in from DESKTOP-FB022.

**Cause:** The account was locked out (Event 4740) after three consecutive wrong-password authentication failures (Event 4776/4625, `0xC000006A`) within under a minute. Access was restored only after helpdesk enabled the account (Event 4722); a second, unidentified source IP (10.10.8.112) also submitted wrong-password Kerberos attempts (Event 4771) after the lockout.

**Scope:** Isolated to `FINBRIDGE\cthompson` only, logging in from DESKTOP-FB022. No other users or systems were affected.

**Workaround:** Check the account's lockout/enabled status in AD and unlock/enable it to restore login immediately.

**Permanent fix:** Identify the device/owner behind the secondary source IP (10.10.8.112) generating wrong-password attempts and remediate the stale/incorrect cached credential (or escalate to security if unrecognized), so repeat lockouts are not triggered.

**How to spot it:** Event 4776/4625 with failure reason "wrong password"/"bad password" (`0xC000006A`), followed by Event 4740 (account locked out); Event 4625 with failure reason "Account locked out" (Logon type 7) confirms the lock state. Continued Event 4771 (`0x18`, wrong password) from a source IP other than the user's known device indicates the secondary, unresolved trigger. Resolution is confirmed by Event 4722 (account enabled) followed by a successful Event 4624 (Logon type 2).
