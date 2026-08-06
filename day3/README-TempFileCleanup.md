# TempFileCleanup.ps1

This document explains how to use `TempFileCleanup.ps1` safely on Windows endpoints.

## What the script does

- Scans configured temp locations for files older than a given age.
- Supports dry run output so you can review before any change.
- Skips locked files and logs the skip reason.
- Handles errors per file so one failure does not stop the run.
- Logs all actions to a timestamped log file.
- Produces a summary at the end of each run.
- Implements rollback by moving files to quarantine first.

## Script location

- `day3/TempFileCleanup.ps1`

## Parameters

- `-DryRun`
  - Preview mode. Prints and logs the files that would be moved/restored.
  - No file changes are made.

- `-OlderThanDays <int>`
  - File age threshold in days.
  - Default: `0`.
  - Example: `-OlderThanDays 7` targets files older than 7 days.

- `-TargetPaths <string[]>`
  - One or more paths to scan.
  - Default values:
    - `$env:TEMP`
    - `$env:WINDIR\Temp`

- `-WorkingRoot <string>`
  - Root folder for logs, manifests, and quarantine data.
  - Default: `$env:ProgramData\DWPTempCleanup`

- `-Rollback`
  - Runs restore mode instead of cleanup mode.
  - Restores files from a manifest.

- `-RollbackManifest <string>`
  - Optional explicit manifest path for rollback.
  - If omitted with `-Rollback`, the newest manifest is selected automatically.

## How rollback works

- Cleanup mode moves files into a run-specific quarantine folder instead of deleting permanently.
- A manifest JSON file is written for each cleanup run.
- Rollback mode reads the manifest and restores files to original paths.
- Idempotent behavior:
  - If a backup file is missing, it is logged and skipped.
  - If the original file already exists, it is logged and skipped.

## Log and data paths

Under `WorkingRoot` (default `$env:ProgramData\DWPTempCleanup`):

- `Logs/TempCleanup_yyyyMMdd_HHmmss.log`
- `Manifests/Manifest_run_yyyyMMdd_HHmmss.json`
- `Quarantine/run_yyyyMMdd_HHmmss/...`

## Usage examples

Dry run with defaults:

```powershell
.\day3\TempFileCleanup.ps1 -DryRun
```

Clean files older than 7 days:

```powershell
.\day3\TempFileCleanup.ps1 -OlderThanDays 7
```

Dry run for custom paths:

```powershell
.\day3\TempFileCleanup.ps1 -DryRun -OlderThanDays 3 -TargetPaths "C:\Temp", "$env:TEMP"
```

Rollback from latest manifest:

```powershell
.\day3\TempFileCleanup.ps1 -Rollback
```

Dry run rollback using a specific manifest:

```powershell
.\day3\TempFileCleanup.ps1 -Rollback -DryRun -RollbackManifest "C:\ProgramData\DWPTempCleanup\Manifests\Manifest_run_20260805_103000.json"
```

## Safety notes

- Start with `-DryRun` to verify scope and candidate files.
- Review log output after each run.
- Pilot on a limited endpoint group before broad rollout.
- Do not include protected or business-critical data paths in `-TargetPaths`.
