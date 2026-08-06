# Structured Triage Summary

## Summary (one line)
Ticket T-1004: Company app installation from Company Portal fails with error 0x87D1041C.

## Impact (who/how many/business urgency)
- Affected user(s): One user/device reported (to-verify).
- Functional impact: Required business application cannot be installed.
- Scope: Unknown if isolated to one app, one device, or multiple users (to-verify).
- Business urgency: Medium-high if app is required for core role tasks.

## Known facts
- Ticket reference: T-1004.
- Platform/context: Installation attempted via Company Portal.
- Symptom: Install fails.
- Reported code: 0x87D1041C.

## Missing information to gather
- Exact app name/version and assignment intent (required vs available) (to-verify).
- Whether failure occurs on one device only or multiple devices/users.
- Device compliance/enrollment state and last policy sync status.
- Network context during install attempt (corp network, VPN, home).
- Available disk space and whether other app installs succeed.
- Whether this app was recently repackaged or deployment settings changed (to-verify).
- Exact failure time for correlation with management logs.

## Likely catagory
Endpoint management / Intune Company Portal app deployment failure.

## First diagnostic step
From the affected device, trigger a manual Company Portal and device management sync, retry the install, and immediately review the resulting app deployment status and local management logs for that same timestamp.
