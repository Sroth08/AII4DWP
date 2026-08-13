# RCA - Legal App Crash Wave

## RCA Scope
This RCA is based only on the provided scope-facts document and does not introduce new telemetry, assumptions, or events.

## Problem Statement
Legal (Floor 6) reported a wave of application crashes in the morning across the Legal-Win11 fleet (45 devices).

## Impact Statement (From Provided Data)
- DEX score declined from 90 at 09:00 to 58 at 10:00 and 55 at 11:00.
- App crash rate rose from 0.2% at 09:00 to 6.2% at 10:00 and 6.8% at 11:00.
- Disk I/O shifted from Normal to High at 10:00 and remained High at 11:00.
- DocManager.exe represented 74% of crashes during 10:00-11:00.

## Change Event
- 09:38:20: SCCM deployment started for Legal Document Manager v2.1 to Legal-Win11 (45 devices).
- 09:44:07: Deployment completed successfully on 45/45 devices with 0 failures.

## Evidence Chain
1. Pre-change baseline was stable (08:00 and 09:00).
2. A fleet-wide application change completed at 09:44:07.
3. In the next measured hour (10:00), endpoint health dropped sharply with increased crashes and high disk I/O.
4. The dominant crashing process (DocManager.exe) aligns with the newly deployed application family.
5. Vendor note for v2.1 documents a known early post-install limitation: on devices under 8GB RAM, auto-save indexing may trigger high disk I/O and intermittent crashes.
6. Fleet hardware includes an under-8GB segment (4GB devices): 18 of 45.

## Root Cause Assessment
Most supported root cause from provided evidence:
- The Legal app crash wave is associated with the Legal Document Manager v2.1 deployment, with observed crash and disk I/O behavior consistent with the vendor-documented early post-install auto-save indexing limitation.

## Contributing Factors
- Presence of under-8GB devices in scope (18 devices with 4GB RAM), which meet the vendor-stated risk criterion.
- Full-scope simultaneous deployment (45/45) increased the size of the exposed population in the same time window.

## What Is Confirmed vs Not Confirmed
Confirmed:
- Temporal sequence (deployment completion before degradation).
- Process concentration (DocManager.exe as 74% of crashes during incident window).
- Symptom alignment (high disk I/O plus crash increase) with vendor note.

Not confirmed in provided data:
- Exact number of devices that crashed.
- Device-level attribution by RAM class.
- Device-level causal traces (for example, per-host crash dump confirmation).

## Final RCA Conclusion
Using only the supplied sources, the incident is best explained as a post-deployment instability event tied to Legal Document Manager v2.1 behavior in the early hours after installation, with risk amplified by the fleet's under-8GB subset.