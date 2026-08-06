# Structured Triage Summary

## Summary (one line)
Ticket T-1008: VPN connects successfully but internal resources are unreachable after a Windows 11 upgrade.

## Impact (who/how many/business urgency)
- Affected user(s): One user/device reported (to-verify).
- Functional impact: Remote user cannot access internal services despite active VPN connection.
- Scope: Currently appears post-upgrade and user/device specific (to-verify).
- Business urgency: High for remote productivity where internal systems are required.

## Known facts
- Ticket reference: T-1008.
- Symptom: VPN session establishes.
- Additional symptom: No internal resources reachable.
- Timing/context: Issue follows Win11 upgrade.

## Missing information to gather
- Which internal resources fail (file shares, intranet, specific apps, name resolution).
- Whether access fails by hostname only, IP only, or both.
- Whether issue occurs on all networks and after reboot.
- VPN client type/version and whether profile settings changed during upgrade (to-verify).
- Whether other Win11-upgraded users with same VPN profile are affected.
- Whether local internet remains functional while VPN is connected.
- Whether endpoint firewall/security policy recently changed (to-verify).

## Likely catagory
Remote access / VPN post-upgrade network path or name-resolution issue.

## First diagnostic step
With VPN connected, run a basic reachability check sequence to an internal hostname and its corresponding IP to quickly determine whether the primary failure domain is routing or name resolution, then branch diagnostics accordingly.
