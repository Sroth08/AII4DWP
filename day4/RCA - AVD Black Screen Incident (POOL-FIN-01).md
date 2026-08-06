# Root Cause Analysis (RCA): AVD Black Screen Incident (POOL-FIN-01)

## Document Control
- Incident type: AVD session black screen post-login
- Affected scope: ~40% of users on POOL-FIN-01. POOL-FIN-02 unaffected.
- Review window: 07:00-07:30 (incident), resolved 10:00
- Source hosts in events: SHFIN-01-A (affected), SHFIN-02-A (comparison, unaffected)
- Analyst role: DWP Endpoint Analyst
- Date of analysis: 2026-08-06

## Executive Summary
Following an overnight image update applied to POOL-FIN-01 at 02:00, session hosts in that pool experienced repeated `dwm.exe` (Desktop Window Manager) crashes caused by a faulting graphics driver module (`igdumd64.dll`, v31.0.101.4146). This produced a black screen for users after login — clearing after roughly 30 seconds for users whose session reconnected and stabilized, and persisting for users whose sessions kept crash-looping. POOL-FIN-02, which did not receive the image update, showed zero impact, confirming the fault was introduced by the image change. The affected pool was rolled back to the prior known-good image; the fix was applied and verified resolved by 10:00, with users successfully logging in to POOL-FIN-01 hosts and no further issues reported.

Root cause: Graphics driver regression (`igdumd64.dll` v31.0.101.4146) introduced in the overnight POOL-FIN-01 image update, causing `dwm.exe` to crash on session load.

## Scope Facts
- Symptom: Black screen post-login — clears after ~30s for some users, persists for others.
- Who: ~40% of users on POOL-FIN-01. POOL-FIN-02 completely unaffected.
- Since: ~07:00 the morning of the incident.
- Change: Overnight image update to POOL-FIN-01 at 02:00. POOL-FIN-02 was NOT updated.
- Resolution confirmed: 10:00 — users verified logging in successfully to POOL-FIN-01 hosts, no issues reported.

## What Each Event ID Records

### Event ID 21 (Microsoft-Windows-TerminalServices-LocalSessionManager) - Session Logon Succeeded
Records a successful session logon/reconnect, including user, session ID, and source IP.

### Event ID 40 (Microsoft-Windows-TerminalServices-LocalSessionManager) - Session Disconnected
Records a session disconnect and its reason code.

### Event ID 1000 (Application Error) - Application Crash
Records a faulting application/module pair, version numbers, exception code, and process ID.

### Event ID 9009 (Desktop Window Manager) - DWM Exited
Records that the Desktop Window Manager process exited unexpectedly with a given exit code.

### Event ID 9011 (Desktop Window Manager) - DWM Started Successfully
Records a healthy DWM startup, with no accompanying crash.

### Event ID 1 (Microsoft-Windows-Kernel-General) - System Boot Time
Records the host's most recent boot time, used here to confirm the image update reboot.

## Timeline

| Time | Host | Event | Detail |
|---|---|---|---|
| 02:00 | POOL-FIN-01 (all hosts) | Change | Overnight image update applied |
| 07:01:44 | SHFIN-02-A | Event 21 | Session logon succeeded, `FINBRIDGE\bwalker`, Session ID 2 |
| 07:01:46 | SHFIN-02-A | Event 9011 | DWM started successfully — no errors this window |
| 07:02:10 | SHFIN-01-A | Event 21 | Session logon succeeded, `FINBRIDGE\mlopez`, Session ID 3, Source 10.10.1.55 |
| 07:02:14 | SHFIN-01-A | Event 1 | System boot time 02:03:11 — confirms reboot after image update |
| 07:02:16 | SHFIN-01-A | Event 1000 | `dwm.exe` (v10.0.22621.2861) faults in `igdumd64.dll` (v31.0.101.4146), exception `0xc0000005`, process 0x1a4c |
| 07:02:17 | SHFIN-01-A | Event 40 | Session disconnected, `FINBRIDGE\mlopez`, Session ID 3, reason code 0 |
| 07:02:18 | SHFIN-01-A | Event 9009 | DWM exited with code 0x40010004 |
| 07:02:44 | SHFIN-01-A | Event 21 | Session logon succeeded (reconnect), `FINBRIDGE\mlopez`, Session ID 3 |
| 07:02:46 | SHFIN-01-A | Event 1000 | Repeat `dwm.exe`/`igdumd64.dll` fault, exception `0xc0000005` |
| 07:02:47 | SHFIN-01-A | Event 40 | Session disconnected, `FINBRIDGE\mlopez`, Session ID 3 |
| 07:03:01 | SHFIN-01-A | Event 9009 | DWM exited with code 0x40010004 |
| 07:03:10 | SHFIN-01-A | Event 21 | Session logon succeeded (second reconnect, now stable), `FINBRIDGE\mlopez`, Session ID 4 |
| 07:08:22 | SHFIN-01-A | Event 21 | Session logon succeeded, `FINBRIDGE\akapoor`, Session ID 5, Source 10.10.1.61 |
| 07:08:24 | SHFIN-01-A | Event 1000 | Repeat `dwm.exe`/`igdumd64.dll` fault, exception `0xc0000005` (session persists black/unstable) |
| ~09:xx (to confirm) | POOL-FIN-01 | Remediation | Image rolled back to prior known-good build; hosts redeployed/rebooted |
| 10:00 | POOL-FIN-01 | Verification | Users confirmed logging in successfully; no issues reported |

## Comparison Evidence (Control Pool)
SHFIN-02-A (POOL-FIN-02, image version `10.0.22621.2861-build-20240313`, not updated) logged a clean session logon and DWM start (07:01:44, 07:01:46, Event 9011) with no Application Error events throughout the window — isolating the fault to hosts that received the 02:00 image update.

## Hypothesis Elimination Summary
Five candidate causes were ranked from initial scope facts and tested against event log evidence:

1. **Graphics/display driver regression in the new image** — Supported. Repeated Event 1000 faults (`dwm.exe`/`igdumd64.dll`, `0xc0000005`) at 07:02:16, 07:02:46, 07:08:24 on the affected host, absent on the unaffected control host.
2. **Broken/misconfigured component (FSLogix, AVD agent, GPU service) in the new image** — Neutral/partial. Fault module is GPU-related, so not disconfirmed, but no FSLogix or AVD-agent-specific errors were present to independently support this broader variant.
3. **AVD agent/RDP shell (rdpshell/rdpinit) failing to initialize** — Contradicted. Disconnects (Event 40) directly followed the DWM crash, not any shell-init error; no rdpshell/rdpinit event was logged.
4. **Session host resource exhaustion (CPU/GPU/memory)** — Contradicted. Exception `0xc0000005` is an access-violation crash signature, not a resource-exhaustion signature; no utilization/resource-warning events were present.
5. **Unrelated cause (profile disk/network issue)** — Contradicted. No FSLogix, profile, or network event IDs appeared anywhere in the affected host's log; the unaffected control host on shared infrastructure showed no impact.

## Detailed 5-Why Analysis

### Problem Statement
Users on POOL-FIN-01 experienced a black screen after login, clearing after ~30 seconds for some and persisting for others.

### Why 1
Why did users see a black screen after login?
- Because the Desktop Window Manager (`dwm.exe`), which renders the desktop, crashed immediately after session logon.
- Evidence: Event 1000 at 07:02:16 (and repeats at 07:02:46, 07:08:24) shows `dwm.exe` faulting, followed by Event 9009 (DWM exited) at 07:02:18.

### Why 2
Why did `dwm.exe` crash?
- Because it faulted in the graphics driver module `igdumd64.dll` (v31.0.101.4146) with an access violation (`0xc0000005`).
- Evidence: Same Event 1000 entries name `igdumd64.dll` as the faulting module in every occurrence.

### Why 3
Why was this graphics driver faulting?
- Because a regressed/incompatible driver version was introduced by the overnight image update at 02:00, confirmed by the host reboot at 02:03:11.
- Evidence: SHFIN-02-A, running the prior image build (`...-build-20240313`) with no driver change, shows a clean DWM start (Event 9011) and zero crashes in the same window.

### Why 4
Why did some sessions recover after ~30s while others persisted in black screen?
- Because session reconnects (Event 21) after each DWM crash sometimes landed on a stable render (e.g., `mlopez` stabilized on the second reconnect at 07:03:10), while other sessions kept hitting the same driver fault on each attempt (e.g., `akapoor` crashed again at 07:08:24 with no stable reconnect shown).
- Evidence: Event 21/1000/40/9009 cycles for `mlopez` (3 cycles ending in stable Session ID 4) versus a single crash for `akapoor` with no subsequent recovery event captured in this window.

### Why 5
Why did this reach ~40% of users on POOL-FIN-01 before being caught and rolled back?
- Because the faulty image had already been deployed pool-wide at 02:00, before any user login had occurred to surface the regression, and there was no automated pre-production validation (e.g., synthetic login/driver health check) to catch the fault before the morning login wave.
- Evidence: Boot time 02:03:11 confirms pool-wide deployment several hours before the first affected logons at ~07:00; no pilot/canary validation step is evidenced in the timeline.

## Root Cause
Primary root cause: A graphics driver regression (`igdumd64.dll` v31.0.101.4146) introduced in the overnight image update to POOL-FIN-01 caused `dwm.exe` to crash on session load, producing black screens that cleared for users whose sessions eventually stabilized on reconnect and persisted for users whose sessions continued to crash-loop.

## Contributing Factors
- No pre-production/pilot validation step (e.g., canary host or synthetic login test) before pool-wide image deployment.
- No automated health check tied to DWM/graphics driver stability post-deployment.
- Reliance on user-reported symptoms to surface the regression rather than proactive monitoring.

## Corrective Actions Taken
- POOL-FIN-01 drained and rolled back to the last known-good image build.
- Affected session hosts redeployed/rebooted on the prior image.
- User sessions verified stable post-rollback.
- Resolution confirmed at 10:00: users logging in successfully to POOL-FIN-01 hosts, no issues reported.

## Preventive Actions
1. Image release process:
   - Require a pilot/canary host pool validation step before any image update is deployed pool-wide, including a synthetic login and DWM/driver health check.
   - Diff driver and key component versions between new and previous image builds as a mandatory pre-deployment gate.

2. Monitoring and detection:
   - Add automated alerting on Application Error Event 1000 for `dwm.exe` and DWM Event 9009 across session hosts, so recurrence is caught before widespread user impact.
   - Track post-deployment health metrics (crash counts, session stability) for a defined bake-in period after any image change.

3. Rollback readiness:
   - Maintain a fast, tested rollback path to the prior image build for each host pool to minimize time-to-mitigate on future regressions.

4. Vendor/driver management:
   - Track known-issue advisories for the graphics driver vendor (Intel) before including new driver versions in the master image.

## Validation and Closure Criteria
- Confirm no further Event 1000 (`dwm.exe`/`igdumd64.dll`) or Event 9009 occurrences on POOL-FIN-01 hosts in the next monitoring window.
- Confirm all previously affected users can log in and retain a stable session without black screen.
- Confirm no recurrence within an agreed observation period (e.g., next 2 business days).
- Status: Resolved and verified at 10:00 — users logging in to POOL-FIN-01 hosts, no issues reported (ongoing monitoring window to confirm no recurrence).

## Limitations of Current Evidence
- Only a 30-minute event log excerpt (07:00-07:30) was provided; full-day logs were not reviewed.
- Exact rollback timestamp and deployment method are to confirm.
- No corroborating FSLogix, network, or capacity telemetry was provided/needed, since the graphics driver evidence was conclusive.
- No formal vendor advisory reference for `igdumd64.dll` v31.0.101.4146 has been confirmed yet (to confirm).

Despite these limitations, the event evidence is internally consistent and strongly supports the graphics driver regression as the root cause, fully explaining both the pool-specific scope and the variable black-screen duration.
