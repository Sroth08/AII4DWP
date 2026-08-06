#requires -Version 5.1
<#
.SYNOPSIS
Safely cleans temporary files on Windows endpoints with dry-run, logging, and rollback support.

.DESCRIPTION
- Targets files in temp locations that are older than a configurable number of days.
- Uses a quarantine move (not hard delete) so files can be restored later.
- Supports dry run for previewing actions.
- Handles errors per file and skips locked files.
- Writes a timestamped log and outputs a summary.

.NOTES
Designed for PowerShell 5.1 and endpoint-safe operations.
#>

[CmdletBinding()]
param(
    # When set, the script only reports what it would move/delete and does not change files.
    [switch]$DryRun,

    # Minimum file age in days. Default 0 means any file older than current time.
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 0,

    # Temp paths to process. Can be overridden by the caller.
    [string[]]$TargetPaths = @(
        $env:TEMP,
        "$env:WINDIR\Temp"
    ),

    # Working root for logs, manifests, and quarantined files.
    [string]$WorkingRoot = "$env:ProgramData\DWPTempCleanup",

    # Switch to restore files from a previous cleanup manifest.
    [switch]$Rollback,

    # Optional path to a specific manifest JSON file for rollback.
    [string]$RollbackManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Section: Initialize run metadata and working folders.
# This section creates predictable locations for logs, manifests, and quarantine data.
$runTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runId = "run_$runTimestamp"
$logRoot = Join-Path -Path $WorkingRoot -ChildPath 'Logs'
$manifestRoot = Join-Path -Path $WorkingRoot -ChildPath 'Manifests'
$quarantineRoot = Join-Path -Path $WorkingRoot -ChildPath 'Quarantine'

New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
New-Item -Path $manifestRoot -ItemType Directory -Force | Out-Null
New-Item -Path $quarantineRoot -ItemType Directory -Force | Out-Null

$script:LogFilePath = Join-Path -Path $logRoot -ChildPath ("TempCleanup_{0}.log" -f $runTimestamp)

# Section: Logging helper.
# This function writes timestamped log entries and mirrors them to the console.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $stamp, $Level, $Message
    Add-Content -Path $script:LogFilePath -Value $line
    Write-Host $line
}

# Section: Locked-file detection helper.
# Attempts a non-shared read/write open to identify in-use files.
function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $stream.Close()
        return $false
    }
    catch [System.IO.IOException] {
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        # Treat access denied as non-deletable in this run for endpoint safety.
        return $true
    }
}

# Section: Build quarantine destination path.
# Converts original file path to a safe folder structure under this run's quarantine root.
function Get-QuarantinePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OriginalPath,

        [Parameter(Mandatory = $true)]
        [string]$RunQuarantineRoot
    )

    $item = Get-Item -LiteralPath $OriginalPath -ErrorAction Stop
    $driveName = $item.PSDrive.Name

    if ($OriginalPath.Length -lt 4) {
        throw "Unexpected file path format: $OriginalPath"
    }

    $relativeNoDrive = $OriginalPath.Substring(3)
    $combinedRelative = Join-Path -Path $driveName -ChildPath $relativeNoDrive
    return Join-Path -Path $RunQuarantineRoot -ChildPath $combinedRelative
}

# Section: Rollback mode.
# Restores files from manifest entries back to their original locations.
function Invoke-Rollback {
    param(
        [string]$ManifestPath,
        [switch]$IsDryRun
    )

    if (-not $ManifestPath) {
        $latestManifest = Get-ChildItem -Path $manifestRoot -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -eq $latestManifest) {
            Write-Log -Level 'WARN' -Message 'Rollback requested but no manifest files were found.'
            return
        }

        $ManifestPath = $latestManifest.FullName
    }

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        Write-Log -Level 'ERROR' -Message "Manifest not found: $ManifestPath"
        return
    }

    Write-Log -Message "Rollback manifest selected: $ManifestPath"

    $entries = @(Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json)
    if ($null -eq $entries) {
        Write-Log -Level 'WARN' -Message 'Manifest exists but contains no entries.'
        return
    }

    $rollbackMode = if ($IsDryRun) { 'Rollback-DryRun' } else { 'Rollback' }
    $summary = [ordered]@{
        Mode                 = $rollbackMode
        Manifest             = $ManifestPath
        EntriesEvaluated     = 0
        WouldRestore         = 0
        Restored             = 0
        SkippedAlreadyExists = 0
        SkippedMissingBackup = 0
        Errors               = 0
    }

    foreach ($entry in $entries) {
        $summary.EntriesEvaluated++

        try {
            $originalPath = [string]$entry.OriginalPath
            $quarantinePath = [string]$entry.QuarantinePath

            if (-not (Test-Path -LiteralPath $quarantinePath)) {
                $summary.SkippedMissingBackup++
                Write-Log -Level 'WARN' -Message "Skipping restore; backup missing: $quarantinePath"
                continue
            }

            if (Test-Path -LiteralPath $originalPath) {
                $summary.SkippedAlreadyExists++
                Write-Log -Level 'WARN' -Message "Skipping restore; file already exists: $originalPath"
                continue
            }

            if ($IsDryRun) {
                $summary.WouldRestore++
                Write-Log -Message "DRY RUN: Would restore '$originalPath' from '$quarantinePath'"
                continue
            }

            $parentDir = Split-Path -Path $originalPath -Parent
            if (-not (Test-Path -LiteralPath $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }

            Move-Item -LiteralPath $quarantinePath -Destination $originalPath -Force -ErrorAction Stop
            $summary.Restored++
            Write-Log -Message "Restored: $originalPath"
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Rollback error for '$($entry.OriginalPath)': $($_.Exception.Message)"
        }
    }

    Write-Log -Message 'Rollback summary:'
    foreach ($kv in $summary.GetEnumerator()) {
        Write-Log -Message ("  {0}: {1}" -f $kv.Key, $kv.Value)
    }
}

# Section: Cleanup mode.
# Finds old files in target temp paths and moves eligible files to quarantine.
function Invoke-Cleanup {
    param(
        [switch]$IsDryRun
    )

    $cutoffDate = (Get-Date).AddDays(-1 * $OlderThanDays)
    $runQuarantineRoot = Join-Path -Path $quarantineRoot -ChildPath $runId

    if (-not $IsDryRun) {
        New-Item -Path $runQuarantineRoot -ItemType Directory -Force | Out-Null
    }

    $cleanupMode = if ($IsDryRun) { 'Cleanup-DryRun' } else { 'Cleanup' }
    $summary = [ordered]@{
        Mode             = $cleanupMode
        OlderThanDays    = $OlderThanDays
        CutoffDate       = $cutoffDate
        TargetPathCount  = $TargetPaths.Count
        FilesScanned     = 0
        Candidates       = 0
        WouldMove        = 0
        MovedToQuarantine = 0
        SkippedLocked    = 0
        SkippedNotFound  = 0
        Errors           = 0
    }

    $manifestEntries = New-Object System.Collections.Generic.List[object]

    foreach ($targetPath in $TargetPaths) {
        try {
            if ([string]::IsNullOrWhiteSpace($targetPath)) {
                Write-Log -Level 'WARN' -Message 'Skipping empty target path entry.'
                continue
            }

            if (-not (Test-Path -LiteralPath $targetPath)) {
                Write-Log -Level 'WARN' -Message "Target path not found: $targetPath"
                continue
            }

            Write-Log -Message "Scanning path: $targetPath"

            $files = Get-ChildItem -LiteralPath $targetPath -File -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $summary.FilesScanned++

                if ($file.LastWriteTime -ge $cutoffDate) {
                    continue
                }

                $summary.Candidates++

                try {
                    if (-not (Test-Path -LiteralPath $file.FullName)) {
                        $summary.SkippedNotFound++
                        Write-Log -Level 'WARN' -Message "Skipping; file no longer exists: $($file.FullName)"
                        continue
                    }

                    if (Test-FileLocked -Path $file.FullName) {
                        $summary.SkippedLocked++
                        Write-Log -Level 'WARN' -Message "Skipping locked file: $($file.FullName)"
                        continue
                    }

                    $quarantinePath = Get-QuarantinePath -OriginalPath $file.FullName -RunQuarantineRoot $runQuarantineRoot

                    if ($IsDryRun) {
                        $summary.WouldMove++
                        Write-Log -Message "DRY RUN: Would move '$($file.FullName)' to '$quarantinePath'"
                        continue
                    }

                    $destinationDir = Split-Path -Path $quarantinePath -Parent
                    if (-not (Test-Path -LiteralPath $destinationDir)) {
                        New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
                    }

                    Move-Item -LiteralPath $file.FullName -Destination $quarantinePath -Force -ErrorAction Stop
                    $summary.MovedToQuarantine++
                    Write-Log -Message "Moved to quarantine: $($file.FullName)"

                    $manifestEntries.Add([pscustomobject]@{
                        OriginalPath   = $file.FullName
                        QuarantinePath = $quarantinePath
                        LastWriteTime  = $file.LastWriteTime
                        LengthBytes    = $file.Length
                        RunId          = $runId
                        MovedAt        = (Get-Date)
                    }) | Out-Null
                }
                catch {
                    $summary.Errors++
                    Write-Log -Level 'ERROR' -Message "Error handling file '$($file.FullName)': $($_.Exception.Message)"
                }
            }
        }
        catch {
            $summary.Errors++
            Write-Log -Level 'ERROR' -Message "Error scanning '$targetPath': $($_.Exception.Message)"
        }
    }

    if (-not $IsDryRun -and $manifestEntries.Count -gt 0) {
        $manifestPath = Join-Path -Path $manifestRoot -ChildPath ("Manifest_{0}.json" -f $runId)
        $manifestEntries | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        Write-Log -Message "Manifest written: $manifestPath"
        $summary.Manifest = $manifestPath
    }

    Write-Log -Message 'Cleanup summary:'
    foreach ($kv in $summary.GetEnumerator()) {
        Write-Log -Message ("  {0}: {1}" -f $kv.Key, $kv.Value)
    }
}

# Section: Entry point.
# Routes execution to cleanup or rollback mode and records script-level boundaries in the log.
Write-Log -Message '=================================================='
$startMode = if ($Rollback) { 'Rollback' } else { 'Cleanup' }
Write-Log -Message ("Script start. Mode: {0}" -f $startMode)
Write-Log -Message ("DryRun={0}; OlderThanDays={1}; WorkingRoot={2}" -f $DryRun.IsPresent, $OlderThanDays, $WorkingRoot)

if ($Rollback) {
    Invoke-Rollback -ManifestPath $RollbackManifest -IsDryRun:$DryRun
}
else {
    Invoke-Cleanup -IsDryRun:$DryRun
}

Write-Log -Message 'Script end.'
Write-Log -Message '=================================================='
