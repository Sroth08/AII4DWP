# Structured Triage Summary

## Summary (one line)
Ticket T-1006: User reports general slowness after upgrading to Windows 11 two days ago.

## Impact (who/how many/business urgency)
- Affected user(s): Single user/device reported (to-verify).
- Functional impact: Broad performance degradation across normal tasks.
- Scope: Currently appears user-specific post-upgrade (to-verify).
- Business urgency: Medium, potentially high if user is blocked on core duties.

## Known facts
- Ticket reference: T-1006.
- Symptom: "Everything is slow."
- Timing: Windows 11 upgrade completed two days ago.

## Missing information to gather
- Whether slowness is at sign-in only, in specific apps, or system-wide all day.
- Whether CPU, memory, or disk usage is consistently high during slow periods.
- Free disk space on system drive and health status (to-verify).
- Whether updates, indexing, OneDrive sync, or security scans are active post-upgrade.
- Whether issue persists after reboot and with minimal startup load.
- Whether similar symptoms are reported by other recently upgraded users.
- Device hardware baseline (RAM, storage type) against Win11 workload expectations (to-verify).

## Likely catagory
Endpoint performance degradation after OS upgrade.

## First diagnostic step
During an active slow period, collect a Task Manager snapshot (CPU, memory, disk, top processes) and correlate with background post-upgrade activity to identify the primary bottleneck before applying fixes.
