# Script Comparison - Login Evidence Collection

One-line note: Fixed reliability and comparability gaps by adding normalized section status and summary metrics, stronger safe error capture, Security 4624 and 4625 evidence, and direct Intune Win32 app state collection so engineers can quickly compare affected devices without reinterpreting raw logs.

## Version Comparison

| Area | Original Script | Improved Script | Why It Matters |
|---|---|---|---|
| Output comparability | Sections stored as array only | Sections stored as ordered map with status and itemCount plus summary metrics | Makes device-to-device comparison fast during incidents |
| DryRun behavior | Plan only | Plan plus log availability and environment checks | Confirms collection feasibility before live run |
| Error capture | Basic exception message | Captures section, operation, exception type, and fullyQualifiedErrorId | Improves troubleshooting when evidence is incomplete |
| Security logon evidence | Not collected | Security log 4624 and 4625 included | Distinguishes auth failure from endpoint slowness |
| Intune app state | IME log tails only | IME log tails plus Win32 app state registry nodes | Adds direct evidence for deployment and detection state |
| Startup and service triage | Full inventory only | Full inventory plus app-hint filtered candidates | Speeds focus on likely problematic components |
| Group policy signal | Not included | GroupPolicy operational log included | Helps explain logon delay after migration/enrollment |
| Process collection robustness | Potential StartTime access errors | Safe process property accessor used | Reduces failures while still collecting high-value process data |
| Final write robustness | Unprotected file write | Safe write wrapper and output directory creation | Prevents silent failure at output stage |
