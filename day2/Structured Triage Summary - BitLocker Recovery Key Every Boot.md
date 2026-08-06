# Structured Triage Summary

## Summary (one line)
Ticket T-1001: New Windows 11 laptop is prompting for BitLocker recovery key on every boot.

## Impact (who/how many/business urgency)
- Affected user(s): Single end user/device reported (to-verify).
- Functional impact: User cannot complete normal startup without manual recovery key entry each boot.
- Scope: Appears limited to one new Win11 laptop at present (to-verify).
- Business urgency: High user productivity impact due to repeated startup interruption; priority and SLA classification (to-verify).

## Known facts
- Ticket reference: T-1001.
- Device state: New Windows 11 laptop.
- Symptom: BitLocker recovery key prompt appears every boot.
- Frequency: Repeats on each startup per user report.

## Missing information to gather
- Device identity details (asset tag/hostname) and assigned user (sanitized where needed).
- Whether this occurs on every restart, cold boot, and resume from sleep.
- Whether any hardware/firmware/security setting changes were made since provisioning (to-verify).
- Whether BIOS/UEFI updates or TPM-related changes occurred before symptom started (to-verify).
- Whether other newly issued laptops are showing the same behavior (single-device vs wider issue).
- Exact on-screen recovery prompt wording and time first observed.
- Confirmation that the recovery key being used is valid and source location for retrieval process.

## Likely catagory
Endpoint security / device encryption (BitLocker) recurring recovery prompt issue.

## First diagnostic step
Instruct the user to complete one controlled boot while on support contact, then on successful sign-in verify BitLocker and protector state on that device (including recovery-trigger context in event logs) to confirm why recovery is being triggered at each startup.
