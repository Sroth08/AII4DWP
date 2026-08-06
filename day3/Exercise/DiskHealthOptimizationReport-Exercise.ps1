#requires -Version 5.1
<#!
Script Name: DiskHealthOptimizationReport-Exercise.ps1
Purpose: Read-only reporting of disk capacity, health indicators, SMART signals, and optimization metadata on Windows endpoints.
Author: <Author-Name-Here>
Date Generated: 2026-08-05
PowerShell Version Requirement: 5.1
Read-Only Safety Disclaimer: This script is diagnostics-only and must not perform remediation, repair, optimization, or configuration changes.
#>

[CmdletBinding()]
param(
    # Section: Working root parameter.
    # Defines where timestamped log files are written.
    [string]$WorkingRoot = "$env:ProgramData\DWPDiskHealthReport"
)

# Section: Strict mode and error behavior.
# Enables stricter script validation while allowing controlled try/catch handling.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Section: Runtime metadata and folder paths.
# Creates deterministic paths used only for log output.
$runTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDirectory = Join-Path -Path $WorkingRoot -ChildPath 'Logs'
$script:LogFile = Join-Path -Path $logDirectory -ChildPath ("DiskHealthOptimizationReport_{0}.log" -f $runTimestamp)

# Section: Logging helper.
# Writes each message to console and to the timestamped log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestampText = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[{0}] [{1}] {2}" -f $timestampText, $Level, $Message

    try {
        Add-Content -LiteralPath $script:LogFile -Value $line -ErrorAction Stop
    }
    catch {
        Write-Host "[LOG-FAIL] $line"
    }

    Write-Host $line
}

# Section: Verification checklist.
# Flags commands, classes, registry paths, and assumptions to validate before production deployment.
function Show-VerificationChecklist {
    Write-Log -Level 'WARN' -Message 'VERIFY BEFORE DEPLOYMENT: Script is strictly read-only and intended for diagnostics only.'
    Write-Log -Level 'WARN' -Message 'VERIFY COMMANDS: Get-Disk, Get-Partition, Get-Volume, Get-CimInstance, Get-WmiObject, Get-ItemProperty, Get-ChildItem, Add-Content, New-Item.'
    Write-Log -Level 'WARN' -Message 'VERIFY CIM/WMI CLASSES: Win32_LogicalDisk, Win32_DiskDrive, Win32_DiskPartition, root\wmi:MSStorageDriver_FailurePredictStatus.'
    Write-Log -Level 'WARN' -Message 'VERIFY REGISTRY PATHS: HKLM:\SOFTWARE\Microsoft\Dfrg\Statistics\Volume* (optimization metadata may vary by OS build).'
    Write-Log -Level 'WARN' -Message 'VERIFY ASSUMPTIONS: Storage module availability, permissions for health namespaces, and SMART provider behavior differ across hardware/driver stacks.'
}

# Section: Read-only safety banner.
# Displays a prominent banner confirming no endpoint changes will be made.
function Show-ReadOnlyBanner {
    $banner = @(
        '============================================================',
        'READ-ONLY DIAGNOSTIC SCRIPT',
        'No changes will be made to this endpoint.',
        'No remediation, repair, optimization, or configuration changes are performed.',
        'Diagnostics and reporting only.',
        '============================================================'
    )

    foreach ($line in $banner) {
        Write-Host $line
    }

    foreach ($line in $banner) {
        Write-Log -Message $line
    }
}

# Section: Utility helper.
# Normalizes identity text for loose matching between disk and SMART provider instance names.
function ConvertTo-NormalizedKey {
    param([string]$InputText)

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        return ''
    }

    return (($InputText -replace '[^A-Za-z0-9]', '').ToUpperInvariant())
}

# Section: Optimization metadata collector.
# Reads optimization hints from registry statistics keys when available.
function Get-OptimizationData {
    $optimizationMap = @{}
    $optimizationRegistryRoot = 'HKLM:\SOFTWARE\Microsoft\Dfrg\Statistics'

    try {
        if (-not (Test-Path -LiteralPath $optimizationRegistryRoot)) {
            Write-Log -Level 'WARN' -Message "Optimization registry root not found: $optimizationRegistryRoot"
            return $optimizationMap
        }

        $volumeKeys = Get-ChildItem -LiteralPath $optimizationRegistryRoot -ErrorAction Stop
        foreach ($volumeKey in $volumeKeys) {
            try {
                $properties = Get-ItemProperty -LiteralPath $volumeKey.PSPath -ErrorAction Stop
                $allProps = $properties.PSObject.Properties

                $driveLetterGuess = $null
                $nameSource = [string]$volumeKey.PSChildName
                if ($nameSource -match '([A-Z])') {
                    $driveLetterGuess = $Matches[1]
                }

                $lastOptimizationValue = $null
                $fragmentationValue = $null
                $statusValue = $null

                foreach ($prop in $allProps) {
                    $propName = [string]$prop.Name
                    if ($propName -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                        continue
                    }

                    if ($null -eq $lastOptimizationValue -and $propName -match 'Last.*(Run|Optimization|Optimize|Analyze|Defrag).*Time') {
                        $lastOptimizationValue = $prop.Value
                    }

                    if ($null -eq $fragmentationValue -and $propName -match '(Frag|Fragmentation|Percent)') {
                        $fragmentationValue = $prop.Value
                    }

                    if ($null -eq $statusValue -and $propName -match '(Status|Result|LastResult)') {
                        $statusValue = $prop.Value
                    }
                }

                if (-not [string]::IsNullOrWhiteSpace($driveLetterGuess)) {
                    $optimizationMap[$driveLetterGuess] = [pscustomobject]@{
                        LastOptimizationRaw = $lastOptimizationValue
                        OptimizationStatusRaw = $statusValue
                        FragmentationRaw = $fragmentationValue
                        RegistrySource = $volumeKey.PSPath
                    }
                }
            }
            catch {
                Write-Log -Level 'WARN' -Message "Failed reading optimization key '$($volumeKey.PSPath)': $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Log -Level 'WARN' -Message "Failed enumerating optimization metadata: $($_.Exception.Message)"
    }

    return $optimizationMap
}

# Section: SMART health collector.
# Queries SMART failure prediction status where the provider is available.
function Get-SmartStatusData {
    $smartData = @()

    try {
        $smartData = @(Get-WmiObject -Namespace 'root\wmi' -Class 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop)
        Write-Log -Message ("SMART provider returned {0} records." -f $smartData.Count)
    }
    catch {
        Write-Log -Level 'WARN' -Message "SMART provider query failed or unavailable: $($_.Exception.Message)"
    }

    return $smartData
}

# Section: Local disk capacity collector.
# Gathers all local fixed logical disks and their core capacity fields.
function Get-LogicalDiskData {
    $logicalDisks = @()

    try {
        $logicalDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -ErrorAction Stop)
        Write-Log -Message ("Logical fixed disks discovered: {0}" -f $logicalDisks.Count)
    }
    catch {
        Write-Log -Level 'ERROR' -Message "Failed collecting Win32_LogicalDisk data: $($_.Exception.Message)"
    }

    return $logicalDisks
}

# Section: Physical disk metadata collector.
# Retrieves storage health and operational state data from Get-Disk where available.
function Get-PhysicalDiskData {
    $diskByNumber = @{}

    try {
        if (-not (Get-Command -Name Get-Disk -ErrorAction SilentlyContinue)) {
            Write-Log -Level 'WARN' -Message 'Get-Disk command is unavailable on this endpoint.'
            return $diskByNumber
        }

        $disks = @(Get-Disk -ErrorAction Stop)
        foreach ($disk in $disks) {
            $diskByNumber[[int]$disk.Number] = $disk
        }

        Write-Log -Message ("Physical disks discovered via Get-Disk: {0}" -f $disks.Count)
    }
    catch {
        Write-Log -Level 'WARN' -Message "Failed collecting Get-Disk metadata: $($_.Exception.Message)"
    }

    return $diskByNumber
}

# Section: Win32 disk metadata collector.
# Retrieves Win32_DiskDrive data for additional model/serial/status context.
function Get-Win32DiskDriveData {
    $win32Disks = @()

    try {
        $win32Disks = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop)
        Write-Log -Message ("Win32_DiskDrive records discovered: {0}" -f $win32Disks.Count)
    }
    catch {
        Write-Log -Level 'WARN' -Message "Failed collecting Win32_DiskDrive metadata: $($_.Exception.Message)"
    }

    return $win32Disks
}

# Section: Disk-to-volume mapper.
# Maps drive letters to disk numbers through partitions.
function Get-DriveLetterToDiskNumberMap {
    $map = @{}

    try {
        if (-not (Get-Command -Name Get-Partition -ErrorAction SilentlyContinue)) {
            Write-Log -Level 'WARN' -Message 'Get-Partition command is unavailable; disk number mapping may be limited.'
            return $map
        }

        $partitions = @(Get-Partition -ErrorAction Stop)
        foreach ($partition in $partitions) {
            if ([string]::IsNullOrWhiteSpace($partition.DriveLetter)) {
                continue
            }

            $map[[string]$partition.DriveLetter] = [int]$partition.DiskNumber
        }
    }
    catch {
        Write-Log -Level 'WARN' -Message "Failed mapping partitions to disk numbers: $($_.Exception.Message)"
    }

    return $map
}

# Section: Health classification helper.
# Converts health signals into Healthy, Warning, Error, or Unavailable categories.
function Get-HealthCategory {
    param(
        [string]$OperationalStatus,
        [string]$HealthStatus,
        [nullable[bool]]$PredictFailure,
        [bool]$HasAnyHealthSignal
    )

    if (-not $HasAnyHealthSignal) {
        return 'Unavailable'
    }

    $operationalUpper = if ($null -eq $OperationalStatus) { '' } else { $OperationalStatus.ToUpperInvariant() }
    $healthUpper = if ($null -eq $HealthStatus) { '' } else { $HealthStatus.ToUpperInvariant() }

    if ($healthUpper -match 'UNHEALTHY|FAILED|ERROR') {
        return 'Error'
    }

    if ($operationalUpper -match 'FAILED|OFFLINE|ERROR|LOST|UNKNOWN') {
        return 'Error'
    }

    if ($PredictFailure -eq $true) {
        return 'Warning'
    }

    if ($healthUpper -match 'WARNING|DEGRADED|UNKNOWN') {
        return 'Warning'
    }

    if ($operationalUpper -match 'DEGRADED|WARNING') {
        return 'Warning'
    }

    if ($healthUpper -eq 'HEALTHY' -or $operationalUpper -match 'ONLINE|OK') {
        return 'Healthy'
    }

    return 'Warning'
}

# Section: Main execution wrapper.
# Orchestrates data collection, reporting, and summary generation with robust error handling.
try {
    try {
        New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Unable to create log directory '$logDirectory': $($_.Exception.Message)"
    }

    Show-ReadOnlyBanner
    Show-VerificationChecklist
    Write-Log -Message ("Script start. WorkingRoot={0}" -f $WorkingRoot)

    $logicalDisks = @(Get-LogicalDiskData)
    $physicalDisksByNumber = Get-PhysicalDiskData
    $win32Disks = @(Get-Win32DiskDriveData)
    $driveLetterToDiskMap = Get-DriveLetterToDiskNumberMap
    $smartStatusRows = @(Get-SmartStatusData)
    $optimizationByDriveLetter = Get-OptimizationData

    $win32DiskByIndex = @{}
    foreach ($win32Disk in $win32Disks) {
        try {
            $win32DiskByIndex[[int]$win32Disk.Index] = $win32Disk
        }
        catch {
            Write-Log -Level 'WARN' -Message "Skipping Win32_DiskDrive row with invalid index: $($_.Exception.Message)"
        }
    }

    $diskAssessmentMap = @{}
    $reportRows = New-Object System.Collections.Generic.List[object]

    foreach ($logicalDisk in $logicalDisks) {
        try {
            $driveLetter = [string]$logicalDisk.DeviceID
            $driveLetterTrimmed = $driveLetter.TrimEnd(':')

            $diskNumber = $null
            if ($driveLetterToDiskMap.ContainsKey($driveLetterTrimmed)) {
                $diskNumber = $driveLetterToDiskMap[$driveLetterTrimmed]
            }

            $physicalDisk = $null
            if ($null -ne $diskNumber -and $physicalDisksByNumber.ContainsKey([int]$diskNumber)) {
                $physicalDisk = $physicalDisksByNumber[[int]$diskNumber]
            }

            $win32Disk = $null
            if ($null -ne $diskNumber -and $win32DiskByIndex.ContainsKey([int]$diskNumber)) {
                $win32Disk = $win32DiskByIndex[[int]$diskNumber]
            }

            $diskOperationalStatus = $null
            $diskHealthStatus = $null
            $mediaType = $null

            if ($null -ne $physicalDisk) {
                try {
                    $diskOperationalStatus = (($physicalDisk.OperationalStatus | ForEach-Object { [string]$_ }) -join ', ')
                }
                catch {
                    $diskOperationalStatus = [string]$physicalDisk.OperationalStatus
                }

                $diskHealthStatus = [string]$physicalDisk.HealthStatus
                $mediaType = [string]$physicalDisk.MediaType
            }

            if ([string]::IsNullOrWhiteSpace($mediaType) -and $null -ne $win32Disk) {
                $mediaType = [string]$win32Disk.MediaType
            }

            $smartPredictFailure = $null
            $smartSummary = 'Unavailable'
            if ($smartStatusRows.Count -gt 0) {
                $diskIdentityCandidates = @(
                    ConvertTo-NormalizedKey -InputText ([string]$win32Disk.PNPDeviceID),
                    ConvertTo-NormalizedKey -InputText ([string]$win32Disk.SerialNumber),
                    ConvertTo-NormalizedKey -InputText ([string]$win32Disk.Model)
                ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

                $smartMatches = @()
                foreach ($smartRow in $smartStatusRows) {
                    $smartKey = ConvertTo-NormalizedKey -InputText ([string]$smartRow.InstanceName)
                    foreach ($candidate in $diskIdentityCandidates) {
                        if ($smartKey.Contains($candidate) -or $candidate.Contains($smartKey)) {
                            $smartMatches += $smartRow
                            break
                        }
                    }
                }

                if ($smartMatches.Count -gt 0) {
                    $smartPredictFailure = ($smartMatches | Where-Object { $_.PredictFailure -eq $true }).Count -gt 0
                    $smartSummary = if ($smartPredictFailure) { 'PredictFailure=True' } else { 'PredictFailure=False' }
                }
                else {
                    $smartSummary = 'ProviderAvailableNoDirectMatch'
                }
            }

            $totalBytes = [int64]$logicalDisk.Size
            $freeBytes = [int64]$logicalDisk.FreeSpace
            $totalGb = if ($totalBytes -gt 0) { [math]::Round(($totalBytes / 1GB), 2) } else { 0 }
            $freeGb = if ($freeBytes -gt 0) { [math]::Round(($freeBytes / 1GB), 2) } else { 0 }
            $freePercent = if ($totalBytes -gt 0) { [math]::Round((($freeBytes / $totalBytes) * 100), 2) } else { 0 }

            $optimizationLastDate = 'Unavailable'
            $optimizationStatus = 'Unavailable'
            $fragmentationPercent = 'Unavailable'
            $optimizationSource = 'Unavailable'

            if ($optimizationByDriveLetter.ContainsKey($driveLetterTrimmed)) {
                $opt = $optimizationByDriveLetter[$driveLetterTrimmed]
                $optimizationSource = [string]$opt.RegistrySource
                if ($null -ne $opt.LastOptimizationRaw) {
                    $optimizationLastDate = [string]$opt.LastOptimizationRaw
                }
                if ($null -ne $opt.OptimizationStatusRaw) {
                    $optimizationStatus = [string]$opt.OptimizationStatusRaw
                }
                if ($null -ne $opt.FragmentationRaw) {
                    $fragmentationPercent = [string]$opt.FragmentationRaw
                }
            }

            $hasHealthSignal = $false
            if (-not [string]::IsNullOrWhiteSpace($diskOperationalStatus)) { $hasHealthSignal = $true }
            if (-not [string]::IsNullOrWhiteSpace($diskHealthStatus)) { $hasHealthSignal = $true }
            if ($null -ne $smartPredictFailure) { $hasHealthSignal = $true }

            $healthCategory = Get-HealthCategory -OperationalStatus $diskOperationalStatus -HealthStatus $diskHealthStatus -PredictFailure $smartPredictFailure -HasAnyHealthSignal $hasHealthSignal

            $diskKey = if ($null -ne $diskNumber) { [string]$diskNumber } else { "UNMAPPED-$driveLetterTrimmed" }
            if (-not $diskAssessmentMap.ContainsKey($diskKey)) {
                $diskAssessmentMap[$diskKey] = [pscustomobject]@{
                    DiskNumber = if ($null -ne $diskNumber) { $diskNumber } else { 'Unknown' }
                    HealthCategory = $healthCategory
                }
            }
            else {
                $existingCategory = [string]$diskAssessmentMap[$diskKey].HealthCategory
                if ($existingCategory -ne 'Error' -and $healthCategory -eq 'Error') {
                    $diskAssessmentMap[$diskKey].HealthCategory = 'Error'
                }
                elseif ($existingCategory -eq 'Healthy' -and $healthCategory -eq 'Warning') {
                    $diskAssessmentMap[$diskKey].HealthCategory = 'Warning'
                }
                elseif ($existingCategory -eq 'Healthy' -and $healthCategory -eq 'Unavailable') {
                    $diskAssessmentMap[$diskKey].HealthCategory = 'Warning'
                }
            }

            $reportRows.Add([pscustomobject]@{
                DiskNumber = if ($null -ne $diskNumber) { $diskNumber } else { 'Unknown' }
                DriveLetter = $driveLetter
                VolumeLabel = [string]$logicalDisk.VolumeName
                FileSystem = [string]$logicalDisk.FileSystem
                TotalCapacityGB = $totalGb
                FreeSpaceGB = $freeGb
                FreeSpacePercent = $freePercent
                DiskOperationalStatus = if ([string]::IsNullOrWhiteSpace($diskOperationalStatus)) { 'Unavailable' } else { $diskOperationalStatus }
                HealthStatus = if ([string]::IsNullOrWhiteSpace($diskHealthStatus)) { 'Unavailable' } else { $diskHealthStatus }
                SmartHealth = $smartSummary
                HealthWarningsOrErrors = $healthCategory
                LastOptimizationDate = $optimizationLastDate
                OptimizationStatus = $optimizationStatus
                FragmentationPercent = $fragmentationPercent
                MediaType = if ([string]::IsNullOrWhiteSpace($mediaType)) { 'Unavailable' } else { $mediaType }
                OptimizationDataSource = $optimizationSource
            }) | Out-Null
        }
        catch {
            Write-Log -Level 'ERROR' -Message "Failed processing logical disk '$($logicalDisk.DeviceID)': $($_.Exception.Message)"
        }
    }

    $sortedRows = @($reportRows | Sort-Object -Property @{Expression = 'DiskNumber'; Descending = $false}, @{Expression = 'DriveLetter'; Descending = $false})

    Write-Log -Message 'Disk Health and Optimization Report:'
    $sortedRows |
        Select-Object DiskNumber, DriveLetter, VolumeLabel, FileSystem, TotalCapacityGB, FreeSpaceGB, FreeSpacePercent, DiskOperationalStatus, HealthStatus, SmartHealth, HealthWarningsOrErrors, LastOptimizationDate, OptimizationStatus, FragmentationPercent, MediaType |
        Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log -Message $_ }

    $totalDisksChecked = $diskAssessmentMap.Keys.Count
    $healthyDisks = @($diskAssessmentMap.Values | Where-Object { $_.HealthCategory -eq 'Healthy' }).Count
    $warningDisks = @($diskAssessmentMap.Values | Where-Object { $_.HealthCategory -eq 'Warning' }).Count
    $errorDisks = @($diskAssessmentMap.Values | Where-Object { $_.HealthCategory -eq 'Error' }).Count
    $unavailableHealthChecks = @($diskAssessmentMap.Values | Where-Object { $_.HealthCategory -eq 'Unavailable' }).Count

    Write-Log -Message 'Summary:'
    Write-Log -Message ("  Total disks checked: {0}" -f $totalDisksChecked)
    Write-Log -Message ("  Healthy disks: {0}" -f $healthyDisks)
    Write-Log -Message ("  Disks with warnings: {0}" -f $warningDisks)
    Write-Log -Message ("  Disks with errors: {0}" -f $errorDisks)
    Write-Log -Message ("  Health checks that could not be completed: {0}" -f $unavailableHealthChecks)
    Write-Log -Message ("  Log file: {0}" -f $script:LogFile)
    Write-Log -Message 'Script end.'

    $sortedRows
}
catch {
    Write-Log -Level 'ERROR' -Message "Unhandled script error: $($_.Exception.Message)"
    throw
}
