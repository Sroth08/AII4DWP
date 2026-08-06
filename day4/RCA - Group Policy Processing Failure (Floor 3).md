# Root Cause Analysis (RCA): Group Policy Processing Failure (Floor 3)

## Document Control
- Incident type: Group Policy processing failure during startup
- Affected OU: OU=Finance
- Affected location: Floor 3
- Incident window: 07:40 - 07:55
- Resolution time: 08:15 AM
- Source hosts in events: DESKTOP-FB031 (affected), DESKTOP-FB029 (comparison, unaffected)
- Analyst role: DWP Endpoint Analyst
- Date of analysis: 2026-08-06

## 1. Executive Summary
Three of four Windows 11 devices in OU=Finance on Floor 3 failed to process Group Policy during startup between 07:40 and 07:55, following an overnight infrastructure migration in which legacy DNS services were decommissioned. Investigation of event logs on an affected device (DESKTOP-FB031) and a comparison device in the same OU (DESKTOP-FB029) confirmed the affected devices were assigned the decommissioned DNS server (10.10.3.250) via DHCP, while the unaffected device was assigned the correct DNS server (10.10.0.10). The decommissioned DNS server did not respond, preventing domain controller resolution, secure channel establishment, and SYSVOL access, which caused Group Policy processing to fail. The root cause was identified as DHCP scope option 006 (DNS Servers) not being fully updated for the Floor 3/Finance subnet following the migration. The DHCP scope was corrected at 08:15 AM, affected devices renewed their leases, and Group Policy subsequently processed successfully with no further Group Policy, Netlogon, or DNS-related errors observed.

## 2. Incident Overview
- Symptom: Group Policy processing fails during startup.
- Trigger context: Infrastructure migration completed overnight; legacy DNS services were decommissioned.
- Onset: Observed during startup between 07:40 and 07:55.
- Resolution: DHCP scope corrected and verified at 08:15 AM.
- Duration: Approximately 35 minutes from first observed failure (07:40) to confirmed resolution (08:15).

## 3. Business Impact
- Three of four devices in OU=Finance on Floor 3 were unable to complete Group Policy processing during startup, within the 07:40-07:55 window.
- Affected devices could not establish a Netlogon secure channel to the domain or access SYSVOL during this window (Events 5719, 1058, 1030, 1129).
- One device in the same OU (DESKTOP-FB029) continued to process Group Policy successfully throughout, indicating impact was limited to the three devices with incorrect DNS assignment rather than the entire OU or floor.
- No information on downstream user/business consequences (e.g., helpdesk ticket volume, financial impact) was provided and none is assumed.

## 4. Scope of Impact
- Affected systems: Three Windows 11 machines on Floor 3.
- Scope: 3 of 4 devices in OU=Finance affected.
- Comparison: One device in the same OU (DESKTOP-FB029) was working normally throughout.
- Confirmed affected device in evidence: DESKTOP-FB031.

## 5. Full Timeline of Events
- Overnight (prior to 07:40): Infrastructure migration completed; legacy DNS services decommissioned.
- 07:40:05 — DESKTOP-FB029, DHCP Client Event 50036: DNS server assigned = 10.10.0.10 (correct), leased from 10.10.0.1.
- 07:40:08 — DESKTOP-FB031, Netlogon Event 5719: Unable to set up secure channel to domain FINBRIDGE; DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 — DESKTOP-FB031, GroupPolicy Event 1058: Cannot access SYSVOL path, Error 0x3.
- 07:40:10 — DESKTOP-FB031, GroupPolicy Event 1030: Cannot query Group Policy objects.
- 07:40:11 — DESKTOP-FB029, GroupPolicy Event 1500: Group Policy processed successfully.
- 07:40:12 — DESKTOP-FB031, GroupPolicy Event 1129: No network connectivity to domain controller.
- 07:41:05 — DESKTOP-FB031, DNS Client Event 1014: Name resolution for FINBRIDGE-DC01.finbridge.local timed out; configured DNS servers did not respond.
- 07:42:18 — DESKTOP-FB031, DHCP Client Event 50036: IP leased from 10.10.0.1; DNS server assigned = 10.10.3.250 (decommissioned).
- 08:15 AM — DHCP scope for the Floor 3 subnet updated to assign DNS server 10.10.0.10; affected devices renewed their DHCP leases.
- Post-08:15 AM — Group Policy processed successfully on affected devices; affected machines successfully contacted FINBRIDGE domain controllers; no further Group Policy, Netlogon, or DNS-related errors observed.

## 6. Evidence Collected

### DESKTOP-FB031 (affected)
- 07:40:08 — Netlogon Event 5719: Unable to set up secure channel to domain FINBRIDGE; DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 — GroupPolicy Event 1058: Cannot access SYSVOL path, Error 0x3.
- 07:40:10 — GroupPolicy Event 1030: Cannot query Group Policy objects.
- 07:40:12 — GroupPolicy Event 1129: No network connectivity to domain controller.
- 07:41:05 — DNS Client Event 1014: Name resolution for FINBRIDGE-DC01.finbridge.local timed out; configured DNS servers did not respond.
- 07:42:18 — DHCP Client Event 50036: IP leased from 10.10.0.1; DNS server assigned 10.10.3.250 (noted as the decommissioned DNS server; correct DNS server is 10.10.0.10).

### DESKTOP-FB029 (comparison, unaffected)
- 07:40:05 — DHCP Client Event 50036: DNS assigned 10.10.0.10 (current DNS server).
- 07:40:11 — GroupPolicy Event 1500: Group Policy processed successfully.

### DHCP Scope Comparison
- Affected Floor 3 devices: DNS assigned = old decommissioned DNS server.
- Unaffected device: DNS assigned = new DNS server.
- Both leases sourced from the same DHCP server (10.10.0.1).

## 7. Investigation Process
1. Collected scope facts: symptom, affected systems, OU scope (3 of 4), comparison device, time window, and recent change (overnight migration with legacy DNS decommission).
2. Generated five ranked hypotheses based on scope facts alone, without evidence, focusing on DNS-related causes given the timing correlation with the DNS decommission.
3. Collected event log evidence from the affected device (DESKTOP-FB031), the comparison device (DESKTOP-FB029), and the DHCP scope comparison.
4. Evaluated each hypothesis individually against the evidence, marking each as SUPPORTS, CONTRADICTS, or NEUTRAL with cited Event IDs and timestamps.
5. Narrowed the supported hypotheses to a single verified root cause by identifying which hypothesis represented the earliest point in the causal chain and fully explained all downstream events without requiring a further unexplained cause.
6. Documented the resolution actions taken and the verification evidence confirming recovery.

## 8. Hypothesis Analysis

| # | Hypothesis | Result | Key Evidence |
|---|---|---|---|
| 1 | Affected devices still point to decommissioned legacy DNS server addresses | SUPPORTS (symptom, not independent root cause) | Event 50036, 07:42:18 (10.10.3.250) vs. Event 50036, 07:40:05 (10.10.0.10) |
| 2 | DHCP scope option 006 not fully updated, causing inconsistent DNS hand-out | SUPPORTS — confirmed root cause | Event 50036 entries at 07:42:18 and 07:40:05, same DHCP server (10.10.0.1), different DNS servers issued |
| 3 | Devices cannot resolve the domain controller (SRV records) | SUPPORTS (downstream effect, not independent root cause) | Event 5719, 07:40:08; Event 1014, 07:41:05 |
| 4 | Stale DNS client cache retaining decommissioned server entries | CONTRADICTS | Event 50036, 07:42:18, shows a freshly leased (not cached) decommissioned DNS server |
| 5 | SYSVOL/Netlogon share inaccessible due to downstream DNS resolution failure | SUPPORTS (downstream effect, not independent root cause) | Event 1058, 07:40:09, absent on DESKTOP-FB029 (Event 1500, 07:40:11 instead) |

## 9. Verified Root Cause
DHCP scope option 006 (DNS Servers) was not fully updated following the infrastructure migration, so the DHCP server (10.10.0.1) continued to lease the decommissioned DNS server address (10.10.3.250) to affected Finance OU devices on Floor 3 instead of the correct address (10.10.0.10). This is confirmed by Event 50036 at 07:42:18 on DESKTOP-FB031 (10.10.3.250 assigned) against Event 50036 at 07:40:05 on DESKTOP-FB029 (10.10.0.10 assigned) from the same DHCP source, and it fully accounts for the downstream Netlogon (5719), DNS Client (1014), and Group Policy (1058, 1030, 1129) failures observed on the affected device.

## 10. Resolution Activities
1. DHCP scope for the Floor 3 subnet was updated to assign DNS server 10.10.0.10.
2. Affected devices renewed their DHCP leases.
3. Group Policy processed successfully afterward.
4. Resolution completed and confirmed at 08:15 AM.

## 11. Verification of Recovery
- Affected machines successfully contacted FINBRIDGE domain controllers.
- Group Policy processing completed successfully.
- No further Group Policy, Netlogon, or DNS-related errors observed.

## 12. 5 Why Analysis
1. **Why did Group Policy processing fail during startup?** Because the affected devices could not establish a Netlogon secure channel or access SYSVOL (Events 5719, 1058, 1030, 1129).
2. **Why could affected devices not establish the secure channel or access SYSVOL?** Because DNS name resolution for FINBRIDGE-DC01.finbridge.local timed out — the configured DNS server did not respond (Event 1014).
3. **Why did the configured DNS server not respond?** Because the affected devices had been assigned the decommissioned DNS server address, 10.10.3.250, rather than the correct address, 10.10.0.10 (Event 50036, 07:42:18).
4. **Why were affected devices assigned the decommissioned DNS server?** Because the DHCP scope for the Floor 3/Finance subnet handed out 10.10.3.250 via lease, while the same DHCP server issued the correct address (10.10.0.10) to the unaffected comparison device (Event 50036, 07:40:05).
5. **Why did the DHCP scope hand out the decommissioned DNS server after the migration?** The investigation evidence confirms the scope option 006 was not fully updated for this subnet at the time of the affected devices' leases, but does not include information on the underlying process or administrative reason the update was incomplete (e.g., change sequencing, scope replication, or scope selection during the migration). This is not assumed and is flagged as an open item for process review.

## 13. Preventive Actions
- Verify DHCP scope option 006 is updated on all relevant scopes as an explicit, checked step within the infrastructure migration/decommission process, before legacy DNS servers are taken offline.
- Confirm no active scope, reservation, or superscope still references a DNS server address prior to decommissioning it.
- Add a post-migration validation step that checks DHCP Client Event 50036 (or equivalent) across affected subnets/OUs to confirm all devices are receiving the intended DNS server before considering the migration complete.

## 14. Lessons Learned
- The 3-of-4 device split within the same OU was a key discriminating fact that pointed toward a configuration/DNS-assignment inconsistency rather than a shared GPO or SYSVOL fault affecting all devices equally.
- Comparing an affected device against a working device in the same OU (DESKTOP-FB031 vs. DESKTOP-FB029) was an effective and fast way to isolate the differing DNS assignment as the discriminator.
- DHCP Client Event 50036 provided a direct, fast-to-check confirmation of the DNS server actually assigned to a device, which was more conclusive than symptom-level Group Policy/Netlogon events for identifying the originating cause.
- A single misconfigured DHCP scope option produced a multi-symptom failure chain (secure channel, SYSVOL, Group Policy) that could otherwise appear as several unrelated issues if events were reviewed in isolation rather than correlated by timestamp and device.
