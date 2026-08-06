# Closure Note: cthompson Login Failure

Resolved. Cause: `FINBRIDGE\cthompson`'s account was locked out after three consecutive wrong-password authentication attempts from DESKTOP-FB022. Action: Helpdesk (`FINBRIDGE\helpdesk-admin`) enabled the account, restoring access. Preventive: Add near-real-time alerting on account lockout events and on failed logons against a single account from multiple source IPs, and identify the source of the secondary failed-attempt IP. User confirmed working.
