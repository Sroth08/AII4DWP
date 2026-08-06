Resolved.
Cause: DHCP scope option 006 (DNS Servers) for the Floor 3/Finance subnet was not fully updated following the overnight infrastructure migration, so the DHCP server (10.10.0.1) continued to lease the decommissioned DNS server address (10.10.3.250) to affected devices instead of the correct address (10.10.0.10).
Action: DHCP scope for the Floor 3 subnet was updated to assign DNS server 10.10.0.10; affected devices renewed their DHCP leases and Group Policy processed successfully afterward.
Preventive: Verify DHCP scope option 006 is updated on all relevant scopes as an explicit checked step before decommissioning legacy DNS servers in future migrations, and add a post-migration validation step checking DHCP Client Event 50036 across affected subnets/OUs to confirm correct DNS hand-out before closing the migration.
User confirmed working.
