# Structured Triage Summary

## Summary (one line)
User cannot connect to VDI today from home Wi-Fi; connection attempt returns "cannot connect," and it worked on Friday.

## Impact (who/how many/business urgency)
- Affected user(s): Single end user reported (to confirm).
- Functional impact: User cannot access VDI session.
- Scope: Only this user/device reported so far (to confirm).
- Business urgency: User cannot access remote desktop workspace; urgency level to confirm.

## Known facts
- Current issue: "cannot connect" message when trying to access VDI.
- Timing: Issue is happening today.
- Previous state: "worked friday".
- Location/network: User is at home on Wi-Fi.

## Missing information to gather
- Exact error text/code and where it appears (VDI client, browser, or gateway).
- Whether multiple connection attempts were made and if behavior is consistent.
- VDI platform/client in use and client version.
- Whether other users are impacted (service-wide vs single user).
- Whether user can access internet and corporate resources generally (for example webmail/VPN) from same network.
- Whether VPN is required and currently connected/disconnected.
- User device details (managed/unmanaged, OS version, recent updates/restarts).
- Any recent account/password/MFA changes since Friday.
- Whether user can connect using an alternate network (for example mobile hotspot).

## Likely catagory
Remote access/VDI connectivity issue from home network (to confirm).

## Suggest first diagnostic step
Capture and confirm the exact connection error message/code from the VDI client during a fresh connection attempt, then immediately verify whether the user has active internet access and required VPN state on the same device.
