param(
    [switch]$DryRun,
    [int]$LookbackHours = 72,
    [int]$TopProcesses = 15,
    [string]$OutputPath = $(Join-Path -Path $PSScriptRoot -ChildPath ("Floor6-Evidence-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
)

# Evidence collection only: no remediation, no configuration changes.
$script:CollectorErrors = @()
$script:NowUtc = (Get-Date).ToUniversalTime().ToString("o")

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ====" -ForegroundColor Cyan
}

function Add-CollectorError {
    param(
        [string]$Section,
        [string]$Operation,
        [System.Exception]$Exception
    )

    $script:CollectorErrors += [pscustomobject]@{
        timestamp  = (Get-Date).ToUniversalTime().ToString("o")
        section    = $Section
        operation  = $Operation
        message    = $Exception.Message
        errorType  = $Exception.GetType().FullName
    }
}

function New-EvidenceSection {
    param(
        [string]$Name,
        $Data
    )

    [pscustomobject]@{
        sectionName = $Name
        collectedAt = (Get-Date).ToUniversalTime().ToString("o")
        data        = $Data
    }
}

function Get-SafeEventData {
    param(
        [string]$LogName,
        [int[]]$Ids,
        [datetime]$StartTime,
        [int]$MaxEvents = 200
    )

    try {
        $filter = @{
            LogName   = $LogName
            StartTime = $StartTime
        }
        if ($Ids -and $Ids.Count -gt 0) {
            $filter.Id = $Ids
        }

        Get-WinEvent -FilterHashtable $filter -ErrorAction Stop -MaxEvents $MaxEvents |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    }
    catch {
        Add-CollectorError -Section "EventLogs" -Operation "Get-WinEvent $LogName" -Exception $_.Exception
        @()
    }
}

function Get-RegistryApps {
    param([string]$Path)

    try {
        Get-ItemProperty -Path $Path -ErrorAction Stop |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation, UninstallString, PSPath
    }
    catch {
        Add-CollectorError -Section "InstalledApplications" -Operation "Read registry path $Path" -Exception $_.Exception
        @()
    }
}

function Parse-InstallDate {
    param([string]$InstallDate)

    if ([string]::IsNullOrWhiteSpace($InstallDate)) {
        return $null
    }

    try {
        if ($InstallDate -match '^\d{8}$') {
            return [datetime]::ParseExact($InstallDate, 'yyyyMMdd', $null)
        }
        return [datetime]::Parse($InstallDate)
    }
    catch {
        return $null
    }
}

$collectionPlan = @(
    "Installed applications inventory (registry-based)",
    "Recent application installs from uninstall metadata and MSI installer events",
    "Startup applications (Win32_StartupCommand and Startup folders)",
    "Scheduled tasks and recent task run state",
    "Services inventory and runtime state",
    "Login duration indicators (Diagnostics-Performance and User Profile events)",
    "Boot performance metrics and latest boot degradation signals",
    "CPU usage snapshot and top CPU processes",
    "Memory pressure snapshot and top memory processes",
    "Event Viewer entries related to logon/performance",
    "Intune Management Extension log metadata and recent log tails",
    "Application deployment activity from Intune and deployment event logs"
)

Write-SectionHeader -Title "Execution Context"
Write-Host "DryRun: $DryRun"
Write-Host "LookbackHours: $LookbackHours"
Write-Host "OutputPath: $OutputPath"

if ($DryRun) {
    Write-SectionHeader -Title "DryRun Collection Plan"
    $collectionPlan | ForEach-Object { Write-Host "- $_" }

    $dryRunResult = [ordered]@{
        metadata = [ordered]@{
            generatedAtUtc = $script:NowUtc
            dryRun         = $true
            lookbackHours  = $LookbackHours
            hostname       = $env:COMPUTERNAME
            user           = "$env:USERDOMAIN\\$env:USERNAME"
        }
        plan = $collectionPlan
        notes = @(
            "DryRun mode: no evidence collection executed.",
            "No remediation or configuration changes are performed by this script."
        )
        errors = $script:CollectorErrors
    }

    $dryRunResult | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "DryRun plan written to $OutputPath" -ForegroundColor Green
    return
}

$startTime = (Get-Date).AddHours(-1 * [Math]::Abs($LookbackHours))
$sections = @()

# =============================
# SECTION: Installed Applications
# =============================
Write-SectionHeader -Title "Collecting Installed Applications"
$allApps = @()
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($path in $registryPaths) {
    $allApps += Get-RegistryApps -Path $path
}
$allApps = $allApps | Sort-Object DisplayName -Unique
$sections += New-EvidenceSection -Name "InstalledApplications" -Data $allApps

Write-SectionHeader -Title "Collecting Recent Application Installations"
$recentApps = foreach ($app in $allApps) {
    $parsed = Parse-InstallDate -InstallDate $app.InstallDate
    if ($parsed -and $parsed -ge $startTime) {
        [pscustomobject]@{
            DisplayName     = $app.DisplayName
            DisplayVersion  = $app.DisplayVersion
            Publisher       = $app.Publisher
            InstallDateRaw  = $app.InstallDate
            InstallDateUtc  = $parsed.ToUniversalTime().ToString("o")
            InstallLocation = $app.InstallLocation
            RegistryPath    = $app.PSPath
        }
    }
}
$msiInstallEvents = Get-SafeEventData -LogName "Application" -Ids @(1033, 11707, 11724) -StartTime $startTime -MaxEvents 250 |
    Where-Object { $_.ProviderName -eq "MsiInstaller" }

$sections += New-EvidenceSection -Name "RecentApplicationInstallations" -Data ([ordered]@{
    fromUninstallRegistry = $recentApps
    msiInstallerEvents    = $msiInstallEvents
})

# =============================
# SECTION: Startup and Scheduled Execution
# =============================
Write-SectionHeader -Title "Collecting Startup Applications"
try {
    $startupCommands = Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction Stop |
        Select-Object Name, Command, Location, User
}
catch {
    Add-CollectorError -Section "StartupApplications" -Operation "Get-CimInstance Win32_StartupCommand" -Exception $_.Exception
    $startupCommands = @()
}

$startupFolderPaths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
)
$startupFolderItems = @()
foreach ($folder in $startupFolderPaths) {
    try {
        if (Test-Path -Path $folder) {
            $startupFolderItems += Get-ChildItem -Path $folder -ErrorAction Stop |
                Select-Object Name, FullName, LastWriteTime
        }
    }
    catch {
        Add-CollectorError -Section "StartupApplications" -Operation "Read startup folder $folder" -Exception $_.Exception
    }
}

$sections += New-EvidenceSection -Name "StartupApplications" -Data ([ordered]@{
    startupCommands = $startupCommands
    startupFolders  = $startupFolderItems
})

Write-SectionHeader -Title "Collecting Scheduled Tasks"
try {
    $scheduledTasks = Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
        $taskInfo = $null
        try {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction Stop
        }
        catch {
            Add-CollectorError -Section "ScheduledTasks" -Operation "Get-ScheduledTaskInfo $($_.TaskPath)$($_.TaskName)" -Exception $_.Exception
        }

        [pscustomobject]@{
            TaskName      = $_.TaskName
            TaskPath      = $_.TaskPath
            State         = $_.State.ToString()
            LastRunTime   = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
            LastTaskResult= if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
            NextRunTime   = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
            Actions       = ($_.Actions | ForEach-Object { $_.Execute }) -join "; "
            Triggers      = ($_.Triggers | ForEach-Object { $_.TriggerType }) -join "; "
        }
    }
}
catch {
    Add-CollectorError -Section "ScheduledTasks" -Operation "Get-ScheduledTask" -Exception $_.Exception
    $scheduledTasks = @()
}
$sections += New-EvidenceSection -Name "ScheduledTasks" -Data $scheduledTasks

# =============================
# SECTION: Services
# =============================
Write-SectionHeader -Title "Collecting Services"
try {
    $serviceInventory = Get-CimInstance -ClassName Win32_Service -ErrorAction Stop |
        Select-Object Name, DisplayName, State, StartMode, StartName, PathName
}
catch {
    Add-CollectorError -Section "Services" -Operation "Get-CimInstance Win32_Service" -Exception $_.Exception
    $serviceInventory = @()
}
$sections += New-EvidenceSection -Name "Services" -Data $serviceInventory

# =============================
# SECTION: Logon and Boot Performance Indicators
# =============================
Write-SectionHeader -Title "Collecting Logon and Boot Performance Indicators"
$diagEvents = Get-SafeEventData -LogName "Microsoft-Windows-Diagnostics-Performance/Operational" -Ids @(100,101,102,103,109,110,200,201,202,203) -StartTime $startTime -MaxEvents 300
$userProfileEvents = Get-SafeEventData -LogName "Microsoft-Windows-User Profile Service/Operational" -Ids @() -StartTime $startTime -MaxEvents 300
$winlogonEvents = Get-SafeEventData -LogName "Microsoft-Windows-Winlogon/Operational" -Ids @() -StartTime $startTime -MaxEvents 300

$sections += New-EvidenceSection -Name "LoginDurationIndicators" -Data ([ordered]@{
    diagnosticsPerformanceEvents = $diagEvents
    userProfileEvents            = $userProfileEvents
    winlogonEvents               = $winlogonEvents
})

Write-SectionHeader -Title "Collecting Device Boot Performance"
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $lastBoot = $os.LastBootUpTime
}
catch {
    Add-CollectorError -Section "DeviceBootPerformance" -Operation "Get-CimInstance Win32_OperatingSystem" -Exception $_.Exception
    $os = $null
    $lastBoot = $null
}

$bootPerfEvents = @()
try {
    $bootPerfEvents = Get-WinEvent -FilterHashtable @{
        LogName = "Microsoft-Windows-Diagnostics-Performance/Operational"
        Id      = 100
        StartTime = $startTime
    } -ErrorAction Stop -MaxEvents 10 | ForEach-Object {
        $p = $_.Properties
        [pscustomobject]@{
            TimeCreated                 = $_.TimeCreated
            EventId                     = $_.Id
            BootTimeMs                  = if ($p.Count -gt 5) { $p[5].Value } else { $null }
            MainPathBootTimeMs          = if ($p.Count -gt 6) { $p[6].Value } else { $null }
            BootUserProfileTimeMs       = if ($p.Count -gt 15) { $p[15].Value } else { $null }
            BootExplorerInitTimeMs      = if ($p.Count -gt 17) { $p[17].Value } else { $null }
            BootNumStartupApps          = if ($p.Count -gt 18) { $p[18].Value } else { $null }
            BootPostBootTimeMs          = if ($p.Count -gt 19) { $p[19].Value } else { $null }
            IsDegradationEvent          = if ($p.Count -gt 20) { $p[20].Value } else { $null }
        }
    }
}
catch {
    Add-CollectorError -Section "DeviceBootPerformance" -Operation "Parse Diagnostics-Performance EventId 100" -Exception $_.Exception
}

$sections += New-EvidenceSection -Name "DeviceBootPerformance" -Data ([ordered]@{
    lastBootUpTime = if ($lastBoot) { $lastBoot.ToUniversalTime().ToString("o") } else { $null }
    diagnosticsPerformanceBootEvents = $bootPerfEvents
})

# =============================
# SECTION: CPU and Memory
# =============================
Write-SectionHeader -Title "Collecting CPU Consumption"
try {
    $cpuCounterSamples = (Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 -ErrorAction Stop).CounterSamples |
        Select-Object TimeStamp, CookedValue
}
catch {
    Add-CollectorError -Section "CPUConsumption" -Operation "Get-Counter Processor(_Total)" -Exception $_.Exception
    $cpuCounterSamples = @()
}

try {
    $topCpuProcesses = Get-Process -ErrorAction Stop |
        Sort-Object CPU -Descending |
        Select-Object -First $TopProcesses Name, Id, CPU, WS, PM, VM, StartTime
}
catch {
    Add-CollectorError -Section "CPUConsumption" -Operation "Get-Process top CPU" -Exception $_.Exception
    $topCpuProcesses = @()
}

$sections += New-EvidenceSection -Name "CPUConsumption" -Data ([ordered]@{
    processorSamples = $cpuCounterSamples
    topProcesses     = $topCpuProcesses
})

Write-SectionHeader -Title "Collecting Memory Consumption"
try {
    $osMem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $memorySummary = [pscustomobject]@{
        TotalVisibleMemoryKB = [int64]$osMem.TotalVisibleMemorySize
        FreePhysicalMemoryKB = [int64]$osMem.FreePhysicalMemory
        TotalVirtualMemoryKB = [int64]$osMem.TotalVirtualMemorySize
        FreeVirtualMemoryKB  = [int64]$osMem.FreeVirtualMemory
        InUsePhysicalMemoryKB = [int64]$osMem.TotalVisibleMemorySize - [int64]$osMem.FreePhysicalMemory
    }
}
catch {
    Add-CollectorError -Section "MemoryConsumption" -Operation "Get-CimInstance Win32_OperatingSystem memory" -Exception $_.Exception
    $memorySummary = $null
}

try {
    $topMemoryProcesses = Get-Process -ErrorAction Stop |
        Sort-Object WS -Descending |
        Select-Object -First $TopProcesses Name, Id, WS, PM, VM, CPU, StartTime
}
catch {
    Add-CollectorError -Section "MemoryConsumption" -Operation "Get-Process top memory" -Exception $_.Exception
    $topMemoryProcesses = @()
}

$sections += New-EvidenceSection -Name "MemoryConsumption" -Data ([ordered]@{
    memorySummary = $memorySummary
    topProcesses  = $topMemoryProcesses
})

# =============================
# SECTION: Event Viewer Logon/Performance and Deployment Activity
# =============================
Write-SectionHeader -Title "Collecting Event Viewer Logon/Performance Entries"
$systemLogonEvents = Get-SafeEventData -LogName "System" -Ids @(6005,6006,6008,7000,7001,7009,7011,7022,7031,7034) -StartTime $startTime -MaxEvents 300
$applicationPerfEvents = Get-SafeEventData -LogName "Application" -Ids @() -StartTime $startTime -MaxEvents 250 |
    Where-Object { $_.Message -match "logon|login|profile|slow|performance|hang|timeout" }

$sections += New-EvidenceSection -Name "EventViewerLogonPerformance" -Data ([ordered]@{
    systemEvents      = $systemLogonEvents
    applicationEvents = $applicationPerfEvents
})

Write-SectionHeader -Title "Collecting Intune Management Extension Activity"
$imeLogRoot = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$imeLogData = @()
try {
    if (Test-Path -Path $imeLogRoot) {
        $imeFiles = Get-ChildItem -Path $imeLogRoot -File -ErrorAction Stop |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10

        foreach ($file in $imeFiles) {
            $tail = @()
            try {
                $tail = Get-Content -Path $file.FullName -Tail 80 -ErrorAction Stop
            }
            catch {
                Add-CollectorError -Section "IntuneManagementExtension" -Operation "Read log tail $($file.FullName)" -Exception $_.Exception
            }

            $imeLogData += [pscustomobject]@{
                Name          = $file.Name
                FullName      = $file.FullName
                LastWriteTime = $file.LastWriteTime
                LengthBytes   = $file.Length
                Tail          = $tail
            }
        }
    }
    else {
        Add-CollectorError -Section "IntuneManagementExtension" -Operation "IME log folder not found" -Exception ([System.IO.DirectoryNotFoundException]::new($imeLogRoot))
    }
}
catch {
    Add-CollectorError -Section "IntuneManagementExtension" -Operation "Enumerate IME logs" -Exception $_.Exception
}
$sections += New-EvidenceSection -Name "IntuneManagementExtensionActivity" -Data $imeLogData

Write-SectionHeader -Title "Collecting Application Deployment Activity"
$dmeAdminEvents = Get-SafeEventData -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin" -Ids @() -StartTime $startTime -MaxEvents 300
$dmeOperationalEvents = Get-SafeEventData -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational" -Ids @() -StartTime $startTime -MaxEvents 300
$appxEvents = Get-SafeEventData -LogName "Microsoft-Windows-AppXDeploymentServer/Operational" -Ids @() -StartTime $startTime -MaxEvents 300

$deploymentPattern = "install|deployment|win32|intune|error|failed|retry|remediation|policy"
$sections += New-EvidenceSection -Name "ApplicationDeploymentActivity" -Data ([ordered]@{
    dmeAdminFiltered = $dmeAdminEvents | Where-Object { $_.Message -match $deploymentPattern }
    dmeOperationalFiltered = $dmeOperationalEvents | Where-Object { $_.Message -match $deploymentPattern }
    appxDeploymentFiltered = $appxEvents | Where-Object { $_.Message -match $deploymentPattern }
})

# =============================
# SECTION: Final Output
# =============================
Write-SectionHeader -Title "Writing JSON Output"

$result = [ordered]@{
    metadata = [ordered]@{
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        dryRun         = $false
        lookbackHours  = $LookbackHours
        hostname       = $env:COMPUTERNAME
        user           = "$env:USERDOMAIN\\$env:USERNAME"
        osVersion      = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Version)
    }
    sections = $sections
    errors   = $script:CollectorErrors
    notes    = @(
        "Evidence collection only. No remediation or configuration changes performed.",
        "Some logs may require elevated permissions; access failures are captured in the errors section."
    )
}

$result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Evidence JSON written to: $OutputPath" -ForegroundColor Green
Write-Host "Collection complete. Error count: $($script:CollectorErrors.Count)" -ForegroundColor Yellow
