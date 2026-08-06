# End-User Communications: AVD Black Screen Incident (POOL-FIN-01)

## Audience 1 — Non-technical executive

Your access and data were never at risk. Earlier today, some staff on one virtual desktop group briefly saw a blank screen when logging in, caused by a recent system update. It has been identified, fixed, and confirmed working as of 10:00 this morning. No action is needed on your part.

*(76 words)*

---

## Audience 2 — Affected end-user team

Hi team — earlier this morning some of you may have seen a black screen right after logging in to your virtual desktop; this was caused by an update applied overnight and has now been fixed. If you log in today and everything looks normal, no action is needed. If you still see a black screen, please try logging out and back in once — if it happens again, contact the IT Service Desk straight away so we can take a look. Thanks for your patience!

*(88 words)*

---

## Audience 3 — Engineer-to-engineer internal note

**Root cause:** Overnight image update to POOL-FIN-01 (deployed 02:00) introduced a regressed graphics driver, `igdumd64.dll` v31.0.101.4146. Driver faults with `0xc0000005` (access violation) inside `dwm.exe`, crashing DWM on session load (Event 1000, repeated at 07:02:16 / 07:02:46 / 07:08:24 on SHFIN-01-A). Some sessions recovered after 1-2 reconnect cycles (~30s), others stayed crash-looped. POOL-FIN-02 (image build `10.0.22621.2861-build-20240313`, not updated) was unaffected, confirming scope was image-specific.

**Action taken:** Drained POOL-FIN-01, rolled back all session hosts in the pool to the prior known-good image build (`...-build-20240313`), redeployed/rebooted hosts.

**Config detail:** Faulting component — `igdumd64.dll` v31.0.101.4146 (Intel graphics driver) bundled in the new image; rollback restores prior driver version matching SHFIN-02-A's build. Affected image only deployed to POOL-FIN-01; POOL-FIN-02 untouched throughout.

**Verification step:** Confirmed at 10:00 — users logging in successfully to POOL-FIN-01 hosts post-rollback, no Event 1000 (`dwm.exe`/`igdumd64.dll`) or Event 9009 (DWM exit) recurrence observed, no further user reports.

**Preventive action needed:** Add mandatory canary/pilot validation (synthetic login + DWM/driver health check) before any pool-wide image deployment; add automated alerting on Event 1000 (`dwm.exe`) and Event 9009 across session hosts; diff driver/component versions between image builds as a pre-deployment gate; track vendor (Intel) driver advisories before including new versions in the master image. Owner/ticket ref: to confirm.
