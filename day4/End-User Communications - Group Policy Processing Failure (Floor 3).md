# End-User Communications: Group Policy Processing Failure (Floor 3)

## Audience 1 - Non-Technical Executive

Your data and system access were never at risk during this morning's issue. A small number of Finance workstations on Floor 3 experienced a temporary technical issue applying routine security settings after startup, caused by an outdated network configuration left over from an overnight system upgrade. This has been fully resolved: affected devices have been corrected and verified as working normally. No action is required from you at this time.

## Audience 2 - Affected End Users

This morning, a few Floor 3 Finance computers had trouble applying some standard system settings right after startup, because they were briefly using an outdated network setting left over from an overnight system upgrade. This has now been fixed — affected computers have been updated and are working normally again, and no further issues have been found. If you notice anything similar (like settings not applying properly after restarting your computer), please restart your machine and contact the IT Service Desk if the issue continues. Thanks for your patience!

## Audience 3 - Engineer-to-Engineer Internal Note

**Incident:** Group Policy processing failure on startup, 3 of 4 devices in OU=Finance, Floor 3, 07:40-07:55.

**Root cause:** DHCP scope option 006 (DNS Servers) for the Floor 3/Finance subnet was not fully updated following the overnight infrastructure migration. The DHCP server (10.10.0.1) continued to lease the decommissioned DNS server address to affected clients instead of the current one.

**DHCP scope configuration issue:** Affected device (DESKTOP-FB031) received DNS server 10.10.3.250 via DHCP Client Event 50036 at 07:42:18. Comparison device (DESKTOP-FB029), same OU and same DHCP server, received the correct DNS server 10.10.0.10 via Event 50036 at 07:40:05 — confirming the split was scope/option-driven, not a per-device static misconfiguration.

**DNS details:** 10.10.3.250 = decommissioned legacy DNS server (no longer answering queries). 10.10.0.10 = correct, current DNS server. Downstream effects on the affected device from the bad DNS assignment: Netlogon Event 5719 (07:40:08, secure channel failure, no response resolving FINBRIDGE-DC01.finbridge.local), DNS Client Event 1014 (07:41:05, name resolution timeout), GroupPolicy Event 1058 (07:40:09, SYSVOL path inaccessible, Error 0x3), Event 1030 (07:40:10, cannot query GPOs), Event 1129 (07:40:12, no connectivity to DC).

**Resolution steps:**
1. Updated DHCP scope option 006 for the Floor 3 subnet to assign DNS server 10.10.0.10.
2. Affected devices released/renewed DHCP leases to pick up the corrected DNS option.
3. Group Policy processed successfully afterward.
4. Resolution completed at 08:15 AM.

**Verification evidence:** Affected machines successfully contacted FINBRIDGE domain controllers; Group Policy processing completed successfully; no further Group Policy, Netlogon, or DNS-related errors observed post-resolution.

**Preventive actions:** Verify DHCP scope option 006 is updated on all relevant scopes as an explicit checked step before decommissioning legacy DNS servers in future migrations; confirm no active scope/reservation/superscope still references a DNS server prior to decommission; add a post-migration validation step checking DHCP Client Event 50036 across affected subnets/OUs to confirm correct DNS hand-out before closing the migration.
