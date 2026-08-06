# Large File Audit Script (Exercise)

## Script

- day3/Exercise/LargeFileAudit-Exercise.ps1

## Purpose

This script identifies large files on Windows endpoints using read-only scan operations.

- It does not delete, move, rename, or modify scanned files.
- It does not change file attributes or permissions.
- It writes only to its own log folder under WorkingRoot.

## Parameters

- ThresholdMB
  - Minimum file size in MB to include in results.
  - Default: 100

- SearchPath
  - One or more root paths to scan.
  - If omitted, the script scans local fixed drives.

- MaxResults
  - Optional cap on returned rows after sorting largest to smallest.

- WorkingRoot
  - Root folder for logs.
  - Default: $env:ProgramData\DWPLargeFileAudit

## Output fields

For each matching file, the script outputs:

- FileName
- FullPath
- FileSizeMB
- FileSizeGB
- CreationDate
- LastModifiedDate

## Sorting

- Results are sorted from largest to smallest.

## Logging

A timestamped run log is created at:

- WorkingRoot\Logs\LargeFileAudit_yyyyMMdd_HHmmss.log

Log content includes:

- Start/end markers
- Resolved scan paths
- Access-denied and other folder/file exceptions
- Summary statistics

## Summary report

At the end of each run, the script reports:

- Number of files scanned
- Number of files matching threshold
- Total size of matching files
- Number of folders skipped
- Number of errors encountered

## Examples

Default scan (local fixed drives, threshold 100 MB):

```powershell
.\day3\Exercise\LargeFileAudit-Exercise.ps1
```

Custom threshold (500 MB):

```powershell
.\day3\Exercise\LargeFileAudit-Exercise.ps1 -ThresholdMB 500
```

Scan specific path and return top 50 largest files:

```powershell
.\day3\Exercise\LargeFileAudit-Exercise.ps1 -SearchPath "C:\Users","D:\Data" -ThresholdMB 250 -MaxResults 50
```

Use custom working root for logs:

```powershell
.\day3\Exercise\LargeFileAudit-Exercise.ps1 -WorkingRoot "C:\ProgramData\DWPLargeFileAuditLab"
```

## Safety and verification checklist

Before production execution, verify:

- Commands used: Get-CimInstance, Get-ChildItem, Join-Path, Add-Content, New-Item
- Assumptions:
  - Read permissions vary by endpoint and may cause skipped folders
  - Larger path scopes can increase runtime
  - Default scope includes local fixed drives only

## Limitations

- Inaccessible folders are skipped and logged; they are not scanned.
- Reparse points and protected OS areas may generate access warnings.
- Output reflects what the executing account can read at runtime.

## Expected behavior

- Script remains read-only for scanned data locations.
- Script continues after access errors and completes with summary/log output.
