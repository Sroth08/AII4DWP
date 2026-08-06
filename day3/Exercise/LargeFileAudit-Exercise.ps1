#requires -Version 5.1
<#!
.SYNOPSIS
Identifies large files on Windows endpoints using read-only operations.

.DESCRIPTION
- Scans one or more paths for files larger than a threshold.
- Defaults to local fixed drives when no search path is provided.
- Handles inaccessible folders gracefully and logs errors.
- Produces sorted output and a run summary.

.NOTES
PowerShell 5.1 compatible.
This script is designed to be read-only against scanned locations.
#>

[CmdletBinding()]
param(
    # Section: Threshold parameter.
    # Defines the minimum file size in MB required for a file to match.
    [ValidateRange(1, 1048576)]
    [int]$ThresholdMB = 100,

    # Section: Search path parameter.
    # Accepts one or more root paths to scan. If omitted, local fixed drives are used.
    [string[]]$SearchPath,

    # Section: Result limit parameter.
    # Optionally limits number of returned rows after sorting largest to smallest.
    [ValidateRange(1, 1000000)]
    [int]$MaxResults,

    # Section: Working root parameter.
    # Stores timestamped run logs. This is the only write location used by the script.
    [string]$WorkingRoot = "$env:ProgramData\DWPLargeFileAudit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Section: Initialize run metadata and log folder.
# Creates a timestamped log file so every action and error is traceable.
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logRoot = Join-Path -Path $WorkingRoot -ChildPath 'Logs'

try {
    New-Item -Path $logRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
}
catch {
    throw "Failed to create log folder '$logRoot'. Error: $($_.Exception.Message)"
}

$script:LogFile = Join-Path -Path $logRoot -ChildPath ("LargeFileAudit_{0}.log" -f $runStamp)

# Section: Logging helper.
# Writes timestamped entries to both console and log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    try {
        Add-Content -LiteralPath $script:LogFile -Value $line -ErrorAction Stop
    }
    catch {
        Write-Host "[LOG-FAIL] $line"
    }

    Write-Host $line
}

# Section: Verification warnings.
# Explicitly flags commands and assumptions to review before running in production.
function Show-VerificationChecklist {
    Write-Log -Level 'WARN' -Message 'VERIFY BEFORE EXECUTION: Script is read-only for scanned locations; it only writes to its own log folder.'
    Write-Log -Level 'WARN' -Message 'VERIFY COMMANDS: Get-CimInstance, Get-ChildItem, Join-Path, Add-Content, New-Item.'
    Write-Log -Level 'WARN' -Message 'VERIFY ASSUMPTIONS: Access permissions and endpoint load may affect scan duration and visibility of protected folders.'
    Write-Log -Level 'WARN' -Message 'VERIFY OUTPUT SCOPE: Default scan targets local fixed drives only.'
}

# Section: Default path resolver.
# Resolves local fixed drive roots when SearchPath is not supplied.
function Get-DefaultFixedDrivePaths {
    $paths = New-Object System.Collections.Generic.List[string]

    try {
        $drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop
        foreach ($drive in $drives) {
            if (-not [string]::IsNullOrWhiteSpace($drive.DeviceID)) {
                $paths.Add("$($drive.DeviceID)\") | Out-Null
            }
        }
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed to enumerate fixed drives: $($_.Exception.Message)"
    }

    return ,$paths
}

# Section: Path normalization helper.
# Expands user-provided paths and removes duplicate roots.
function Resolve-ScanPaths {
    param([string[]]$InputPaths)

    $resolved = New-Object System.Collections.Generic.List[string]

    foreach ($path in $InputPaths) {
        try {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }

            $full = [System.IO.Path]::GetFullPath($path)
            if (-not (Test-Path -LiteralPath $full)) {
                Write-Log -Level 'WARN' -Message "Skipping non-existent path: $full"
                continue
            }

            if (-not $resolved.Contains($full)) {
                $resolved.Add($full) | Out-Null
            }
        }
        catch {
            Write-Log -Level 'WARN' -Message "Skipping invalid path '$path': $($_.Exception.Message)"
        }
    }

    return ,$resolved
}

# Section: Large file scanner.
# Recursively scans folders with explicit try/catch per folder to handle access issues gracefully.
function Find-LargeFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RootPaths,

        [Parameter(Mandatory = $true)]
        [int64]$ThresholdBytes
    )

    $results = New-Object System.Collections.Generic.List[object]

    $stats = [ordered]@{
        FilesScanned = 0
        FilesMatched = 0
        MatchingBytes = [int64]0
        FoldersSkipped = 0
        Errors = 0
    }

    foreach ($root in $RootPaths) {
        Write-Log -Message "Scanning root path: $root"

        $stack = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($root)

        while ($stack.Count -gt 0) {
            $currentFolder = $stack.Pop()

            try {
                $items = Get-ChildItem -LiteralPath $currentFolder -Force -ErrorAction Stop

                foreach ($item in $items) {
                    if ($item.PSIsContainer) {
                        $stack.Push($item.FullName)
                        continue
                    }

                    $stats.FilesScanned++

                    try {
                        $length = [int64]$item.Length
                        if ($length -lt $ThresholdBytes) {
                            continue
                        }

                        $sizeMB = [math]::Round(($length / 1MB), 2)
                        $sizeGB = [math]::Round(($length / 1GB), 3)

                        $results.Add([pscustomobject]@{
                            FileName = $item.Name
                            FullPath = $item.FullName
                            FileSizeMB = $sizeMB
                            FileSizeGB = $sizeGB
                            CreationDate = $item.CreationTime
                            LastModifiedDate = $item.LastWriteTime
                            SizeBytes = $length
                        }) | Out-Null

                        $stats.FilesMatched++
                        $stats.MatchingBytes += $length
                    }
                    catch {
                        $stats.Errors++
                        Write-Log -Level 'WARN' -Message "File metadata read failed: $($item.FullName) :: $($_.Exception.Message)"
                    }
                }
            }
            catch {
                $stats.FoldersSkipped++
                $stats.Errors++
                Write-Log -Level 'WARN' -Message "Folder skipped: $currentFolder :: $($_.Exception.Message)"
            }
        }
    }

    return [pscustomobject]@{
        Results = $results
        Stats = $stats
    }
}

# Section: Script entry point.
# Resolves scope, runs scan, sorts output, applies optional limit, and writes summary.
Write-Log -Message '=================================================='
Write-Log -Message ("Script start. ThresholdMB={0}; MaxResults={1}; WorkingRoot={2}" -f $ThresholdMB, $MaxResults, $WorkingRoot)
Show-VerificationChecklist

$pathsToScan = @()
if ($null -ne $SearchPath -and $SearchPath.Count -gt 0) {
    $pathsToScan = @(Resolve-ScanPaths -InputPaths $SearchPath)
}
else {
    $pathsToScan = @(Get-DefaultFixedDrivePaths)
}

if ($pathsToScan.Count -eq 0) {
    Write-Log -Level 'ERROR' -Message 'No valid scan paths were resolved. Exiting.'
    Write-Log -Message '=================================================='
    return
}

Write-Log -Message ("Resolved scan paths: {0}" -f ($pathsToScan -join '; '))

$thresholdBytes = [int64]$ThresholdMB * 1MB
$scan = Find-LargeFiles -RootPaths $pathsToScan -ThresholdBytes $thresholdBytes

$sorted = @($scan.Results | Sort-Object -Property SizeBytes -Descending)
if ($PSBoundParameters.ContainsKey('MaxResults')) {
    $sorted = @($sorted | Select-Object -First $MaxResults)
}

if ($sorted.Count -gt 0) {
    $display = $sorted | Select-Object FileName, FullPath, FileSizeMB, FileSizeGB, CreationDate, LastModifiedDate
    $display | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log -Message $_ }
}
else {
    Write-Log -Message 'No files matched the configured threshold.'
}

$totalMB = [math]::Round(($scan.Stats.MatchingBytes / 1MB), 2)
$totalGB = [math]::Round(($scan.Stats.MatchingBytes / 1GB), 3)

Write-Log -Message 'Summary:'
Write-Log -Message ("  Number of files scanned: {0}" -f $scan.Stats.FilesScanned)
Write-Log -Message ("  Number of files matching threshold: {0}" -f $scan.Stats.FilesMatched)
Write-Log -Message ("  Total size of matching files: {0} MB ({1} GB)" -f $totalMB, $totalGB)
Write-Log -Message ("  Number of folders skipped: {0}" -f $scan.Stats.FoldersSkipped)
Write-Log -Message ("  Number of errors encountered: {0}" -f $scan.Stats.Errors)
Write-Log -Message ("Log file: {0}" -f $script:LogFile)
Write-Log -Message 'Script end.'
Write-Log -Message '=================================================='

# Section: Pipeline output.
# Emits final sorted objects for optional downstream reporting/export.
$sorted | Select-Object FileName, FullPath, FileSizeMB, FileSizeGB, CreationDate, LastModifiedDate
+