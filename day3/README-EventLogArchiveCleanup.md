# EventLogArchiveCleanup.ps1

This document explains how to safely use `EventLogArchiveCleanup.ps1` on Windows endpoints.

## What the script does

- Inspects selected event logs and identifies logs eligible for cleanup.
- Eligibility rule: only logs whose newest event is older than cutoff are targeted.
- Archives each eligible log to `.evtx` before cleanup.
- Supports dry run to print how many records would be deleted.
- Uses per-operation try/catch to prevent one failure from stopping the whole run.
- Logs all actions to a timestamped log file.
- Writes a summary at the end.
- Supports rollback mode for archived files from a previous run.

## Script location

- `day3/EventLogArchiveCleanup.ps1`

## Parameters

- `-DryRun`
  - Preview mode.
  - Prints/logs per-log and total record counts that would be deleted.
  - No archive or cleanup changes are made.

- `-OlderThanDays <int>`
  - Age threshold in days.
  - Default: `3`.
  - The script only targets logs where `LastWriteTime` is older than this threshold.

- `-LogNames <string[]>`
  - Event logs to process.
  - Default: `Application`, `System`, `Security`.

- `-WorkingRoot <string>`
  - Root storage for logs, archives, manifests, and rollback restore files.
  - Default: `$env:ProgramData\DWPEventLogMaintenance`.

- `-Rollback`
  - Runs rollback mode instead of archive/cleanup mode.

- `-RollbackManifest <string>`
  - Optional explicit path to a manifest JSON file.
  - If omitted in rollback mode, latest manifest is selected automatically.

## Idempotency behavior

- For each log, if an archive file for today already exists, that log is skipped.
- This prevents duplicate archive files for the same day and log.

## Rollback behavior

- Rollback mode reads manifest entries and restores archived `.evtx` files into a dated restore folder.
- Restore output folder: `RollbackRestore/Restore_yyyyMMdd_HHmmss` under `WorkingRoot`.
- This is a safe rollback of archived data files for review/recovery.
- Note: Windows does not provide a safe native API to write archived events back into live channels with original metadata.

## Files created under WorkingRoot

- `Logs/EventLogArchiveCleanup_yyyyMMdd_HHmmss.log`
- `Archives/<LogName>_yyyyMMdd.evtx`
- `Manifests/Manifest_run_yyyyMMdd_HHmmss.json`
- `RollbackRestore/Restore_yyyyMMdd_HHmmss/*.evtx`

## Usage examples

Dry run with defaults:

```powershell
.\day3\EventLogArchiveCleanup.ps1 -DryRun
```

Archive and clean logs older than 7 days:

```powershell
.\day3\EventLogArchiveCleanup.ps1 -OlderThanDays 7
```

Dry run with custom logs:

```powershell
.\day3\EventLogArchiveCleanup.ps1 -DryRun -OlderThanDays 5 -LogNames Application,System
```

Rollback using latest manifest (dry run):

```powershell
.\day3\EventLogArchiveCleanup.ps1 -Rollback -DryRun
```

Rollback using a specific manifest:

```powershell
.\day3\EventLogArchiveCleanup.ps1 -Rollback -RollbackManifest "C:\ProgramData\DWPEventLogMaintenance\Manifests\Manifest_run_20260805_103000.json"
```

## Safety notes

- Run elevated where required (especially for `Security` log operations).
- Start with `-DryRun` in pilot first.
- Review the timestamped log output after every run.
- Keep archive retention policy aligned with endpoint governance.
