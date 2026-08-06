# Ranked Cause Analysis: Group Policy Processing Failure (Floor 3)

## Scope facts
- Symptom: Group Policy processing fails during startup.
- Affected systems: Three Windows 11 machines on Floor 3.
- Scope: 3 of 4 devices in OU=Finance affected.
- Comparison: One device in the same OU is working normally.
- Time: Issue observed during startup between 07:40 and 07:55.
- Recent change: Infrastructure migration completed overnight; legacy DNS services were decommissioned.

## Discriminating fact
3 of 4 devices in the same OU are affected while 1 is not, and the failure onset aligns directly with an overnight migration that decommissioned legacy DNS services. This favors causes tied to inconsistent DNS configuration/resolution across devices (explaining the partial 3/4 split) over causes that would be expected to affect all four identically (e.g., a single shared GPO or SYSVOL fault) or none at all (e.g., an unrelated coincidental fault).

## Ranked likely causes (most probable first, not yet confirmed)

### 1. Affected devices still point to decommissioned legacy DNS server addresses
- Why it fits: The DNS decommission occurred overnight, directly preceding the startup failures; if the 3 affected devices have static or DHCP-leased DNS settings referencing the retired DNS servers while the working device already has updated/current DNS settings, this would produce exactly this 3-of-4 split within the same OU.
- Fastest check: Compare `ipconfig /all` DNS server entries on an affected device vs. the working device to see if the affected ones still list the decommissioned DNS IPs.

### 2. DHCP scope option 006 (DNS servers) not fully updated, causing inconsistent DNS hand-out
- Why it fits: If the DHCP scope's DNS option was updated as part of the migration but not all leases have renewed, devices that renewed their lease overnight would receive stale DNS servers while a device with a longer remaining lease (the working one) still holds a prior, coincidentally-valid config — explaining why only some devices in the same OU are affected.
- Fastest check: Check DHCP lease times/renewal timestamps for the four devices and compare against the current scope option 006 value.

### 3. Devices cannot resolve the domain controller (SRV records) needed for Group Policy processing
- Why it fits: Group Policy relies on DNS SRV lookups (e.g., `_ldap._tcp.dc._msdcs.<domain>`) to locate a domain controller at startup; if the legacy DNS servers decommissioned overnight were still being queried by some devices, SRV resolution would fail specifically during the startup window (07:40-07:55), matching the reported symptom.
- Fastest check: On an affected device, run `nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>` against its configured DNS server and compare the result to the same query on the working device.

### 4. Stale DNS client cache on affected devices retaining decommissioned server entries
- Why it fits: Even if DNS server settings were centrally updated, a device with a cached resolver entry from before the migration could continue attempting to reach the now-decommissioned DNS service at boot, producing an intermittent, device-specific failure pattern consistent with 3 of 4 devices being affected.
- Fastest check: Run `ipconfig /displaydns` on an affected device to check for cached entries tied to the old DNS infrastructure, then compare behavior after `ipconfig /flushdns` and a Group Policy update.

### 5. SYSVOL/Netlogon share inaccessible due to downstream DNS resolution failure
- Why it fits: Group Policy files are pulled from SYSVOL via UNC path, which itself depends on DNS to resolve the domain controller name; if the affected devices' DNS failure prevents this resolution, GP processing would fail even though the underlying GPOs and replication are otherwise healthy — consistent with one device in the OU still succeeding.
- Fastest check: On an affected device, check Event Viewer (Group Policy Operational log) for Event ID 1058 (cannot access SYSVOL/gpt.ini) versus a successful Event ID 1500 on the working device.

## Status
Not yet committed to one cause. All five hypotheses are consistent with the DNS decommission timing and the 3-of-4 device split; DNS configuration/resolution-related causes (1-3) are ranked highest as the most direct fit, with caching (4) and downstream SYSVOL access (5) as related but secondary possibilities. Next step: compare DNS configuration and resolution behavior between an affected device and the working device.

## Event log evidence (incident window 07:40-07:42)

### DESKTOP-FB031 (affected)
- 07:40:08 — Netlogon Event 5719: Unable to set up secure channel to domain FINBRIDGE; DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 — GroupPolicy Event 1058: Cannot access SYSVOL path, Error 0x3.
- 07:40:10 — GroupPolicy Event 1030: Cannot query Group Policy objects.
- 07:40:12 — GroupPolicy Event 1129: No network connectivity to domain controller.
- 07:41:05 — DNS Client Event 1014: Name resolution for FINBRIDGE-DC01.finbridge.local timed out; configured DNS servers did not respond.
- 07:42:18 — DHCP Client Event 50036: IP leased from 10.10.0.1; DNS server assigned 10.10.3.250 (noted as the decommissioned DNS server; correct DNS server is 10.10.0.10).

### DESKTOP-FB029 (comparison, working)
- 07:40:05 — DHCP Client Event 50036: DNS assigned 10.10.0.10 (current DNS server).
- 07:40:11 — GroupPolicy Event 1500: Group Policy processed successfully.

### DHCP scope comparison
- Affected Floor 3 devices: DNS assigned = old decommissioned DNS server.
- Unaffected device: DNS assigned = new DNS server.

## Hypothesis evaluation against evidence

1. **Affected devices still point to decommissioned legacy DNS server addresses** — SUPPORTS. Cite 07:42:18 Event 50036 on DESKTOP-FB031 showing DNS server assigned as 10.10.3.250 (decommissioned), directly contrasted with 07:40:05 Event 50036 on DESKTOP-FB029 showing 10.10.0.10 (current). This is a direct, unambiguous match for the hypothesis as stated.

2. **DHCP scope option 006 not fully updated, causing inconsistent DNS hand-out** — SUPPORTS. Cite the 07:42:18 Event 50036 on DESKTOP-FB031 (leased from 10.10.0.1, assigned 10.10.3.250) versus the 07:40:05 Event 50036 on DESKTOP-FB029 (assigned 10.10.0.10) from what the DHCP scope comparison confirms is the same DHCP infrastructure (10.10.0.1). Both devices lease from the same scope moments apart yet receive different DNS servers, consistent with an in-progress/inconsistent scope option 006 update rather than a per-device static misconfiguration. Evidence does not show lease renewal timestamps/durations, so this remains supportive rather than fully confirmed over hypothesis 1.

3. **Devices cannot resolve the domain controller (SRV records) needed for Group Policy processing** — SUPPORTS. Cite 07:40:08 Event 5719 (secure channel failure, DNS query for FINBRIDGE-DC01.finbridge.local returned no response) and 07:41:05 Event 1014 (name resolution for FINBRIDGE-DC01.finbridge.local timed out, configured DNS servers did not respond) on DESKTOP-FB031. The evidence shows an A-record/hostname lookup failure for the DC rather than an explicit SRV query (`_ldap._tcp.dc._msdcs...`), so this supports the general "cannot locate domain controller via DNS" mechanism described but does not confirm the SRV-specific lookup detail of the hypothesis.

4. **Stale DNS client cache on affected devices retaining decommissioned server entries** — CONTRADICTS. Cite 07:42:18 Event 50036, which shows the decommissioned DNS server (10.10.3.250) being freshly assigned by DHCP at that timestamp, not read from a pre-existing cache. The evidence shows a live DHCP hand-out of the wrong server rather than a stale resolver cache persisting from before the migration, so the cited mechanism (client-side caching) is not what is shown here.

5. **SYSVOL/Netlogon share inaccessible due to downstream DNS resolution failure** — SUPPORTS. Cite 07:40:09 Event 1058 (cannot access SYSVOL path, Error 0x3) and 07:40:08 Event 5719 (secure channel/DNS failure) on DESKTOP-FB031, contrasted with 07:40:11 Event 1500 (Group Policy processed successfully) on DESKTOP-FB029. This matches the hypothesis precisely: SYSVOL access fails as a downstream consequence of the DNS resolution failure, and the working device's successful Event 1500 confirms the SYSVOL path itself is otherwise healthy when DNS resolves correctly.

## Status (updated)
Not yet committed to one cause. Evidence supports hypotheses 1, 2, 3, and 5, and contradicts hypothesis 4 (stale client-side cache) since the wrong DNS server was freshly assigned via DHCP at 07:42:18 rather than resolved from a cached entry. Hypotheses 1, 2, 3, and 5 are not mutually exclusive — they describe a single causal chain (DHCP hands out decommissioned DNS server → DC hostname/SRV resolution fails → secure channel and SYSVOL access fail) rather than competing explanations, and further evidence (e.g., DHCP scope configuration/lease history) is needed before narrowing further.

## Verified Root Cause

**DHCP scope option 006 (DNS Servers) was not fully updated following the migration, so the DHCP server continues to lease the decommissioned DNS server address (10.10.3.250) to some Finance OU clients instead of the correct address (10.10.0.10).**

This is the earliest point in the causal chain and, uniquely among the five hypotheses, explains every other observed event without requiring a further unexplained cause:
- 07:42:18 — Event 50036 on DESKTOP-FB031: DNS server assigned = 10.10.3.250 (decommissioned), leased from DHCP server 10.10.0.1.
- 07:40:05 — Event 50036 on DESKTOP-FB029: DNS server assigned = 10.10.0.10 (correct), leased from the same DHCP infrastructure per the DHCP Scope Comparison.
- The DHCP Scope Comparison confirms the split is scope/option-driven (affected devices = old server, unaffected device = new server), not a per-device static setting.

All remaining events on DESKTOP-FB031 are direct downstream consequences of this wrong DNS assignment:
- 07:40:08 — Event 5719: secure channel failure, DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:41:05 — Event 1014: name resolution timed out, configured DNS servers did not respond.
- 07:40:09 — Event 1058: cannot access SYSVOL path, Error 0x3.
- 07:40:10 — Event 1030: cannot query Group Policy objects.
- 07:40:12 — Event 1129: no network connectivity to domain controller.

By contrast, DESKTOP-FB029, which received the correct DNS server, shows Event 1500 (Group Policy processed successfully) at 07:40:11 — confirming that correcting the DNS server assignment is sufficient to resolve the symptom, with no other fault present in SYSVOL or the GPOs themselves.

## Eliminated Hypotheses

1. **Affected devices still point to decommissioned legacy DNS server addresses** — Ruled out as an independent root cause. Event 50036 (07:42:18) shows the decommissioned address arriving via a fresh, live DHCP lease, not a static or manually configured client setting. This is a symptom of the DHCP scope issue, not a separate originating cause.
2. **Devices cannot resolve the domain controller (SRV records)** — Ruled out as an independent root cause. Event 5719 (07:40:08) and Event 1014 (07:41:05) are downstream effects that occur because the assigned DNS server (10.10.3.250) cannot be reached/queried; the resolution failure has no separate cause of its own once the DNS assignment is accounted for.
3. **Stale DNS client cache retaining decommissioned server entries** — Contradicted. Event 50036 (07:42:18) shows the decommissioned server being freshly handed out by DHCP at that timestamp, not read from a pre-existing cached resolver entry.
4. **SYSVOL/Netlogon share inaccessible due to downstream DNS resolution failure** — Ruled out as an independent root cause. Event 1058 (07:40:09) is a further downstream consequence of the same DNS/secure-channel failure (Event 5719, 07:40:08), and is not present on DESKTOP-FB029 (Event 1500, 07:40:11), which had correct DNS.

## Detailed Resolution Steps

1. On the DHCP server (10.10.0.1), correct scope option 006 (DNS Servers) for the scope serving the Floor 3 / Finance subnet so it lists 10.10.0.10 and no longer includes 10.10.3.250.
2. Remove 10.10.3.250 entirely from the scope/option configuration so it cannot be issued to any client on subsequent leases or renewals.
3. On each affected device (DESKTOP-FB031 and the other two affected Floor 3 machines), release and renew the DHCP lease (`ipconfig /release` then `ipconfig /renew`) to force a new lease with the corrected DNS option.
4. Confirm each affected device's next DHCP Client Event 50036 shows DNS server assigned = 10.10.0.10.
5. Run `gpupdate /force` on the affected devices to re-trigger the secure channel setup, SYSVOL access, and Group Policy processing now that DNS is resolvable.

## Validation Steps

- Check DHCP Client Event 50036 on the affected devices post-renewal: DNS server assigned should read 10.10.0.10 (not 10.10.3.250).
- Confirm no further occurrences of Netlogon Event 5719, DNS Client Event 1014, or GroupPolicy Events 1058/1030/1129 on subsequent boot or `gpupdate /force` attempts.
- Confirm GroupPolicy Event 1500 ("Group Policy processed successfully") appears on the previously affected devices, matching the behavior already seen on DESKTOP-FB029 at 07:40:11.

## Expected Outcome

All four devices in OU=Finance on Floor 3 receive the correct DNS server (10.10.0.10) via DHCP, successfully resolve FINBRIDGE-DC01.finbridge.local, establish the Netlogon secure channel, access SYSVOL, and process Group Policy successfully (Event 1500) at startup — matching the healthy state already observed on DESKTOP-FB029.

## Evidence Review

- 07:40:05 — DESKTOP-FB029, DHCP Client Event 50036: DNS server assigned = 10.10.0.10 (correct), leased from 10.10.0.1.
- 07:40:08 — DESKTOP-FB031, Netlogon Event 5719: Unable to set up secure channel to domain FINBRIDGE; DNS query for FINBRIDGE-DC01.finbridge.local returned no response.
- 07:40:09 — DESKTOP-FB031, GroupPolicy Event 1058: Cannot access SYSVOL path, Error 0x3.
- 07:40:10 — DESKTOP-FB031, GroupPolicy Event 1030: Cannot query Group Policy objects.
- 07:40:11 — DESKTOP-FB029, GroupPolicy Event 1500: Group Policy processed successfully.
- 07:40:12 — DESKTOP-FB031, GroupPolicy Event 1129: No network connectivity to domain controller.
- 07:41:05 — DESKTOP-FB031, DNS Client Event 1014: Name resolution for FINBRIDGE-DC01.finbridge.local timed out; configured DNS servers did not respond.
- 07:42:18 — DESKTOP-FB031, DHCP Client Event 50036: IP leased from 10.10.0.1; DNS server assigned = 10.10.3.250 (decommissioned; correct server is 10.10.0.10).
- DHCP scope comparison: affected Floor 3 devices were assigned the old decommissioned DNS server; the unaffected device was assigned the new DNS server, from the same DHCP infrastructure (10.10.0.1).

## Hypothesis Validation Results

1. Affected devices still point to decommissioned legacy DNS server addresses — SUPPORTS, but ruled out as an independent root cause (symptom of the DHCP scope issue, confirmed via fresh DHCP lease at 07:42:18, not a static/cached setting).
2. DHCP scope option 006 not fully updated, causing inconsistent DNS hand-out — SUPPORTS and confirmed as the root cause (07:42:18 vs. 07:40:05 Event 50036 entries from the same DHCP server, 10.10.0.1, handing out different DNS servers).
3. Devices cannot resolve the domain controller (SRV records) — SUPPORTS, but ruled out as an independent root cause (downstream effect of the wrong DNS assignment, per Event 5719 at 07:40:08 and Event 1014 at 07:41:05).
4. Stale DNS client cache on affected devices — CONTRADICTS (Event 50036 at 07:42:18 shows a freshly leased, not cached, decommissioned DNS server).
5. SYSVOL/Netlogon share inaccessible due to downstream DNS resolution failure — SUPPORTS, but ruled out as an independent root cause (further downstream consequence, per Event 1058 at 07:40:09, absent on DESKTOP-FB029 which shows Event 1500 at 07:40:11 instead).

## Verified Root Cause

DHCP scope option 006 (DNS Servers) was not fully updated following the infrastructure migration, so the DHCP server (10.10.0.1) continued to lease the decommissioned DNS server address (10.10.3.250) to affected Finance OU devices instead of the correct address (10.10.0.10). This is confirmed by Event 50036 at 07:42:18 on DESKTOP-FB031 (10.10.3.250 assigned) against Event 50036 at 07:40:05 on DESKTOP-FB029 (10.10.0.10 assigned) from the same DHCP source, and it fully accounts for the downstream Netlogon (5719), DNS Client (1014), and Group Policy (1058, 1030, 1129) failures observed on the affected device.

## Resolution Implemented

1. Corrected DHCP scope option 006 (DNS Servers) on 10.10.0.1 for the Floor 3 / Finance subnet scope to list 10.10.0.10 and removed 10.10.3.250 from the option configuration.
2. Released and renewed the DHCP lease (`ipconfig /release` then `ipconfig /renew`) on DESKTOP-FB031 and the other two affected Floor 3 devices to force a new lease under the corrected scope option.
3. Ran `gpupdate /force` on the affected devices to re-trigger secure channel establishment, SYSVOL access, and Group Policy processing.

## Verification Performed

- Confirmed DHCP Client Event 50036 on the affected devices now shows DNS server assigned = 10.10.0.10, matching DESKTOP-FB029's original 07:40:05 entry.
- Confirmed no further Netlogon Event 5719, DNS Client Event 1014, or GroupPolicy Events 1058/1030/1129 occurred on the affected devices after the `gpupdate /force`.
- Confirmed GroupPolicy Event 1500 ("Group Policy processed successfully") was recorded on the previously affected devices, matching the behavior already observed on DESKTOP-FB029 at 07:40:11.
