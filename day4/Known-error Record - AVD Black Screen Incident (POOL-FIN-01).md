# Known-Error Record: AVD Black Screen Incident (POOL-FIN-01)

**Symptom:** Users see a black screen immediately after logging in to their AVD session. For some users the screen clears after roughly 30 seconds once the session reconnects and stabilizes; for others it persists.

**Cause:** A graphics driver regression (`igdumd64.dll` v31.0.101.4146) was introduced in the overnight image update applied to POOL-FIN-01, causing `dwm.exe` to crash on session load with exception `0xc0000005`.

**Scope:** ~40% of users on POOL-FIN-01 session hosts. POOL-FIN-02, which did not receive the image update, was completely unaffected.

**Workaround:** Drain and cordon the affected host pool, then roll back session hosts to the prior known-good image build to restore stable logins.

**Permanent fix:** Rebuild the master image with the corrected graphics driver, validate on a pilot/canary pool, then redeploy in stages with monitoring before wider rollout.

**How to spot it:** Application Error Event 1000 with faulting application `dwm.exe` and faulting module `igdumd64.dll`, exception code `0xc0000005`; followed by TerminalServices-LocalSessionManager Event 40 (session disconnect) and Desktop Window Manager Event 9009 (DWM exited). A clean comparison host shows DWM Event 9011 (started successfully) with no Event 1000 entries.
