<#
Purpose:
- Capture a quick local endpoint health snapshot for a DWP engineer.
- Show computer identity and total physical memory.
- Show free space on the C drive in GB.
- Show top 5 memory-consuming processes.
- Show the latest 10 System event log errors (Level 2).
- Show count of stale (non-special) user profiles not used for 90+ days.

Author:
- DWP Endpoint Engineering (refactored for readability)

How to run:
1. Open Windows PowerShell 5.1.
2. Navigate to the script folder.
3. Run: .\inherited.ps1

Notes:
- This refactor keeps original behavior unchanged and improves readability only.
#>

# Get core computer system information (for example, machine name and total RAM).
$computerSystemInfo = Get-CimInstance Win32_ComputerSystem

# Get free bytes on drive C by expanding the Free property from the C drive object.
$freeBytesOnCDrive = Get-PSDrive C | Select-Object -ExpandProperty Free

# Get running processes, sort by working set memory descending, and keep top 5.
$topFiveProcessesByWorkingSet = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Get the most recent 10 events from the System log and keep only error-level events (Level 2).
$recentSystemErrorEvents = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Get user profiles and keep only non-special profiles not used in the last 90 days.
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
     -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
}

# Print computer name and total physical memory.
Write-Host $computerSystemInfo.Name $computerSystemInfo.TotalPhysicalMemory

# Print free space on C drive converted from bytes to GB with 2 decimal places.
Write-Host ([math]::Round($freeBytesOnCDrive / 1GB, 2)) 'GB free'

# Print each top process name and its working set memory value.
$topFiveProcessesByWorkingSet | ForEach-Object { Write-Host $_.Name $_.WS }

# Print time and message for each recent System error event.
$recentSystemErrorEvents | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# Print stale profile count only when at least one stale profile exists.
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }
