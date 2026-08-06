# Ranked Cause Analysis: AVD Black Screen Incident (POOL-FIN-01)

## Scope facts
- Symptom: Black screen post-login — clears after 30s for some users, persists for others.
- Who: ~40% of users on POOL-FIN-01. POOL-FIN-02 is completely unaffected.
- Since: ~07:00 this morning.
- Change: Overnight image update to POOL-FIN-01 at 02:00. POOL-FIN-02 was NOT updated.

## Discriminating fact
POOL-FIN-02 received no image update and shows zero impact. Any cause must therefore be something introduced by or contained in the new POOL-FIN-01 image — infrastructure- or account-wide causes that would be expected to also affect POOL-FIN-02 are weakened by this control comparison.

## Ranked likely causes (most probable first, not yet confirmed)

### 1. Graphics/display driver regression in the new image
- Why it fits: Symptom pattern (clears after 30s for some, persists for others) matches a driver-init/render delay. Fully isolated to the only pool that received the image update.
- Consistency with POOL-FIN-02 unaffected: Strongest fit — driver version is baked into the image itself. No update on POOL-FIN-02 = old driver retained = no regression possible.
- Fastest check: Compare the display/graphics driver version in the new POOL-FIN-01 image against the previous known-good image version.

### 2. Broken/misconfigured component (FSLogix, AVD agent, GPU service) shipped in the new image
- Why it fits: Same scope/timing correlation as #1, but the fault could sit in a non-driver component rather than the display driver.
- Consistency with POOL-FIN-02 unaffected: Equally strong — any component baked into the image only exists in changed form on POOL-FIN-01; POOL-FIN-02 keeps the prior working component.
- Fastest check: Diff the image build/deployment log or app/service inventory between the new and previous POOL-FIN-01 image versions.

### 3. AVD agent/RDP shell (rdpshell/rdpinit) failing to initialize correctly on affected hosts
- Why it fits: Explains why black screen clears after 30s for some (shell eventually loads) but persists for others (shell fails entirely).
- Consistency with POOL-FIN-02 unaffected: Directly tied to the image — shell/agent version is part of the pool's image build, so an untouched image on POOL-FIN-02 would not carry the same init fault.
- Fastest check: Review Event Viewer on an affected session host for RDS/AVD agent or TerminalServices-RDPClient errors around login time.

### 4. Session host resource exhaustion (CPU/GPU/memory) caused by something new in the image
- Why it fits: Could explain inconsistent severity (30s delay vs. persistent) as a load-dependent symptom.
- Consistency with POOL-FIN-02 unaffected: Only consistent with the pool split if the exhaustion is itself a side-effect of the new image; if resource pressure were independent of the image, POOL-FIN-02 could show it too under similar load — weaker fit than 1–3.
- Fastest check: Check host-level CPU/GPU utilization and available capacity on POOL-FIN-01 hosts at ~07:00 vs. POOL-FIN-02.

### 5. Unrelated cause (e.g., profile disk or network issue) not connected to the image update
- Why it fits (weakest): Doesn't explain why the issue is confined solely to the updated pool.
- Consistency with POOL-FIN-02 unaffected: Weakest fit — profile storage/network infrastructure is typically shared across pools, so a genuinely unrelated fault would likely also touch POOL-FIN-02. Its complete lack of impact argues against this cause.
- Fastest check: Confirm affected users' profile disks and storage share health are identical/unaffected on POOL-FIN-01 vs. POOL-FIN-02.

## Status
Not yet committed to one cause. Pool-split evidence strongly favors causes 1–3 (all image-content-specific). Next step: driver/build diff between image versions.

## Event log evidence (2024-03-15 07:00-07:30)

### SHFIN-01-A (POOL-FIN-01 — affected)
- 07:02:10 — TerminalServices-LocalSessionManager Event 21: Session logon succeeded. User `FINBRIDGE\mlopez`, Session ID 3, Source 10.10.1.55.
- 07:02:14 — Kernel-General Event 1: System boot time 2024-03-15 02:03:11 (host restarted after overnight image update).
- 07:02:16 — Application Error Event 1000: Faulting application `dwm.exe` (v10.0.22621.2861), faulting module `igdumd64.dll` (v31.0.101.4146), exception code `0xc0000005`, process ID 0x1a4c.
- 07:02:17 — TerminalServices-LocalSessionManager Event 40: Session disconnected. User `FINBRIDGE\mlopez`, Session ID 3, Reason code 0.
- 07:02:18 — Desktop Window Manager Event 9009: DWM exited with code 0x40010004.
- 07:02:44 — TerminalServices-LocalSessionManager Event 21: Session logon succeeded (reconnect). User `FINBRIDGE\mlopez`, Session ID 3.
- 07:02:46 — Application Error Event 1000: Same `dwm.exe`/`igdumd64.dll` fault, exception code `0xc0000005`.
- 07:02:47 — TerminalServices-LocalSessionManager Event 40: Session disconnected. User `FINBRIDGE\mlopez`, Session ID 3.
- 07:03:01 — Desktop Window Manager Event 9009: DWM exited with code 0x40010004.
- 07:03:10 — TerminalServices-LocalSessionManager Event 21: Session logon succeeded (second reconnect). User `FINBRIDGE\mlopez`, Session ID 4.
- 07:08:22 — TerminalServices-LocalSessionManager Event 21: Session logon succeeded. User `FINBRIDGE\akapoor`, Session ID 5, Source 10.10.1.61.
- 07:08:24 — Application Error Event 1000: Same `dwm.exe`/`igdumd64.dll` fault, exception code `0xc0000005`.

### SHFIN-02-A (POOL-FIN-02 — unaffected, image version 10.0.22621.2861-build-20240313, pre-update)
- 07:01:44 — TerminalServices-LocalSessionManager Event 21: Session logon succeeded. User `FINBRIDGE\bwalker`, Session ID 2.
- 07:01:46 — Desktop Window Manager Event 9011: DWM started successfully.
- No Application Error events in this window.

## Hypothesis evaluation against evidence

1. **Graphics/display driver regression in the new image** — Strongly supports. Cite 07:02:16, 07:02:46, 07:08:24 (Event 1000, `dwm.exe` faulting on `igdumd64.dll`, `0xc0000005`), contrasted with 07:01:46 on SHFIN-02-A (Event 9011, clean DWM start, no errors).
2. **Broken/misconfigured component (FSLogix, AVD agent, GPU service) in the new image** — Neutral-to-partial support. Cite 07:02:16 Event 1000 — faulting module is GPU-related, so not disconfirmed, but no FSLogix/AVD-agent-specific errors present to independently confirm the non-driver variant.
3. **AVD agent/RDP shell (rdpshell/rdpinit) failing to initialize** — Contradicts. Cite 07:02:17 Event 40 (disconnect) occurring one second after the 07:02:16 dwm.exe crash, not after any rdpshell/rdpinit error; no such event exists in the log.
4. **Session host resource exhaustion (CPU/GPU/memory)** — Contradicts. Cite 07:02:16 Exception code `0xc0000005` (access violation/crash signature, not exhaustion); no CPU/GPU utilization or resource-warning events present.
5. **Unrelated cause (profile disk/network issue)** — Contradicts. Cite 07:01:46 SHFIN-02-A Event 9011 (clean, shared-infrastructure host unaffected); no FSLogix/profile/network event IDs anywhere in the SHFIN-01-A log.

## Surviving hypothesis
**Graphics/display driver regression in the new image** — confirmed by repeated `dwm.exe` crashes faulting on `igdumd64.dll` (v31.0.101.4146), exception `0xc0000005`, at 07:02:16, 07:02:46, and 07:08:24 on SHFIN-01-A, absent entirely on the un-updated SHFIN-02-A comparison host.

## Resolution steps

### Immediate mitigation
1. Drain and cordon POOL-FIN-01 — mark affected session hosts as "drain mode" so no new users land on them.
2. Roll back the image on POOL-FIN-01 session hosts to the last known-good build (matching SHFIN-02-A's `10.0.22621.2861-build-20240313`).
3. Reboot/reassign active sessions for affected users (e.g., `mlopez`, `akapoor`) once hosts are back on the rolled-back image; verify DWM starts cleanly (Event 9011, no Event 1000/9009).
4. Notify affected users with a plain-language update and ETA.

### Root cause fix (permanent)
5. Diff the graphics driver package/version between the new and previous POOL-FIN-01 image builds to confirm `igdumd64.dll` v31.0.101.4146 as the regressed component.
6. Check vendor (Intel) release notes for known issues with this driver version on the current Windows/AVD build; obtain a fixed version or apply a vendor-recommended mitigation.
7. Rebuild the master image with the corrected/rolled-back graphics driver, keeping other intended image changes intact.

### Validation before redeploy
8. Pilot test the corrected image on a small test host pool; reproduce login load and confirm no `dwm.exe`/`igdumd64.dll` crashes over a soak period.
9. Regression-check that the original intent of the overnight update still functions correctly on the corrected image.

### Redeploy and close out
10. Staged rollout of the corrected image to POOL-FIN-01, monitoring for Application Error Event 1000 (`dwm.exe`) and DWM Error 9009 after each stage.
11. Monitor POOL-FIN-01 for 24-48 hours post-fix for recurrence before closing.
12. Document as a known-error record: symptom (black screen post-login), cause (`igdumd64.dll` driver regression in image update), workaround (image rollback), permanent fix (corrected driver in rebuilt image).
