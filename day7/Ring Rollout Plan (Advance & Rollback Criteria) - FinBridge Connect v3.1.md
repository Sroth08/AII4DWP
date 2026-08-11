# Ring Rollout Plan (Advance & Rollback Criteria) — FinBridge Connect v3.1

| Field | Value |
|---|---|
| Title | Ring Rollout Plan (Advance & Rollback Criteria) — FinBridge Connect v3.1 |
| Version | 1.0 |
| Date | 11/08/2026 |
| Author | DWP Endpoint Engineer |
| Reviewed | Self |
| Status | Draft |
| App | FinBridge Connect v3.1 (.intunewin), already added to the Intune app catalog |
| Target fleet | 10,000 Windows 11 endpoints |
| Deadline | 3 weeks from plan date (by 01/09/2026) |
| Known constraints | Finance (500 users) needs it by end of week 1, highest priority; 5% of fleet (~500 devices) on 4GB RAM may struggle with v3.1 requirements |
| Previous version | v3.0 — no major rollout issues, still available in the Intune app catalog for rollback |
| Detection rule | Registry version string check, `HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1` |

## Purpose
Defines the ring structure, quantitative advance criteria, rollback triggers, and Finance-deadline resolution for the FinBridge Connect v3.1 rollout, so each gate between rings is a measurable go/no-go decision rather than a judgement call. Companion to [Phased Deployment Plan - FinBridge Connect v3.1.md](Phased%20Deployment%20Plan%20-%20FinBridge%20Connect%20v3.1.md) and [Guide - Adding a Windows App to the Intune Catalog (FinBridge Connect v3.1).md](Guide%20-%20Adding%20a%20Windows%20App%20to%20the%20Intune%20Catalog%20%28FinBridge%20Connect%20v3.1%29.md).

> **Note on data handling:** This document contains no credentials, tenant names, or device identifiers — safe for use per the Personal AI Usage Charter.

---

## 1. RING STRUCTURE

| Ring | Size | Duration | Who | Purpose | Intune assignment |
|---|---|---|---|---|---|
| **Ring 1 — Pilot** | 150 devices (1.5%) | 2 days (Day 1–2) | IT/help-desk staff + volunteer champions across departments, **standard hardware only** (excludes Finance, excludes the 4GB RAM cohort) | Prove the mechanics: install/uninstall commands, requirements config, and the registry detection rule work correctly on real, varied devices before anyone depends on the app for business use | **Required**, assigned to a static Azure AD security group `Pilot-FinBridgeConnect` (curated membership, not dynamic — pilot composition must be deliberate) |
| **Ring 2 — Early** | 1,350 devices (13.5%) | 5 days (Day 3–7) | Early-adopter business units beyond IT (excludes Finance and the 4GB RAM cohort, both handled separately — see Section 4 and the 4GB carve-out below) | Broaden exposure across more device models, network segments, and real day-to-day usage patterns than Ring 1 can cover, before committing the remaining ~80% of the fleet | **Required**, assigned to a dynamic Azure AD group scoped by department attribute (`Early-Adopters-FinBridgeConnect`), excluding the Ring 1 and 4GB RAM groups |
| **Ring 3 — Broad** | 8,000 devices (80%) main wave + 500 devices (5%) 4GB RAM sub-wave, gated separately | 12 days (Day 8–19) main wave; Day 17–19 4GB sub-wave | All remaining standard-hardware devices in the main wave; the 4GB RAM cohort only after its own go/no-go performance test passes (Section 3) | Complete the rollout across the fleet while keeping the known at-risk hardware cohort isolated from the main wave's blast radius | **Required**, assigned to a dynamic group = all Win11 devices **minus** Ring 1/Ring 2/Finance/4GB-RAM exclusion groups; the 4GB RAM sub-wave uses a separate dynamic group filtered on `physicalMemoryInBytes ≤ 4GB` |

Total: 150 + 1,350 + 8,000 + 500 = 10,000 devices (Finance's 500 users are counted within whichever ring Section 4 resolves them into, not added on top).

- Each ring is a **go/no-go gate** — the next ring's assignment is not created until the current ring's advance criteria (Section 2) are met or an explicit, documented exception is approved.
- The 4GB RAM cohort is deliberately excluded from Rings 1–3's main assignment groups throughout, and only receives its own assignment after the hardware-specific go/no-go test in Section 3 passes — it is never folded into a ring sized/timed for standard hardware.

---

## 2. ADVANCE CRITERIA

All criteria are measured from Intune's **Device install status** report (per app, per assignment group) and Service Desk ticket data tagged `FinBridgeConnect`, evaluated only once the monitoring period has elapsed.

| Gate | Install success rate (min. to advance) | Error rate threshold (max. to still advance) | User-reported issues (max. ticket rate) | Monitoring period (min. before evaluating) |
|---|---|---|---|---|
| **Ring 1 → Ring 2** | ≥ 95% of Ring 1 devices report **Installed** | ≤ 5% report **Failed** (combined install-command and detection-rule failures) | ≤ 2 tickets per 100 devices (≤ 3 tickets total across 150 devices) tagged `FinBridgeConnect` | 48 hours after Ring 1 assignment reaches ≥ 95% device check-in |
| **Ring 2 → Ring 3** | ≥ 97% of Ring 2 devices report **Installed** | ≤ 3% report **Failed** | ≤ 1 ticket per 100 devices (≤ 14 tickets total across 1,350 devices) tagged `FinBridgeConnect` | 72 hours after Ring 2 assignment reaches ≥ 95% device check-in |

**Hold condition (pause without full rollback):**
Triggered when a ring's install success rate falls **between 85% and the gate's minimum** (i.e. below target but above the rollback trigger in Section 3), or the ticket rate exceeds its threshold by up to 2×, **and** the failures are concentrated in an identifiable, non-widespread cause.

- *Example:* Ring 1 finishes its 48-hour monitoring period at 92% install success (below the 95% target, above the 85% rollback trigger), with failures concentrated on a single laptop model showing a driver conflict during silent install. **Action:** pause the Ring 2 assignment for up to 48 hours to confirm root cause and issue a fix/exclusion for that model, without reverting any already-installed Ring 1 devices to v3.0, and without treating this as a rollback event.

---

## 3. ROLLBACK TRIGGERS

| Trigger | Threshold & timeframe | Decision maker | Decision window | Exact Intune action |
|---|---|---|---|---|
| **Install failure rate** | ≥ 15% of a ring's assigned devices report **Failed** within 24 hours of assignment | DWP Endpoint Engineer (pre-authorised, threshold-based — no separate approval needed) | Immediate (automatic halt on breach, confirmed within 1 hour of the report showing the breach) | Halt further ring expansion: do **not** create the next ring's assignment. Existing ring's **Required** assignment for v3.1 is removed/disabled on the affected group; group is reassigned **Required** to v3.0 to restore known-good state. |
| **Application crash rate** | ≥ 5% of installed devices in a ring show app-crash telemetry within 48 hours of install | Service Owner / Change Advisory (rollback is a judgement call, not automatic) | 24 hours from breach detection to decision | If rollback approved: affected group's v3.1 **Required** assignment removed, group reassigned **Required** to v3.0; if held pending investigation, ring is frozen (no new devices added) until decided. |
| **Business-critical failure** | Any single occurrence of: FinBridge Connect v3.1 fails to establish connectivity to the core finance settlement system for a Finance user | DWP Endpoint Engineer + Finance IT liaison (joint, due to business impact) | 2 hours from first confirmed report | Immediate reassignment of the **entire Finance group** (not just the affected device) from v3.1 **Required** back to v3.0 **Required**, regardless of overall rollout percentage or timeline impact. |
| **4GB RAM device failures** | ≥ 10% failure/crash rate within the go/no-go sample (10–20 devices) or the full 4GB cohort, vs. ≤ 5% baseline expected on standard hardware | DWP Endpoint Engineer, with Service Owner notified | 8 hours from sample/cohort monitoring period ending | Isolate the entire 4GB RAM dynamic group: remove/disable its v3.1 **Required** assignment, reassign **Required** to v3.0 fleet-wide for that group; group remains excluded from any future v3.1 assignment until a hardware mitigation is confirmed and re-tested. |

All rollback actions are same-tool (Intune assignment changes only) — no manual reimage — since v3.0 remains published and assignable in the catalog throughout.

---

## 4. FINANCE DEADLINE RESOLUTION

The ring structure in Section 1 places Finance either inside Ring 2 (earliest: Day 3–7) or later, but Finance requires completion by end of week 1 (Day 5). Two options were evaluated:

### Option A — Compress the pilot to fit Finance into Ring 2 by end of week 1
- **Minimum safe pilot duration:** 24 hours (one full business day plus one overnight device check-in cycle) — enough to catch immediate, blocking failures (install command errors, detection rule misfires, install-time crashes) but not delayed-onset issues.
- **Risk introduced:** a 24-hour window will not surface problems that take longer to appear (e.g. periodic background-job conflicts, second-day performance degradation) — Finance would inherit that unvalidated risk as part of Ring 2's mass rollout, with no separate safety net, despite being the highest-priority, least risk-tolerant group.
- **Compensating control:** apply enhanced same-day monitoring specifically to the Finance sub-group within Ring 2 — dedicated help-desk queue with a 1-hour response SLA, a real-time install-status view filtered to Finance devices, and pre-authorised ability to fast-rollback just the Finance sub-group to v3.0 within the 2-hour business-critical decision window (Section 3), independent of the rest of Ring 2.

### Option B — Treat Finance as a separate priority Ring 0 before the main pilot
- **Structure:** Ring 0 = Finance's 500 devices only, Day 1–3, preceded by a same-day micro-validation on Day 0 (a few hours) using 10–20 non-Finance volunteer devices to confirm the basic install/uninstall/detection mechanics work at all before any Finance device is touched.
- **Advance conditions (to declare Ring 0 complete, not to open Ring 1):** install success ≥ 98% (stricter than Ring 1's 95%, given business criticality), zero P1 incidents, and explicit Finance stakeholder sign-off within 24 hours of full Ring 0 rollout.
- **Rollback plan:** identical business-critical trigger and action as Section 3 — any single core-settlement-connectivity failure reassigns the entire Finance group back to v3.0 **Required** within a 2-hour joint decision window (DWP Endpoint Engineer + Finance IT liaison).
- Ring 1 (Pilot) and Ring 2 (Early) then proceed on their Section 1 timeline unchanged, using the Day 0 micro-validation evidence as an additional (not replacement) data point.

### Recommendation
**Option B — a dedicated Ring 0 for Finance.**

**Justification:** Option A directly trades away validation depth for the fleet's single most risk-intolerant group, purely to satisfy a deadline that is unrelated to technical readiness — a 24-hour window is materially weaker than the 48-hour Ring 1 standard this plan otherwise treats as the minimum credible pilot. Option B keeps that same 48-hour-equivalent rigor for the general pilot (Section 1 is untouched) while still hitting Finance's deadline, because Ring 0 runs Day 1–3 in parallel with, not instead of, Ring 1 — Finance does not wait for Ring 1 to finish, and Ring 1 is not compressed to accommodate Finance. The only added cost is a short Day 0 micro-validation and coordination with a Finance IT liaison, which is small relative to the risk it removes from the highest-priority stakeholder group.

---

## Summary checklist

- [ ] Ring 1 (Pilot, 150 devices, standard hardware) assigned `Required` to `Pilot-FinBridgeConnect`.
- [ ] Ring 0 (Finance, 500 devices) run per Option B, in parallel with Ring 1, Day 1–3.
- [ ] Ring 2 (Early, 1,350 devices) and Ring 3 (Broad, 8,000 devices) assigned only after their preceding gate's advance criteria (Section 2) are met.
- [ ] 4GB RAM cohort (500 devices) excluded from all standard rings; deployed only after its own go/no-go test passes.
- [ ] All four rollback triggers (Section 3), their decision makers, decision windows, and exact Intune actions are known to the on-call engineer before Ring 0/Ring 1 starts.
- [ ] Hold condition (Section 2) understood as distinct from a rollback trigger — a pause, not a reversion.
