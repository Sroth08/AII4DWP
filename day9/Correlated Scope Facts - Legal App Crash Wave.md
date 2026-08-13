# Correlated Scope Facts - Legal App Crash Wave

## Scenario Scope
- Business area and location: Legal, Floor 6
- Device scope: Legal-Win11 collection/group
- Total devices in scope: 45

## Source Correlation (Timing + Content)

### Unified timeline across both sources
- 08:00 (DEX): Score 91, app crash rate 0.1%, disk I/O Normal
- 09:00 (DEX): Score 90, app crash rate 0.2%, disk I/O Normal
- 09:38:20 (SCCM): Deployment started for Legal Document Manager v2.1 to Legal-Win11 (45 devices)
- 09:44:07 (SCCM): Install completed on 45/45 devices, result Success, 0 failures
- 10:00 (DEX): Score drops to 58, app crash rate rises to 6.2%, disk I/O High
- 11:00 (DEX): Score 55, app crash rate 6.8%, disk I/O High

Correlation fact:
- The DEX degradation window begins after the SCCM deployment completed, not before it.

### Process-level and package-level linkage
- DEX (10:00-11:00): Top crashing process is DocManager.exe, representing 74% of all crashes in that window.
- SCCM package deployed in same scope and just before degradation: Legal Document Manager v2.1.

Correlation fact:
- The dominant crashing process name aligns with the deployed application family (Document Manager), in the same device scope and post-deployment window.

### Symptom pattern correlation with vendor note
- Vendor release note for v2.1: known limitation on devices under 8GB RAM where auto-save indexing may cause high disk I/O and intermittent crashes during first hours after install.
- DEX during 10:00-11:00 shows exactly high disk I/O plus elevated crash rates after rollout completion.

Correlation fact:
- Observed post-deployment symptom pattern (high disk I/O + crash increase in first hours) matches the documented v2.1 known limitation pattern.

### Hardware cohort scope against limitation criteria
- Fleet composition: 60% with 8GB RAM (27 devices), 40% with 4GB RAM (18 devices).
- Documented limitation applies to under 8GB RAM.

Correlation fact:
- At-risk subgroup defined by vendor criteria is the 4GB cohort (18 devices) inside the 45-device scope.

## Established Scope Facts (Strictly from provided data)
1. Impact and change share the same full scope: Legal-Win11, 45 devices.
2. Baseline was stable at 08:00-09:00 before rollout.
3. v2.1 deployed successfully to all 45 devices by 09:44:07.
4. Degradation appears in the next measured DEX hour (10:00) and persists at 11:00.
5. Crash concentration is mostly DocManager.exe (74%) during the degraded window.
6. High disk I/O appears only in the degraded post-deployment window.
7. The observed symptom combination and timing align with the vendor-known v2.1 limitation during early post-install indexing.
8. The fleet contains 18 devices (4GB) that meet the under-8GB risk criterion.

## Not Established by the Provided Sources
- Exact number of devices that crashed.
- Per-device crash counts or per-device I/O metrics.
- Whether any 8GB devices also crashed.
- A single-device causal proof; only a strong cross-source temporal and symptom correlation is established.
