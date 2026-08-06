# Disk Health and Optimization Read-Only Report

## Script Purpose

This package provides a strict read-only PowerShell 5.1 script for endpoint diagnostics:

- Reports local disk and volume capacity details.
- Reports health indicators where available.
- Reports optimization metadata where available.
- Logs all actions, warnings, and errors to a timestamped log file.

Script file:

- day3/Exercise/DiskHealthOptimizationReport-Exercise.ps1

## Parameters

- WorkingRoot
  - Optional path for log output.
  - Default: $env:ProgramData\DWPDiskHealthReport

## Examples

Run with defaults:

```powershell
.\day3\Exercise\DiskHealthOptimizationReport-Exercise.ps1
```

Run with a custom log root:

```powershell
.\day3\Exercise\DiskHealthOptimizationReport-Exercise.ps1 -WorkingRoot "C:\ProgramData\DWPDiskHealthReportLab"
```

## Output Fields

The report includes these fields for each logical disk/volume row:

- DiskNumber
- DriveLetter
- VolumeLabel
- FileSystem
- TotalCapacityGB
- FreeSpaceGB
- FreeSpacePercent
- DiskOperationalStatus
- HealthStatus
- SmartHealth
- HealthWarningsOrErrors
- LastOptimizationDate
- OptimizationStatus
- FragmentationPercent
- MediaType
- OptimizationDataSource

## Logging Behavior

The script writes all key actions to:

- WorkingRoot\Logs\DiskHealthOptimizationReport_yyyyMMdd_HHmmss.log

Logged events include:

- Read-only safety banner
- Verification checklist
- Discovery and query steps
- Warnings and errors
- Formatted report output
- Summary totals

## SMART Data Collection Limitations

SMART diagnostics are hardware, driver, and storage-stack dependent. Expect these limitations:

- Some disks/controllers do not expose SMART through root\wmi provider classes.
- Provider data may not map cleanly to a specific disk on all hardware.
- Virtualized environments may provide partial or no SMART status.
- Predictive failure status can be unavailable even when disk health is otherwise visible.

## Safety Considerations

This script is diagnostics-only and must not change endpoint state:

- It does not run Optimize-Volume.
- It does not run Defrag.exe.
- It does not run disk repair commands.
- It does not modify disk settings, partitions, or volumes.
- It does not modify registry values used for storage configuration.

Only report/log artifacts are generated under WorkingRoot.

## Validation Steps Before Production Deployment

1. Verify command availability on target endpoint builds:
   - Get-Disk
   - Get-Partition
   - Get-CimInstance
   - Get-WmiObject

2. Verify data source compatibility:
   - CIM/WMI classes:
     - Win32_LogicalDisk
     - Win32_DiskDrive
     - root\wmi:MSStorageDriver_FailurePredictStatus

3. Verify registry read access for optimization metadata:
   - HKLM:\SOFTWARE\Microsoft\Dfrg\Statistics\Volume*

4. Run in a pilot group and confirm:
   - No endpoint configuration drift
   - Log file creation only under WorkingRoot
   - Expected health categorization and report readability

5. Validate role/permission constraints:
   - Ensure service accounts have sufficient read permissions for required providers.
