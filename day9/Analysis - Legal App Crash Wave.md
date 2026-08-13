# Analysis - Legal App Crash Wave

## Source Basis
This analysis is derived strictly from the provided scope-facts document and its two cited sources (Nexthink DEX export and SCCM deployment log).

## Incident Scope
- Business area and location: Legal, Floor 6
- Device scope: Legal-Win11
- Total devices in scope: 45

## Correlated Timeline
- 08:00 (DEX): Score 91, app crash rate 0.1%, disk I/O Normal
- 09:00 (DEX): Score 90, app crash rate 0.2%, disk I/O Normal
- 09:38:20 (SCCM): Deployment started, Legal Document Manager v2.1, target Legal-Win11 (45 devices)
- 09:44:07 (SCCM): Deployment completed, 45/45 success, 0 failures
- 10:00 (DEX): Score 58, app crash rate 6.2%, disk I/O High
- 11:00 (DEX): Score 55, app crash rate 6.8%, disk I/O High

## Cross-Source Correlation Findings
1. Temporal correlation:
- Endpoint health degradation appears after deployment completion, not before.

2. Process-to-change correlation:
- During 10:00-11:00, DocManager.exe accounts for 74% of all crashes.
- The deployed package in the same scope is Legal Document Manager v2.1.

3. Symptom-pattern correlation:
- Vendor note for v2.1 states a known limitation on devices under 8GB RAM: high disk I/O and intermittent crashes during early post-install indexing.
- Observed post-deployment DEX pattern is high disk I/O with elevated app crashes.

4. Population-at-risk correlation:
- Fleet composition is 60% at 8GB RAM (27 devices) and 40% at 4GB RAM (18 devices).
- The documented limitation criterion (under 8GB RAM) maps directly to the 4GB cohort.

## Established Facts
- Impact scope and deployment scope are the same 45-device Legal-Win11 group.
- Baseline before rollout (08:00-09:00) was stable.
- Deployment execution status was successful on all 45 devices.
- Degradation started in the next measured DEX hour and persisted through 11:00.
- Crash concentration was primarily DocManager.exe during the degraded window.
- High disk I/O is observed only in the degraded post-deployment window.

## Limits of Evidence
- No per-device crash counts are provided.
- No per-device I/O values are provided.
- No confirmed split of crashed devices by RAM class is provided.
- No single-device causal trace is provided.

## Analytical Conclusion
Based on the provided evidence only, the strongest supported interpretation is a post-deployment degradation event in Legal-Win11 that is temporally and symptomatically aligned with Legal Document Manager v2.1 behavior described in the vendor known limitation.