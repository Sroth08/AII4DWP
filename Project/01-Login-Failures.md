# Login Failures and Slow Sign-Ins

## Scope of this issue
- Reported symptoms: At least some Floor 6 Legal users cannot log in on Monday morning, while others report sign-in taking a long time.
- Known environment: Windows 11, Intune managed, 45 users on the floor.
- Known timing: Reported at 09:14 Monday.

## Symptom
Some users cannot complete login, while others can log in only after a long delay.

## Potential business impact
Affected users are either blocked from starting work or significantly delayed.

## Severity
Critical.

## Could this represent a security incident?
Possibly. Sign-in disruption alone does not prove a security issue, but multi-user access problems require validation that they are not caused by an access control or account-related problem.

## May this be related to the Friday application deployment?
Possible, but unproven. The deployment is only a known recent change at this stage.

## First check
Check Microsoft Entra ID sign-in records for affected users during the Monday morning incident window, then compare with sign-in performance on an affected device.

## Why that check comes first
It tests first for a shared central sign-in pattern and then distinguishes that from device-local sign-in delay.

## Evidence expected
- Whether failed sign-ins are recorded for affected users
- Whether failures or delays cluster in time
- Whether the same sign-in pattern appears across multiple users
- Whether sign-in delay is reproducible on an affected device

## Escalation trigger
Escalate immediately if multiple affected users show the same authentication or access failure pattern, if login impact appears to be increasing across the floor, or if severe repeatable sign-in delay is present across multiple devices.
