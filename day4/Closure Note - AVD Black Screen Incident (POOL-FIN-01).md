# Closure Note: AVD Black Screen Incident (POOL-FIN-01)

Resolved. Cause: Graphics driver regression (`igdumd64.dll` v31.0.101.4146) introduced in the overnight image update to POOL-FIN-01, causing `dwm.exe` to crash on session load and produce black screens. Action: Drained POOL-FIN-01 and rolled back affected session hosts to the prior known-good image build. Preventive: Mandatory canary/pilot validation and automated crash alerting to be added before future pool-wide image deployments. User confirmed working.
