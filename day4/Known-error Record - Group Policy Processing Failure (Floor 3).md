# Known-error Record - Group Policy Processing Failure After DNS Decommission (Floor 3)

Symptom: Affected users experience Group Policy failing to process during startup, with no visible error on screen but delayed or missing policy application.

Cause: Affected devices were assigned a decommissioned DNS server address via DHCP because scope option 006 (DNS Servers) for the subnet had not been fully updated following an infrastructure migration, preventing domain controller resolution and secure channel/SYSVOL access.

Scope: 3 of 4 Windows 11 devices in OU=Finance on Floor 3; only devices leased the decommissioned DNS server were affected, while a device in the same OU with the correct DNS server was unaffected.

Workaround: On an affected device, manually release and renew the DHCP lease (or set the correct DNS server, 10.10.0.10) and run `gpupdate /force` to restore Group Policy processing without waiting for the wider scope fix.

Permanent Fix: Update DHCP scope option 006 for the affected subnet to assign only the correct DNS server (10.10.0.10) and remove the decommissioned address (10.10.3.250) so no device can be leased the old server again.

How to Spot It:
- Event IDs: Netlogon Event 5719 (secure channel failure), DNS Client Event 1014 (name resolution timeout), GroupPolicy Events 1058 (SYSVOL inaccessible, Error 0x3), 1030 (cannot query GPOs), and 1129 (no connectivity to domain controller); a working device instead shows GroupPolicy Event 1500.
- Error messages: "Cannot access SYSVOL path, Error 0x3" and "No network connectivity to domain controller."
- DNS symptoms: Name resolution for the domain controller (e.g., FINBRIDGE-DC01.finbridge.local) times out because the configured DNS server does not respond.
- DHCP indicators: DHCP Client Event 50036 shows the assigned DNS server as the decommissioned address rather than the current one; comparing this event across affected and unaffected devices confirms the split.
