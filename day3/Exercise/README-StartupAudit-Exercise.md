# Startup Program Audit Script (Exercise)

This document explains how to use the startup audit script safely on Windows endpoints.

## Script file

- `day3/Exercise/EventLogArchiveCleanup-Exercise.ps1`

## Purpose

The script audits startup programs for:

- Current user
- All users

It can also disable exactly one specified startup entry when explicitly requested, and supports rollback from backup state.

By default, it runs in **audit mode** and does not modify anything.

## Startup locations collected

The script audits these locations:

- Startup folders
  - Current user startup folder
  - All users startup folder
- Registry startup keys
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce`
  - `HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`
  - `HKLM:\Software\Microsoft\Windows\CurrentVersion\Run`
  - `HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce`
  - `HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run`
  - `HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`
  - `HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce`
- Startup approval state references
  - `...\Explorer\StartupApproved\Run`
  - `...\Explorer\StartupApproved\StartupFolder`

## Output fields

For each startup entry, the script reports:

- Program Name
- Startup Location
- Command Path
- Enabled/Disabled Status
- User Scope (Current User or All Users)

## Parameters

- `-Disable`
  - Enables disable mode.
  - The script will only disable an entry when this switch is present.

- `-Rollback`
  - Restores previously disabled entries from backup state.

- `-ProgramName <string>`
  - Startup program name used with `-Disable` or optional with `-Rollback`.
  - Required when `-Disable` is used.

- `-StartupLocation <string>`
  - Optional disambiguation filter if multiple entries share the same program name.

- `-WorkingRoot <string>`
  - Root path for logs, backups, disabled-item storage, and backup state.
  - Default: `$env:ProgramData\DWPStartupAudit`

## Safe-by-default behavior

- Default mode is audit only (no modifications).
- Nothing is disabled unless `-Disable` is explicitly provided.
- Before any disable operation, the script:
  - Validates the target exists.
  - Creates backup metadata/artifacts.
  - Logs every step.

## Idempotency behavior

- Already-disabled entries are skipped.
- Existing backups are reused and not duplicated.
- Re-running disable/rollback does not create inconsistent state.

## Backup and rollback model

Disable mode:

- Registry entries:
  - Backup metadata is written under `Backups`.
  - Startup value is moved to a script-managed subkey: `DWPDisabledValues`.
- Startup folder files:
  - File backup copy is created under `Backups\StartupFiles\...`.
  - Original file is moved to `DisabledStartupItems\...`.

Rollback mode:

- Reads `StartupBackupState.json`.
- Restores entries marked as disabled.
- Can restore all disabled entries or only entries matching `-ProgramName`.

## Logging

- Every action is logged to a timestamped log file:
  - `Logs/StartupAudit_yyyyMMdd_HHmmss.log`

## End-of-run summary

The script reports:

- Total startup entries found
- Total disabled
- Total skipped
- Total errors

## Examples

Audit only (default):

```powershell
.\day3\Exercise\EventLogArchiveCleanup-Exercise.ps1
```

Disable one startup entry by name:

```powershell
.\day3\Exercise\EventLogArchiveCleanup-Exercise.ps1 -Disable -ProgramName "Teams"
```

Disable one startup entry by name and location filter (when duplicates exist):

```powershell
.\day3\Exercise\EventLogArchiveCleanup-Exercise.ps1 -Disable -ProgramName "OneDrive" -StartupLocation "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
```

Rollback all previously disabled entries:

```powershell
.\day3\Exercise\EventLogArchiveCleanup-Exercise.ps1 -Rollback
```

Rollback only one program:

```powershell
.\day3\Exercise\EventLogArchiveCleanup-Exercise.ps1 -Rollback -ProgramName "Teams"
```

Use a custom working root:

```powershell
.\day3\Exercise\EventLogArchiveCleanup-Exercise.ps1 -WorkingRoot "C:\ProgramData\DWPStartupAuditLab"
```

## Safety considerations

- Review the script output warning checklist before running with `-Disable` or `-Rollback`.
- Verify sensitive registry paths and commands before execution.
- Run in endpoint pilot groups before broad use.
- Use elevation for HKLM/common startup changes where required.
- Keep backups and logs according to your retention policy.
