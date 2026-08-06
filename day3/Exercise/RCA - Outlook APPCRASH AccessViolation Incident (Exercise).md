# Root Cause Analysis (RCA): Outlook APPCRASH AccessViolation Incident (Exercise)

## Document Control
- Incident type: Application crash / endpoint productivity incident
- Affected app: OUTLOOK.EXE (Microsoft Office 16)
- Analysis window: 2024-03-15 09:13:44 to 09:18:05
- Primary host context: Windows 11 endpoint (based on module versioning)
- Analyst role: DWP Endpoint Analyst
- Date of analysis: 2026-08-05

## Executive Summary
Outlook crashed repeatedly within minutes, with identical Event ID 1000 crash signatures showing exception code 0xc0000005 (access violation) in KERNELBASE.dll at the same fault offset. Windows Error Reporting logged an APPCRASH bucket (Event ID 1001), and .NET Runtime logged an unhandled System.AccessViolationException (Event ID 1026).

Most likely cause: a repeatable memory access violation in Outlook runtime path, likely triggered by add-in or profile/runtime interaction, resulting in deterministic crash behavior at the same module and fault offset.

## Event ID Explanations

### Event ID 1000 (Source: Application Error)
Records that an application process crashed. It captures the faulting executable, module, exception code, and offset to identify the crash signature.

What it shows here:
- Faulting app: OUTLOOK.EXE (16.0.17126.20132)
- Faulting module: KERNELBASE.dll (10.0.22621.3155)
- Exception code: 0xc0000005 (access violation)
- Fault offset: 0x000000000003a4b2
- Repeat occurrence with same signature confirms recurring fault pattern.

### Event ID 1001 (Source: Windows Error Reporting)
Records that Windows Error Reporting (WER) captured and categorized the crash into a fault bucket for telemetry/correlation.

What it shows here:
- Event Name: APPCRASH
- Fault bucket ID present, indicating Microsoft/WER-style signature grouping.
- Confirms OS crash reporting pipeline observed the same failure.

### Event ID 1026 (Source: .NET Runtime)
Records an unhandled managed exception that terminates the process.

What it shows here:
- Application: OUTLOOK.EXE
- Framework: v4.0.30319
- Exception: System.AccessViolationException
- Confirms crash had managed runtime visibility and ended process execution.

## Reconstructed Sequence (Plain English)
1. Outlook started at 09:13:44.
2. Around 09:14:22, Outlook crashed (Event 1000) due to access violation in KERNELBASE.dll.
3. User (or auto-restart behavior) launched Outlook again.
4. At 09:17:45, Outlook crashed a second time with the exact same crash signature (same module and fault offset), indicating repeatable failure.
5. At 09:18:01, Windows Error Reporting registered the APPCRASH in a fault bucket (Event 1001).
6. At 09:18:05, .NET Runtime logged unhandled System.AccessViolationException (Event 1026), reinforcing that the process terminated due to memory access fault.

## Most Likely Cause With Evidence

### Most Likely Cause
A deterministic application-layer fault in Outlook execution path caused repeated access violations, most likely triggered by an Outlook add-in, corrupted profile/component interaction, or Office binary/state inconsistency.

### Why this is most likely
- Same application (OUTLOOK.EXE), same module (KERNELBASE.dll), same exception code (0xc0000005), and same fault offset across repeated crashes.
- The recurrence within minutes suggests a stable trigger condition rather than a one-off transient glitch.
- WER APPCRASH bucketing and .NET unhandled exception corroborate the same crash condition from different telemetry sources.

### Evidence points
- 09:14:22 Event 1000: first crash signature.
- 09:17:45 Event 1000: second crash with matching signature.
- 09:18:01 Event 1001: APPCRASH captured by WER.
- 09:18:05 Event 1026: unhandled System.AccessViolationException logged.

## Detailed 5-Why Analysis

### Problem Statement
Outlook repeatedly crashed, preventing stable email client access.

### Why 1
Why could the user not use Outlook?
- Outlook process terminated repeatedly due to application crashes (Event 1000).

### Why 2
Why did Outlook terminate?
- It encountered access violation exception 0xc0000005 in KERNELBASE.dll at a consistent fault offset.

### Why 3
Why was an access violation triggered repeatedly?
- A repeatable code path in Outlook runtime likely attempted invalid memory access under a consistent startup/use condition.

### Why 4
Why did that repeatable code path keep executing?
- The same user context and startup state likely reloaded the same trigger (for example: add-in load sequence, profile object/state, or corrupted client-side cache/config element).

### Why 5
Why was the trigger not prevented before user impact?
- Endpoint controls and proactive health checks did not isolate the failing component before production use.
- No early automated recovery action (safe mode launch/add-in isolation/profile validation) occurred before repeated crashes affected productivity.

## Root Cause
Primary root cause: repeatable Outlook runtime fault manifesting as access violation (0xc0000005), most likely due to problematic add-in/profile-state interaction or Office client state corruption.

## Contributing Factors
- Immediate app relaunch reproduced same trigger condition.
- Lack of automatic fallback to safe mode/isolation path before second failure.
- Limited telemetry scope in supplied events (no add-in list, no stack trace dump).

## Corrective Actions (Recommended)
1. Immediate containment
- Launch Outlook in safe mode and validate crash behavior without COM add-ins.
- Disable non-Microsoft add-ins incrementally and retest.

2. Client integrity
- Run Office Quick Repair; if unresolved, run Online Repair.
- Clear/refresh Outlook local profile cache state where policy permits.

3. Profile and mailbox checks
- Create a fresh Outlook profile and test.
- Validate mailbox size/corruption indicators and OST integrity.

4. Platform and version hygiene
- Verify Office build health and patch consistency across affected cohort.
- Confirm no conflicting endpoint security plugin update at incident time.

5. Escalation and evidence
- Collect crash dumps (LocalDumps/ProcDump) for symbolized stack analysis.
- Correlate with WER fault bucket history and known Microsoft advisories.

## Validation and Closure Criteria
- Outlook launches and remains stable through agreed soak period (for example 30-60 minutes active use).
- No new Event 1000 for OUTLOOK.EXE in observation window.
- No new Event 1026 AccessViolation for OUTLOOK.EXE.
- User confirms normal send/receive and calendar operations.

## Residual Risk
Without dump-level stack trace or add-in telemetry, the cause is highly probable but not fully proven to a single component. Residual risk remains until controlled isolation tests are completed.

## Assumptions and Evidence Limits
- Provided data is a subset of Application log events only.
- No Security log correlation, dump stack traces, add-in inventory, or endpoint change timeline was provided.
- Conclusions therefore prioritize strongest evidence pattern: repeated identical access violation crash signature.
