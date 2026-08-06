# RCA - Print Spooler Repeated Crash and Logon Failure Incident (Exercise)

## Incident Summary
- **Incident Type:** Endpoint printing service failure
- **System:** Windows endpoint (System log)
- **Primary Component:** Print Spooler (`spoolsv` / Print Spooler service)
- **Observation Window:** 2024-03-15 10:01:14 to 10:03:50
- **Business Impact:** Printing unavailable and print-dependent workflows interrupted.

## Event ID Interpretation

### Event ID 7034 (Service Control Manager)
Records that a service terminated unexpectedly. This event does not include a configured recovery action in the message body; it mainly confirms an abnormal service stop and increments termination count.

### Event ID 7031 (Service Control Manager)
Records that a service terminated unexpectedly and that Service Control Manager will apply a configured recovery action (for example, restart after a delay). In this case, restart is scheduled after 60,000 ms.

### Event ID 7023 (Service Control Manager)
Records that a service terminated and returned a specific service error code/message. Here the terminating error is: **"The specified module could not be found."** This strongly indicates a missing or inaccessible dependency (DLL/module/driver component) required by the Print Spooler runtime path.

### Event ID 7038 (Service Control Manager)
Records that a service failed to log on with its configured account due to logon rights/policy restrictions or invalid credentials context. Here, the service account `NT AUTHORITY\SYSTEM` was denied the required logon type on this computer.

## Reconstructed Sequence of Events (Plain English)
1. At 10:01:14, Print Spooler crashed unexpectedly for the first time.
2. At 10:01:45, it crashed again, indicating the problem persisted after restart/attempted recovery.
3. At 10:02:16, it crashed a third time, showing repeated instability.
4. At 10:02:47, a fourth unexpected termination occurred and SCM explicitly reported that it would restart the service after 60 seconds.
5. At 10:03:49, the service terminated with a clearer error: a required module could not be found.
6. At 10:03:50, immediately after, SCM logged that Print Spooler could not log on as `NT AUTHORITY\SYSTEM` because the account lacked the required logon type on the machine.

In practical terms, the service repeatedly crashed, then recovery attempts surfaced two deeper issues: a missing component and a policy/account-rights failure preventing stable service startup.

## Most Likely Cause
A **combined configuration and integrity issue** is most likely:
- **Primary technical trigger:** Missing/corrupted print-related module (often tied to printer driver package, print provider, or dependent DLL) caused spooler termination (`7023`).
- **Compounding factor:** Local/Group Policy security rights were altered so `SYSTEM` did not retain expected service logon rights, causing service startup/logon failure (`7038`).

This pattern is commonly seen after an incomplete driver change, endpoint hardening misconfiguration, broken image baseline, or policy drift.

## 5 Whys Analysis

### Problem Statement
The Print Spooler service repeatedly crashed and then failed to start correctly, causing printing outage.

1. **Why** did printing fail?
   - Because the Print Spooler service was not running reliably.
2. **Why** was the Print Spooler not running reliably?
   - Because it terminated unexpectedly multiple times and failed during restart attempts.
3. **Why** did it terminate during restart attempts?
   - Because required runtime module(s) for spooler/print stack were missing or inaccessible (`7023`).
4. **Why** were required module(s) missing/inaccessible?
   - Most likely due to incomplete printer driver update/removal, corrupted print subsystem files, or failed software deployment affecting print components.
5. **Why** did recovery still fail even after retry/restart?
   - Because system/service security rights were misconfigured, and `NT AUTHORITY\SYSTEM` was denied the required logon type (`7038`), preventing clean service startup.

### Root Cause Statement
The outage was caused by **print subsystem integrity failure (missing module)** combined with **service account rights misconfiguration**. Either issue alone can destabilize spooler; together they produced repeated crashes and startup failure.

## Contributing Factors
- Potential ungoverned printer driver lifecycle (install/remove/update).
- Potential GPO/local security policy drift affecting service logon rights.
- Lack of pre-deployment validation for print stack dependencies.
- Recovery action existed, but no automated post-failure diagnostics to isolate missing module quickly.

## Corrective Actions
1. Validate and repair print subsystem binaries and dependencies (SFC/DISM; verify spooler dependencies and print provider registration).
2. Remove/reinstall suspect third-party printer drivers and packages; prioritize vendor-signed current versions.
3. Reset and validate Print Spooler service configuration to defaults where appropriate.
4. Restore required local security rights for service operation and confirm effective policy after GP refresh.
5. Restart spooler and confirm stability under test print load.

## Preventive Actions
1. Introduce controlled printer driver change process with rollback checkpoints.
2. Add endpoint compliance checks for spooler service rights and startup state.
3. Monitor recurring SCM events (`7034`, `7031`, `7023`, `7038`) with alert thresholds.
4. Add post-patch validation runbook for print functionality on pilot ring before broad rollout.
5. Keep a known-good baseline of print drivers and subsystem configuration in endpoint standards.

## Evidence Used
- System log Event ID 7034 at 10:01:14, 10:01:45, 10:02:16
- System log Event ID 7031 at 10:02:47
- System log Event ID 7023 at 10:03:49
- System log Event ID 7038 at 10:03:50

## Confidence and Assumptions
- **Confidence:** Medium-High (event chain is internally consistent).
- **Assumptions:** No additional Application log crash signatures were provided (for example faulting module name), so specific missing file/module is inferred from SCM message only.
