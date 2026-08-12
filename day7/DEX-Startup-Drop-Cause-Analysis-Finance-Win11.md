# DEX Startup Performance Drop — Ranked Cause Analysis
**Device group:** Finance-Win11 (215 devices)
**Signal:** Median startup time +23.8 s, score drop 84 → 61 from 2026-08-04
**Config change applied:** 2026-08-04 02:00 (security baseline profile — startup compliance script + additional Defender scan policy)

---

## Rank 1 — Startup compliance logging script running synchronously at login

**Why it fits:**
- The config change explicitly added a startup script for compliance logging, deployed at exactly the moment the degradation begins.
- Startup scripts that run synchronously block "login to usable desktop" directly — a ~24 s addition is consistent with a script waiting on a network call, log write, or slow interpreter start.
- IT-Win11 received no config change and shows zero degradation across the same dates, ruling out infrastructure or network causes that would affect both groups.

**Fastest check:**
Review Group Policy / Intune startup script execution logs on an affected device (`Event Viewer > Applications and Services Logs > Microsoft > Windows > GroupPolicy`). Look for script duration entries timestamped at logon on 2026-08-04+. Compare total script runtime against the ~24 s delta.

---

## Rank 2 — Additional Defender scan policy triggering a scan during the login phase

**Why it fits:**
- The same config change added a new Defender scan policy. A scan scheduled at startup or triggered on new-profile events can heavily contend with disk I/O during login, inflating time to usable desktop.
- Again, timing is exact and IT-Win11 is unaffected because the policy was not deployed to them.
- The ~24 s increase and the plateau across 2026-08-05–06 (not worsening) is consistent with a fixed per-boot scan overhead rather than an accumulating problem.

**Fastest check:**
On an affected device, check `Event Viewer > Windows Defender > Operational` for scan start/end events correlated with logon time. Also check `MpCmdRun.log` (`C:\ProgramData\Microsoft\Windows Defender\Support\`) for scan durations at boot. Compare a pre-04 Aug logon trace vs post-04 Aug.

---

## Rank 3 — Startup script causing a network dependency delay (GP/Intune processing wait)

**Why it fits:**
- If the compliance logging script calls a network resource (e.g., a logging endpoint, UNC path, or Intune check-in) that is slow or unreliable, Windows may wait for the script to complete or time out before releasing the desktop.
- This would not affect IT-Win11 as the script is scoped to Finance-Win11 only.
- A network-dependent delay would also explain why the times are not fully consistent day-to-day (41.3 → 43.8 → 42.1 s) — slight variance from network latency rather than a pure local overhead.

**Fastest check:**
Run `tracert` / `Test-NetConnection` to the script's target endpoint from an affected Finance device during login hours. Simultaneously capture a Process Monitor boot log (`procmon /backingfile`) to see whether the script is blocked on a network I/O wait and for how long.

---

*All three causes share the same root trigger: the 2026-08-04 02:00 config change. The clean IT-Win11 comparison confirms this is not an environmental or infrastructure issue. Investigate in rank order — Rank 1 can be confirmed or eliminated in under 10 minutes from Event Viewer alone.*
