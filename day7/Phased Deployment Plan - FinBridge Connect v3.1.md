# Phased Deployment Plan — FinBridge Connect v3.1

| Field | Value |
|---|---|
| Title | Phased Deployment Plan — FinBridge Connect v3.1 |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | DWP Endpoint Engineer |
| Reviewed | Self |
| Status | Draft |
| App | FinBridge Connect v3.1 (.intunewin) |
| Previous version | v3.0 — no major issues on rollout; still available in Intune app catalog |
| Target fleet | 10,000 Windows 11 endpoints |
| Deadline | 3 weeks from plan date (by 01/09/2026) |
| Detection rule | Registry version string check |

## Purpose
Defines a ringed deployment schedule for FinBridge Connect v3.1 that meets the Finance team's end-of-week-1 deadline (500 users, highest priority) while controlling risk from the 5% of the fleet on older 4GB RAM hardware, and keeps v3.0 available as a rollback path throughout.

> **Note on data handling:** This document contains no device identifiers, credentials, or tenant-specific names — safe for use per the Personal AI Usage Charter.

---

## 1. Constraints & risk summary

| Constraint | Implication for plan |
|---|---|
| Finance needs it by end of week 1 (500 users, highest priority) | Finance must be its own early, dedicated ring — cannot be folded into a later broad wave. |
| 5% of fleet (~500 devices) have 4GB RAM, may struggle with v3.1 requirements | These devices must **not** be mixed into standard rings; deploy last, after a go/no-go performance check, with enhanced monitoring and an explicit fallback to v3.0. |
| v3.0 had no major rollout issues | Baseline confidence in the general deployment mechanism (packaging, targeting, connectivity) is reasonably high — this rollout's added risk is version-specific (v3.1 requirements) and hardware-specific (4GB RAM), not process-specific. |
| v3.0 still in Intune app catalog | Enables a same-tool rollback (reassign v3.0, retire/uninstall v3.1) instead of a rebuild-from-scratch recovery. |
| Detection rule checks registry version string | Must be validated against the exact string v3.1 writes (see Section 3) before Ring 0, since it gates both compliance reporting and supersedence behaviour. |

---

## 2. Deployment rings & timeline

| Ring | Group | Approx. devices | Days | Exit criteria before next ring |
|---|---|---|---|---|
| Ring 0 — Pilot | IT + volunteer champions across departments (standard hardware only) | 100 | Day 1–2 | Install success ≥ 95%, no P1/P2 incidents, detection rule confirmed accurate (Section 3) |
| Ring 1 — Finance priority | All Finance devices (standard hardware) | 500 | Day 3–5 (end of week 1) | Install success ≥ 98%, Finance sign-off, no unresolved P1 tickets |
| Ring 2 — Broad wave A | ~40% of remaining standard-hardware fleet | 3,760 | Day 6–9 | Install success ≥ 95%, help-desk ticket volume within normal range |
| Ring 3 — Broad wave B | Remaining standard-hardware fleet | 5,140 | Day 10–14 | Install success ≥ 95%, no new hardware/perf-related issues surfaced |
| Ring 4 — Low-RAM cohort (4GB) | Devices flagged 4GB RAM | 500 | Day 15–19 | Go/no-go performance test passed (Section 4); enhanced monitoring in place |
| Closeout | Stragglers, retries, reporting | remainder | Day 20–21 | All rings at target install rate or explicitly held on v3.0 with documented reason |

Total accounted for: 100 + 500 + 3,760 + 5,140 + 500 = 10,000 devices.

Each ring is a **go/no-go gate**: the next ring does not start until the current ring's exit criteria are met or a documented exception is approved.

---

## 3. Detection rule validation (registry version string)

| Check | Why it matters |
|---|---|
| Confirm the registry path/value FinBridge Connect v3.1 actually writes (do not assume it is unchanged from v3.0). | If the path is unchanged but only the value changes, an incorrect rule could still read the old v3.0 string and report false "installed/compliant" for devices that failed to upgrade. |
| Confirm the detection rule matches the v3.1 string specifically (e.g. exact value "3.1", not "greater than or equal to 3.0" or a wildcard). | A loose rule would mark v3.0-only devices as compliant, masking incomplete rollout and breaking Ring exit-criteria reporting. |
| Test detection on: (a) clean device, (b) v3.0-only device, (c) v3.0→v3.1 upgraded device. | Confirms the rule returns "not installed", "not installed" (or v3.0-not-target), and "installed" respectively, before this is trusted at 10,000-device scale. |
| Configure v3.1 as a **supersedence/upgrade** of v3.0 in Intune rather than a separate app. | Ensures devices with v3.0 are upgraded in place and the old version is retired per policy, rather than risking side-by-side installs or failed detection due to two versions coexisting. |
| Re-validate detection rule after Ring 0 before Ring 1 (Finance) starts. | Finance is the highest-priority, time-boxed ring — a detection defect discovered here is cheaper to fix on 100 devices than on 500 Finance devices under deadline pressure. |

---

## 4. Hardware risk mitigation — 4GB RAM cohort (Ring 4)

1. **Identify the cohort precisely.** Build an Intune dynamic device group filtering on device physical memory (e.g. `device.physicalMemoryInBytes` reported via Intune/Endpoint analytics hardware inventory) rather than relying on manual lists, so the ~500 devices are captured accurately fleet-wide.
2. **Run a go/no-go performance test before Ring 4 opens.** Deploy to a small sample (10–20 devices) from within the 4GB cohort first; monitor CPU/RAM utilization, app launch time, and crash/hang reports for 24–48 hours.
3. **Define pass/fail thresholds up front** (e.g. no more than a defined % increase in crash reports, install success ≥ 90% for this cohort specifically — lower than standard rings because hardware-driven failures are anticipated).
4. **If the sample fails:** hold the remaining 4GB cohort on v3.0 (rollback per Section 5), open a vendor/engineering conversation about minimum requirements, and re-test before rescheduling.
5. **If the sample passes:** roll out to the remaining cohort with enhanced monitoring (shorter check-in interval, dedicated help-desk tag) through Day 19.

---

## 5. Rollback plan

| Trigger | Action |
|---|---|
| A ring fails its exit criteria (install failures, P1/P2 incidents, detection rule misreporting) | Pause the next ring. Do not proceed on schedule; the deadline yields to stability. |
| Individual devices fail to upgrade or show post-install issues | Reassign the affected device(s) to the v3.0 app assignment in the Intune catalog (uninstall v3.1 / reinstall v3.0), since v3.0 remains available and had no major rollout issues. |
| 4GB RAM cohort fails go/no-go performance test (Section 4) | Hold that cohort on v3.0 fleet-wide; do not force v3.1 onto hardware that cannot support it until a mitigation is confirmed. |
| Systemic issue found after a ring has fully deployed (e.g. discovered in Ring 2) | Consider a staged rollback of that ring via supersedence reversal (reassign v3.0 as the required app for the affected group) while root cause is investigated, rather than rolling back the entire fleet. |

Rollback is always same-tool (Intune app assignment change), not a manual reimage, since v3.0 already exists in the catalog.

---

## 6. Monitoring & success criteria

- Per-ring Intune app install status report reviewed daily during that ring's active window.
- Help-desk ticket volume/category tracked against a pre-rollout baseline; any spike tagged "FinBridge v3.1" for visibility.
- Ring 4 (4GB RAM) gets additional endpoint performance monitoring (CPU/RAM, app crash telemetry) given the known hardware risk.
- Overall success = all rings at or above their target install rate, Finance completed within week 1, and no unresolved P1 incidents attributable to the deployment at the 3-week mark.

---

## 7. Communications plan

| Audience | Timing | Message focus |
|---|---|---|
| Finance (Ring 1) | Before Day 3 | Priority deployment, expected completion by end of week 1, who to contact for issues. |
| General fleet (Rings 2–3) | Before each wave starts | What's changing, no action required, how to report issues. |
| 4GB RAM cohort (Ring 4) | Before Day 15 | Notify that their device may see reduced performance, what to expect, and that a fallback to the previous version is available if needed. |
| Help desk / L1-L2 | Before Ring 0 | Brief on v3.1 changes, known 4GB RAM risk, and the v3.0 rollback procedure so tickets can be resolved without escalation. |

---

## 8. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Detection rule misreports v3.0 as v3.1 (false compliant) | Medium | High — masks incomplete rollout, breaks reporting | Explicit multi-state validation in Section 3 before Ring 0 exit |
| Finance deadline slips past end of week 1 | Low–Medium | High — highest-priority stakeholder | Finance is its own dedicated ring immediately after a short Ring 0 pilot; no shared ring with general fleet |
| 4GB RAM devices experience degraded performance or failure | High (known constraint) | Medium — isolated to ~5% of fleet | Deploy last, gate on go/no-go test, hold on v3.0 if failed |
| Supersedence misconfiguration leaves v3.0 and v3.1 side-by-side | Low | Medium — inconsistent state, detection confusion | Validate supersedence behaviour in Ring 0 before wider rollout |
| Help-desk ticket surge during broad waves (Rings 2–3) | Medium | Medium | Baseline ticket volume tracked; pause ring on spike |
