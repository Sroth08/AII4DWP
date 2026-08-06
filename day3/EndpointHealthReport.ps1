# Endpoint Health Report (PowerShell 5.1)
# READ-ONLY: This script only reads system information and does not modify system state.

# =========================
# Section 1: System Uptime
# =========================
# What this does:
# - Reads the OS last boot time.
# - Calculates elapsed uptime from current time.
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$lastBoot = $os.LastBootUpTime
$uptime = (Get-Date) - $lastBoot

Write-Host "=== System Uptime ==="
Write-Host ("Last Boot Time : {0}" -f $lastBoot)
Write-Host ("Uptime         : {0} days {1} hours {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)
Write-Host ""

# =============================
# Section 2: Free Disk Space
# =============================
# What this does:
# - Reads local fixed disks only (DriveType=3).
# - Reports free GB, total GB, and free percentage.
# VERIFY BEFORE RUNNING: Confirm DriveType=3 scope matches your DWP reporting standard.
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"

Write-Host "=== Free Disk Space (Local Fixed Drives) ==="
$disks |
    Select-Object DeviceID,
                  @{Name='FreeGB';Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
                  @{Name='TotalGB';Expression={[math]::Round($_.Size / 1GB, 2)}},
                  @{Name='FreePercent';Expression={[math]::Round(($_.FreeSpace / $_.Size) * 100, 2)}} |
    Format-Table -AutoSize
Write-Host ""

# ==========================================
# Section 3: Pending Reboot (Registry Check)
# ==========================================
# What this does:
# - Checks common registry indicators that signal a pending reboot.
# - Aggregates results into an overall pending reboot state.
# VERIFY BEFORE RUNNING: Confirm these registry paths are approved in your environment.
$rebootChecks = @(
    @{ Name = "Component Based Servicing"; Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" },
    @{ Name = "Windows Update RebootRequired"; Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" },
    @{ Name = "Pending File Rename Operations"; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"; ValueName = "PendingFileRenameOperations" }
)

$pendingReboot = $false
$rebootResults = foreach ($check in $rebootChecks) {
    if ($check.ContainsKey("ValueName")) {
        $regValueObject = Get-ItemProperty -Path $check.Path -Name $check.ValueName -ErrorAction SilentlyContinue
        $present = $null -ne $regValueObject
    }
    else {
        $present = Test-Path -Path $check.Path
    }

    if ($present) { $pendingReboot = $true }

    [pscustomobject]@{
        Check   = $check.Name
        Present = $present
    }
}

Write-Host "=== Pending Reboot Status ==="
$rebootResults | Format-Table -AutoSize
Write-Host ("Overall Pending Reboot: {0}" -f $pendingReboot)
Write-Host ""

# =============================================
# Section 4: Top 5 Processes by Memory (WS)
# =============================================
# What this does:
# - Reads running processes.
# - Sorts by Working Set (WS) descending.
# - Displays top 5 memory consumers and executable full path.
# VERIFY BEFORE RUNNING: Some process paths may be unavailable without elevated rights.
Write-Host "=== Top 5 Processes by Memory (Working Set) ==="
Get-Process |
    Sort-Object -Property WS -Descending |
    Select-Object -First 5 Name, Id, @{Name='WorkingSetMB';Expression={[math]::Round($_.WS / 1MB, 2)}}, @{Name='ExecutablePath';Expression={ if ($_.Path) { $_.Path } else { try { $_.MainModule.FileName } catch { 'Access denied or unavailable' } } }} |
    Format-Table -AutoSize
Write-Host ""

# =====================================
# Section 5: Top 5 Processes by CPU
# =====================================
# What this does:
# - Reads running processes with CPU data.
# - Sorts by cumulative CPU seconds descending.
# - Displays top 5 CPU consumers and executable full path.
# VERIFY BEFORE RUNNING: CPU values are cumulative since process start, not real-time CPU percentage.
# VERIFY BEFORE RUNNING: Some process paths may be unavailable without elevated rights.
Write-Host "=== Top 5 Processes by CPU (Cumulative Seconds) ==="
Get-Process |
    Where-Object { $_.CPU -ne $null } |
    Sort-Object -Property CPU -Descending |
    Select-Object -First 5 Name, Id, @{Name='CPUSeconds';Expression={[math]::Round($_.CPU, 2)}}, @{Name='ExecutablePath';Expression={ if ($_.Path) { $_.Path } else { try { $_.MainModule.FileName } catch { 'Access denied or unavailable' } } }} |
    Format-Table -AutoSize
Write-Host ""

# ==========================================
# Section 6: Last 5 System Log Errors
# ==========================================
# What this does:
# - Reads the latest 5 Error events from the System event log.
# - Shows TimeCreated, Event ID, Provider, and Message.
# VERIFY BEFORE RUNNING: Ensure your account is permitted to read the System event log.
Write-Host "=== Last 5 System Log Errors ==="
try {
    Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 2 } -MaxEvents 5 |
        Select-Object TimeCreated, Id, ProviderName, Message |
        Format-Table -Wrap -AutoSize
}
catch {
    Write-Warning "Unable to read System log: $($_.Exception.Message)"
}
