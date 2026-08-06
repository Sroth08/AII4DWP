Root cause: Win11 upgrade removed legacy VPN client; Intune did not re-deploy new client due to detection-rule gap.
Action taken: Removed stale VPN registry entries under HKLM\SOFTWARE<vendor>; force-triggered Intune sync; new client deployed; split-tunnel config applied.
Verification: Connectivity confirmed to all internal subnets.
Data impact: No data loss.
Preventive action needed: Fix/close the Intune detection-rule gap so Win11-upgraded endpoints reliably trigger new VPN client re-deployment automatically.
