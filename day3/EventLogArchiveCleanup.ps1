#requires -Version 5.1
<#!
.SYNOPSIS
Safely archives and cleans eligible Windows Event Logs.

.DESCRIPTION
- Only targets logs whose newest event is older than the cutoff date.
- Supports dry run to show how many records would be deleted.
- Archives logs before cleanup and writes a run manifest.
- Supports rollback mode that restores archived files into a restore folder for review.
- Logs all actions and prints a summary.

.NOTES
PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
    # Runs in preview mode and makes no changes.
    [switch]$DryRun,

    # Targets logs where LastWriteTime is older than this many days.
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 3,

    # Logs to process. Defaults to common administrative channels.
    [string[]]$LogNames = @('Application', 'System', 'Security'),

    # Root folder for logs, archives, manifests, and rollback output.
    [string]$WorkingRoot = "$env:ProgramData\DWPEventLogMaintenance",

    # Runs rollback mode instead of archive/cleanup mode.
    [switch]$Rollback,

    # Optional explicit manifest JSON path for rollback mode.
    [string]$RollbackManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Section: Initialize paths and run metadata.
# Creates deterministic folders and a timestamped log file for traceability.
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runDate = Get-Date -Format 'yyyyMMdd'
$runId = "run_$runStamp"

$logRoot = Join-Path -Path $WorkingRoot -ChildPath 'Logs'
$archiveRoot = Join-Path -Path $WorkingRoot -ChildPath 'Archives'
$manifestRoot = Join-Path -Path $WorkingRoot -ChildPath 'Manifests'
$restoreRoot = Join-Path -Path $WorkingRoot -ChildPath 'RollbackRestore'

try { New-Item -Path $logRoot -ItemType Directory -Force | Out-Null } catch { throw }
try { New-Item -Path $archiveRoot -ItemType Directory -Force | Out-Null } catch { throw }
try { New-Item -Path $manifestRoot -ItemType Directory -Force | Out-Null } catch { throw }
try { New-Item -Path $restoreRoot -ItemType Directory -Force | Out-Null } catch { throw }

$script:LogFile = Join-Path -Path $logRoot -ChildPath ("EventLogArchiveCleanup_{0}.log" -f $runStamp)

# Section: Logging helper.
# Writes timestamped messages to log file and console.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message

    try {
        Add-Content -LiteralPath $script:LogFile -Value $line
    }
    catch {
        Write-Host "[LOG-FAIL] $line"
    }

    Write-Host $line
}

# Section: Sanitizes log names for file names.
# Replaces characters not valid for Windows file paths.
function ConvertTo-SafeFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $safe = $Name
    foreach ($c in $invalid) {
        $safe = $safe.Replace([string]$c, '_')
    }

    $safe = $safe.Replace('/', '_')
    $safe = $safe.Replace('\\', '_')
    return $safe
}

# Section: Rollback mode implementation.
# Copies archived EVTX files from a selected manifest to a restore folder.
# Note: Windows does not support writing archived events back into live channels safely.
function Invoke-Rollback {
    param(
        [string]$ManifestPath,
        [switch]$IsDryRun
    )

    # Determine which manifest to use.
    if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
        try {
            $latest = Get-ChildItem -LiteralPath $manifestRoot -Filter '*.json' -File -ErrorAction Stop |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 1
        }
        catch {
            Write-Log -Level 'ERROR' -Message "Failed to search manifest files: $($_.Exception.Message)"
            return
        }

        if ($null -eq $latest) {
            Write-Log -Level 'WARN' -Message 'Rollback requested but no manifest files were found.'
            return
        }

        $ManifestPath = $latest.FullName
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        Write-Log -Level 'ERROR' -Message "Rollback manifest not found: $ManifestPath"
        return
    }

    Write-Log -Message "Rollback manifest selected: $ManifestPath"

    try {
        $entries = @(Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json)
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed to parse rollback manifest: $($_.Exception.Message)"
        return
    }

    if ($entries.Count -eq 0) {
        Write-Log -Level 'WARN' -Message 'Rollback manifest contains no entries.'
        return
    }

    $modeLabel = if ($IsDryRun) { 'Rollback-DryRun' } else { 'Rollback' }
    $summary = [ordered]@{
        Mode                 = $modeLabel
        Manifest             = $ManifestPath
        EntriesEvaluated     = 0
        WouldRestoreFiles    = 0
        RestoredFiles        = 0
        SkippedMissingSource = 0
        SkippedAlreadyExists = 0
        Errors               = 0
    }

    $restoreRunRoot = Join-Path -Path $restoreRoot -ChildPath ("Restore_{0}" -f $runStamp)

    if (-not $IsDryRun) {
        try {
            New-Item -Path $restoreRunRoot -ItemType Directory -Force | Out-Null
        }
        catch {
            Write-Log -Level 'ERROR' -Message "Failed creating rollback restore folder: $($_.Exception.Message)"
            return
        }
    }

    foreach ($entry in $entries) {
        $summary.EntriesEvaluated++

        try {
            $sourceArchive = [string]$entry.ArchivePath
            $logName = [string]$entry.LogName
            $safeLog = ConvertTo-SafeFileName -Name $logName
            $destination = Join-Path -Path $restoreRunRoot -ChildPath ("{0}_{1}.evtx" -f $safeLog, $runStamp)

            if (-not (Test-Path -LiteralPath $sourceArchive)) {
                $summary.SkippedMissingSource++
                Write-Log -Level 'WARN' -Message "Rollback skip; archive missing: $sourceArchive"
                continue
            }

            if (-not $IsDryRun -and (Test-Path -LiteralPath $destination)) {
                $summary.SkippedAlreadyExists++
                Write-Log -Level 'WARN' -Message "Rollback skip; restore file already exists: $destination"
                continue
            }

            if ($IsDryRun) {
                $summary.WouldRestoreFiles++
                Write-Log -Message "DRY RUN: Would restore archive '$sourceArchive' to '$destination'"
                continue
            }

            Copy-Item -LiteralPath $sourceArchive -Destination $destination -Force -ErrorAction Stop
            $summary.RestoredFiles++
            Write-Log -Message "Rollback restored archive copy: $destination"
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Rollback error: $($_.Exception.Message)"
        }
    }

    Write-Log -Message 'Rollback summary:'
    foreach ($kv in $summary.GetEnumerator()) {
        Write-Log -Message ("  {0}: {1}" -f $kv.Key, $kv.Value)
    }
}

# Section: Archive and cleanup mode implementation.
# Archives eligible logs first, then clears them only if archive succeeded.
function Invoke-ArchiveCleanup {
    param(
        [switch]$IsDryRun
    )

    $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
    $summaryMode = if ($IsDryRun) { 'ArchiveCleanup-DryRun' } else { 'ArchiveCleanup' }

    $summary = [ordered]@{
        Mode                   = $summaryMode
        OlderThanDays          = $OlderThanDays
        CutoffDate             = $cutoff
        LogsRequested          = $LogNames.Count
        LogsEnumerated         = 0
        LogsEligible           = 0
        LogsSkippedNotOld      = 0
        LogsSkippedEmpty       = 0
        LogsSkippedAlreadyToday = 0
        RecordsWouldDelete     = 0
        RecordsDeleted         = 0
        LogsArchived           = 0
        LogsCleared            = 0
        Errors                 = 0
    }

    $manifestEntries = New-Object System.Collections.Generic.List[object]

    foreach ($logName in $LogNames) {
        try {
            $summary.LogsEnumerated++

            Write-Log -Message "Inspecting log: $logName"

            # Read channel metadata once to avoid heavy per-record enumeration.
            $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop

            $recordCount = 0
            if ($null -ne $logInfo.RecordCount) {
                $recordCount = [int64]$logInfo.RecordCount
            }

            if ($recordCount -le 0) {
                $summary.LogsSkippedEmpty++
                Write-Log -Message "Skipping '$logName'; no records present."
                continue
            }

            if ($null -eq $logInfo.LastWriteTime) {
                $summary.LogsSkippedNotOld++
                Write-Log -Message "Skipping '$logName'; LastWriteTime unavailable."
                continue
            }

            # Safety rule: only clear logs when their newest event is older than cutoff.
            if ($logInfo.LastWriteTime -ge $cutoff) {
                $summary.LogsSkippedNotOld++
                Write-Log -Message "Skipping '$logName'; newest event is newer than cutoff."
                continue
            }

            $summary.LogsEligible++
            $summary.RecordsWouldDelete += $recordCount

            $safeLogName = ConvertTo-SafeFileName -Name $logName
            $archiveName = "{0}_{1}.evtx" -f $safeLogName, $runDate
            $archivePath = Join-Path -Path $archiveRoot -ChildPath $archiveName

            # Idempotency rule: if today's archive exists for this log, skip this log.
            if (Test-Path -LiteralPath $archivePath) {
                $summary.LogsSkippedAlreadyToday++
                Write-Log -Message "Skipping '$logName'; archive already exists for today: $archivePath"
                continue
            }

            if ($IsDryRun) {
                Write-Log -Message "DRY RUN: '$logName' would archive to '$archivePath' and delete $recordCount records."
                continue
            }

            # Archive operation using wevtutil epl.
            try {
                & wevtutil epl $logName $archivePath
                if ($LASTEXITCODE -ne 0) {
                    throw "wevtutil epl failed with exit code $LASTEXITCODE"
                }
                $summary.LogsArchived++
                Write-Log -Message "Archived '$logName' to '$archivePath'"
            }
            catch {
                $summary.Errors++
                Write-Log -Level 'ERROR' -Message "Archive failed for '$logName': $($_.Exception.Message)"
                continue
            }

            # Cleanup operation using wevtutil cl only after successful archive.
            try {
                & wevtutil cl $logName
                if ($LASTEXITCODE -ne 0) {
                    throw "wevtutil cl failed with exit code $LASTEXITCODE"
                }

                $summary.LogsCleared++
                $summary.RecordsDeleted += $recordCount
                Write-Log -Message "Cleared '$logName'; deleted $recordCount records."

                $manifestEntries.Add([pscustomobject]@{
                    LogName         = $logName
                    ArchivePath     = $archivePath
                    RecordCount     = $recordCount
                    LastWriteTime   = $logInfo.LastWriteTime
                    ArchiveDate     = (Get-Date)
                    RunId           = $runId
                    OlderThanDays   = $OlderThanDays
                    CutoffDate      = $cutoff
                }) | Out-Null
            }
            catch {
                $summary.Errors++
                Write-Log -Level 'ERROR' -Message "Cleanup failed for '$logName': $($_.Exception.Message)"
            }
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Inspection failed for '$logName': $($_.Exception.Message)"
        }
    }

    # Persist rollback manifest for successful archive+cleanup actions.
    if (-not $IsDryRun -and $manifestEntries.Count -gt 0) {
        try {
            $manifestPath = Join-Path -Path $manifestRoot -ChildPath ("Manifest_{0}.json" -f $runId)
            $manifestEntries | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
            Write-Log -Message "Manifest written: $manifestPath"
            $summary.Manifest = $manifestPath
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Failed writing manifest: $($_.Exception.Message)"
        }
    }

    Write-Log -Message 'Archive/Cleanup summary:'
    foreach ($kv in $summary.GetEnumerator()) {
        Write-Log -Message ("  {0}: {1}" -f $kv.Key, $kv.Value)
    }
}

# Section: Script entry point.
# Selects mode, writes run start/end markers, and invokes the selected operation.
Write-Log -Message '=================================================='
$mode = if ($Rollback) { 'Rollback' } else { 'ArchiveCleanup' }
Write-Log -Message ("Script start. Mode={0}; DryRun={1}; OlderThanDays={2}; WorkingRoot={3}" -f $mode, $DryRun.IsPresent, $OlderThanDays, $WorkingRoot)

if ($Rollback) {
    try {
        Invoke-Rollback -ManifestPath $RollbackManifest -IsDryRun:$DryRun
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Unhandled rollback error: $($_.Exception.Message)"
    }
}
else {
    try {
        Invoke-ArchiveCleanup -IsDryRun:$DryRun
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Unhandled archive/cleanup error: $($_.Exception.Message)"
    }
}

Write-Log -Message 'Script end.'
Write-Log -Message '=================================================='
