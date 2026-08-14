[CmdletBinding()]
param(
    [switch]$DryRun,
    [int]$LookbackHours = 72,
    [int]$TopProcesses = 15,
    [int]$MaxEventsPerLog = 300,
    [string]$AppNameHint = "document management",
    [string]$OutputPath = $(Join-Path -Path $PSScriptRoot -ChildPath ("Floor6-Evidence-Improved-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
)

# Evidence collection only: no remediation, no configuration changes.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$script:CollectorErrors = @()
$script:NowUtc = (Get-Date).ToUniversalTime().ToString("o")
$script:NowLocal = (Get-Date).ToString("o")
$script:Sections = [ordered]@{}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "==== $Title ====" -ForegroundColor Cyan
}

function Add-CollectorError {
    param(
        [string]$Section,
        [string]$Operation,
        [System.Exception]$Exception,
        [string]$FullyQualifiedErrorId = ""
    )

    $script:CollectorErrors += [pscustomobject]@{
        timestampUtc          = (Get-Date).ToUniversalTime().ToString("o")
        section               = $Section
        operation             = $Operation
        message               = $Exception.Message
        errorType             = $Exception.GetType().FullName
        fullyQualifiedErrorId = $FullyQualifiedErrorId
    }
}

function Add-SectionResult {
    param(
        [string]$Name,
        [string]$Status,
        [object]$Data
    )

    $itemCount = 0
    if ($null -eq $Data) {
        $itemCount = 0
    }
    elseif ($Data -is [System.Collections.IDictionary]) {
        $itemCount = $Data.Count
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
        $itemCount = @($Data).Count
    }
    else {
        $itemCount = 1
    }

    $script:Sections[$Name] = [ordered]@{
        status       = $Status
        collectedAt  = (Get-Date).ToUniversalTime().ToString("o")
        itemCount    = $itemCount
        data         = $Data
    }
}

function Invoke-Safely {
    param(
        [string]$Section,
        [string]$Operation,
        [scriptblock]$ScriptBlock,
        $DefaultValue = $null
    )

    try {
        & $ScriptBlock
    }
    catch {
        Add-CollectorError -Section $Section -Operation $Operation -Exception $_.Exception -FullyQualifiedErrorId $_.FullyQualifiedErrorId
        $DefaultValue
    }
}

function Get-SafeEventData {
    param(
        [string]$Section,
        [string]$LogName,
        [int[]]$Ids,
        [datetime]$StartTime,
        [int]$MaxEvents = 200
    )

    Invoke-Safely -Section $Section -Operation "Get-WinEvent $LogName" -DefaultValue @() -ScriptBlock {
        $filter = @{
            LogName   = $LogName
            StartTime = $StartTime
        }
        if ($Ids -and $Ids.Count -gt 0) {
            $filter.Id = $Ids
        }

        Get-WinEvent -FilterHashtable $filter -ErrorAction Stop -MaxEvents $MaxEvents |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message, RecordId
    }
}

function Get-RegistryApps {
    param([string]$Path)

    Invoke-Safely -Section "InstalledApplications" -Operation "Read registry path $Path" -DefaultValue @() -ScriptBlock {
        Get-ItemProperty -Path $Path -ErrorAction Stop |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation, UninstallString, PSPath
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

function Get-ProcessSafe {
    param(
        [object]$Process,
        [string]$Field
    )

    try {
        $Process.$Field
    }
    catch {
        $null
    }
}

$collectionPlan = @(
    "Execution context and device baseline metadata for cross-device comparison",
    "Installed applications inventory (registry-based)",
    "Recent application installs from uninstall metadata and MSI installer events",
    "Startup applications (Win32_StartupCommand and Startup folders)",
    "Scheduled tasks including startup and app-hint filtered candidates",
    "Services inventory including app-hint filtered candidates",
    "Login duration indicators (Diagnostics-Performance, User Profile, Winlogon)",
    "Boot performance metrics and boot degradation indicators",
    "CPU and memory snapshots and top processes",
    "Security logon evidence (4624/4625) and logon/performance event logs",
    "Intune Management Extension activity and Win32 app state registry evidence",
    "Application deployment activity from MDM and AppX deployment logs",
    "Summary metrics for easy comparison across multiple devices"
)

Write-SectionHeader -Title "Execution Context"
Write-Host "DryRun: $DryRun"
Write-Host "LookbackHours: $LookbackHours"
Write-Host "OutputPath: $OutputPath"
Write-Host "AppNameHint: $AppNameHint"

$startTime = (Get-Date).AddHours(-1 * [Math]::Abs($LookbackHours))

if ($DryRun) {
    Write-SectionHeader -Title "DryRun Collection Plan"
    $collectionPlan | ForEach-Object { Write-Host "- $_" }

    $availableLogs = @(
        "Application",
        "System",
        "Security",
        "Microsoft-Windows-Diagnostics-Performance/Operational",
        "Microsoft-Windows-User Profile Service/Operational",
        "Microsoft-Windows-Winlogon/Operational",
        "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin",
        "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational",
        "Microsoft-Windows-AppXDeploymentServer/Operational"
    ) | ForEach-Object {
        [pscustomobject]@{
            logName = $_
            exists  = [bool](Get-WinEvent -ListLog $_ -ErrorAction SilentlyContinue)
        }
    }

    $dryRunResult = [ordered]@{
        metadata = [ordered]@{
            generatedAtUtc = $script:NowUtc
            generatedAtLocal = $script:NowLocal
            dryRun         = $true
            lookbackHours  = $LookbackHours
            hostname       = $env:COMPUTERNAME
            user           = "$env:USERDOMAIN\$env:USERNAME"
            appNameHint    = $AppNameHint
        }
        plan = $collectionPlan
        checks = [ordered]@{
            logsDetected = $availableLogs
            imeLogFolderExists = (Test-Path -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs")
            outputDirectoryExists = (Test-Path -Path (Split-Path -Path $OutputPath -Parent))
        }
        notes = @(
            "DryRun mode: no evidence collection executed.",
            "No remediation or configuration changes are performed by this script."
        )
        errors = $script:CollectorErrors
    }

    $dryRunResult | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "DryRun plan written to $OutputPath" -ForegroundColor Green
    return
}

# =============================
# SECTION: Device Baseline Metadata
# =============================
Write-SectionHeader -Title "Collecting Device Baseline Metadata"
$deviceMetadata = Invoke-Safely -Section "DeviceBaseline" -Operation "Collect Win32 metadata" -DefaultValue $null -ScriptBlock {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop

    [ordered]@{
        hostname              = $env:COMPUTERNAME
        currentUser           = "$env:USERDOMAIN\$env:USERNAME"
        domain                = $env:USERDOMAIN
        osCaption             = $os.Caption
        osVersion             = $os.Version
        osBuildNumber         = $os.BuildNumber
        installDate           = if ($os.InstallDate) { $os.InstallDate.ToUniversalTime().ToString("o") } else { $null }
        lastBootUpTime        = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToUniversalTime().ToString("o") } else { $null }
        localTime             = (Get-Date).ToString("o")
        utcTime               = (Get-Date).ToUniversalTime().ToString("o")
        timezone              = (Get-TimeZone).Id
        manufacturer          = $cs.Manufacturer
        model                 = $cs.Model
        totalPhysicalMemory   = [int64]$cs.TotalPhysicalMemory
        serialNumber          = $bios.SerialNumber
        isElevated            = ([bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    }
}
Add-SectionResult -Name "DeviceBaseline" -Status ($(if ($null -eq $deviceMetadata) { "partial" } else { "ok" })) -Data $deviceMetadata

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
$allApps = $allApps | Sort-Object DisplayName, DisplayVersion, Publisher -Unique
Add-SectionResult -Name "InstalledApplications" -Status "ok" -Data $allApps

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
$msiInstallEvents = Get-SafeEventData -Section "RecentApplicationInstallations" -LogName "Application" -Ids @(1033, 11707, 11724) -StartTime $startTime -MaxEvents $MaxEventsPerLog |
    Where-Object { $_.ProviderName -eq "MsiInstaller" }

Add-SectionResult -Name "RecentApplicationInstallations" -Status "ok" -Data ([ordered]@{
    fromUninstallRegistry = $recentApps
    msiInstallerEvents    = $msiInstallEvents
})

# =============================
# SECTION: Startup and Scheduled Execution
# =============================
Write-SectionHeader -Title "Collecting Startup Applications"
$startupCommands = Invoke-Safely -Section "StartupApplications" -Operation "Get-CimInstance Win32_StartupCommand" -DefaultValue @() -ScriptBlock {
    Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction Stop |
        Select-Object Name, Command, Location, User
}

$startupFolderPaths = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
)
$startupFolderItems = @()
foreach ($folder in $startupFolderPaths) {
    $folderItems = Invoke-Safely -Section "StartupApplications" -Operation "Read startup folder $folder" -DefaultValue @() -ScriptBlock {
        if (Test-Path -Path $folder) {
            Get-ChildItem -Path $folder -ErrorAction Stop |
                Select-Object Name, FullName, LastWriteTime
        }
        else {
            @()
        }
    }
    $startupFolderItems += $folderItems
}

Add-SectionResult -Name "StartupApplications" -Status "ok" -Data ([ordered]@{
    startupCommands = $startupCommands
    startupFolders  = $startupFolderItems
    appHintMatches  = @($startupCommands | Where-Object {
        $_.Name -match [regex]::Escape($AppNameHint) -or $_.Command -match [regex]::Escape($AppNameHint)
    })
})

Write-SectionHeader -Title "Collecting Scheduled Tasks"
$scheduledTasks = Invoke-Safely -Section "ScheduledTasks" -Operation "Get-ScheduledTask" -DefaultValue @() -ScriptBlock {
    Get-ScheduledTask -ErrorAction Stop | ForEach-Object {
        $taskInfo = Invoke-Safely -Section "ScheduledTasks" -Operation "Get-ScheduledTaskInfo $($_.TaskPath)$($_.TaskName)" -DefaultValue $null -ScriptBlock {
            Get-ScheduledTaskInfo -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction Stop
        }

        [pscustomobject]@{
            TaskName       = $_.TaskName
            TaskPath       = $_.TaskPath
            State          = $_.State.ToString()
            LastRunTime    = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
            LastTaskResult = if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
            NextRunTime    = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
            Actions        = ($_.Actions | ForEach-Object { $_.Execute }) -join "; "
            Triggers       = ($_.Triggers | ForEach-Object { $_.TriggerType }) -join "; "
        }
    }
}

$scheduledTaskCandidates = @($scheduledTasks | Where-Object {
    $_.TaskName -match [regex]::Escape($AppNameHint) -or $_.Actions -match [regex]::Escape($AppNameHint)
})

Add-SectionResult -Name "ScheduledTasks" -Status "ok" -Data ([ordered]@{
    allTasks      = $scheduledTasks
    appHintMatches = $scheduledTaskCandidates
})

# =============================
# SECTION: Services
# =============================
Write-SectionHeader -Title "Collecting Services"
$serviceInventory = Invoke-Safely -Section "Services" -Operation "Get-CimInstance Win32_Service" -DefaultValue @() -ScriptBlock {
    Get-CimInstance -ClassName Win32_Service -ErrorAction Stop |
        Select-Object Name, DisplayName, State, StartMode, StartName, PathName
}

$serviceCandidates = @($serviceInventory | Where-Object {
    $_.Name -match [regex]::Escape($AppNameHint) -or
    $_.DisplayName -match [regex]::Escape($AppNameHint) -or
    $_.PathName -match [regex]::Escape($AppNameHint)
})

Add-SectionResult -Name "Services" -Status "ok" -Data ([ordered]@{
    allServices    = $serviceInventory
    appHintMatches = $serviceCandidates
})

# =============================
# SECTION: Logon and Boot Performance Indicators
# =============================
Write-SectionHeader -Title "Collecting Logon and Boot Performance Indicators"
$diagEvents = Get-SafeEventData -Section "LoginDurationIndicators" -LogName "Microsoft-Windows-Diagnostics-Performance/Operational" -Ids @(100,101,102,103,109,110,200,201,202,203) -StartTime $startTime -MaxEvents $MaxEventsPerLog
$userProfileEvents = Get-SafeEventData -Section "LoginDurationIndicators" -LogName "Microsoft-Windows-User Profile Service/Operational" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog
$winlogonEvents = Get-SafeEventData -Section "LoginDurationIndicators" -LogName "Microsoft-Windows-Winlogon/Operational" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog
$groupPolicyEvents = Get-SafeEventData -Section "LoginDurationIndicators" -LogName "Microsoft-Windows-GroupPolicy/Operational" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog

Add-SectionResult -Name "LoginDurationIndicators" -Status "ok" -Data ([ordered]@{
    diagnosticsPerformanceEvents = $diagEvents
    userProfileEvents            = $userProfileEvents
    winlogonEvents               = $winlogonEvents
    groupPolicyEvents            = $groupPolicyEvents
})

Write-SectionHeader -Title "Collecting Device Boot Performance"
$osForBoot = Invoke-Safely -Section "DeviceBootPerformance" -Operation "Get-CimInstance Win32_OperatingSystem" -DefaultValue $null -ScriptBlock {
    Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
}

$bootPerfEvents = Invoke-Safely -Section "DeviceBootPerformance" -Operation "Parse Diagnostics-Performance EventId 100" -DefaultValue @() -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName = "Microsoft-Windows-Diagnostics-Performance/Operational"
        Id      = 100
        StartTime = $startTime
    } -ErrorAction Stop -MaxEvents 20 | ForEach-Object {
        $p = $_.Properties
        [pscustomobject]@{
            TimeCreated            = $_.TimeCreated
            EventId                = $_.Id
            BootTimeMs             = if ($p.Count -gt 5) { $p[5].Value } else { $null }
            MainPathBootTimeMs     = if ($p.Count -gt 6) { $p[6].Value } else { $null }
            BootUserProfileTimeMs  = if ($p.Count -gt 15) { $p[15].Value } else { $null }
            BootExplorerInitTimeMs = if ($p.Count -gt 17) { $p[17].Value } else { $null }
            BootNumStartupApps     = if ($p.Count -gt 18) { $p[18].Value } else { $null }
            BootPostBootTimeMs     = if ($p.Count -gt 19) { $p[19].Value } else { $null }
            IsDegradationEvent     = if ($p.Count -gt 20) { $p[20].Value } else { $null }
        }
    }
}

Add-SectionResult -Name "DeviceBootPerformance" -Status "ok" -Data ([ordered]@{
    lastBootUpTime = if ($osForBoot -and $osForBoot.LastBootUpTime) { $osForBoot.LastBootUpTime.ToUniversalTime().ToString("o") } else { $null }
    diagnosticsPerformanceBootEvents = $bootPerfEvents
})

# =============================
# SECTION: CPU and Memory
# =============================
Write-SectionHeader -Title "Collecting CPU Consumption"
$cpuCounterSamples = Invoke-Safely -Section "CPUConsumption" -Operation "Get-Counter Processor(_Total)" -DefaultValue @() -ScriptBlock {
    (Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 -ErrorAction Stop).CounterSamples |
        Select-Object TimeStamp, CookedValue
}

$topCpuProcesses = Invoke-Safely -Section "CPUConsumption" -Operation "Get-Process top CPU" -DefaultValue @() -ScriptBlock {
    Get-Process -ErrorAction Stop |
        Sort-Object CPU -Descending |
        Select-Object -First $TopProcesses | ForEach-Object {
            [pscustomobject]@{
                Name      = $_.Name
                Id        = $_.Id
                CPU       = Get-ProcessSafe -Process $_ -Field CPU
                WS        = Get-ProcessSafe -Process $_ -Field WS
                PM        = Get-ProcessSafe -Process $_ -Field PM
                VM        = Get-ProcessSafe -Process $_ -Field VM
                StartTime = Get-ProcessSafe -Process $_ -Field StartTime
            }
        }
}

Add-SectionResult -Name "CPUConsumption" -Status "ok" -Data ([ordered]@{
    processorSamples = $cpuCounterSamples
    topProcesses     = $topCpuProcesses
})

Write-SectionHeader -Title "Collecting Memory Consumption"
$memorySummary = Invoke-Safely -Section "MemoryConsumption" -Operation "Get-CimInstance Win32_OperatingSystem memory" -DefaultValue $null -ScriptBlock {
    $osMem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    [pscustomobject]@{
        TotalVisibleMemoryKB  = [int64]$osMem.TotalVisibleMemorySize
        FreePhysicalMemoryKB  = [int64]$osMem.FreePhysicalMemory
        TotalVirtualMemoryKB  = [int64]$osMem.TotalVirtualMemorySize
        FreeVirtualMemoryKB   = [int64]$osMem.FreeVirtualMemory
        InUsePhysicalMemoryKB = [int64]$osMem.TotalVisibleMemorySize - [int64]$osMem.FreePhysicalMemory
    }
}

$topMemoryProcesses = Invoke-Safely -Section "MemoryConsumption" -Operation "Get-Process top memory" -DefaultValue @() -ScriptBlock {
    Get-Process -ErrorAction Stop |
        Sort-Object WS -Descending |
        Select-Object -First $TopProcesses | ForEach-Object {
            [pscustomobject]@{
                Name      = $_.Name
                Id        = $_.Id
                WS        = Get-ProcessSafe -Process $_ -Field WS
                PM        = Get-ProcessSafe -Process $_ -Field PM
                VM        = Get-ProcessSafe -Process $_ -Field VM
                CPU       = Get-ProcessSafe -Process $_ -Field CPU
                StartTime = Get-ProcessSafe -Process $_ -Field StartTime
            }
        }
}

Add-SectionResult -Name "MemoryConsumption" -Status "ok" -Data ([ordered]@{
    memorySummary = $memorySummary
    topProcesses  = $topMemoryProcesses
})

# =============================
# SECTION: Event Viewer Logon/Performance and Deployment Activity
# =============================
Write-SectionHeader -Title "Collecting Event Viewer Logon/Performance Entries"
$systemLogonEvents = Get-SafeEventData -Section "EventViewerLogonPerformance" -LogName "System" -Ids @(6005,6006,6008,7000,7001,7009,7011,7022,7031,7034) -StartTime $startTime -MaxEvents $MaxEventsPerLog
$applicationPerfEvents = Get-SafeEventData -Section "EventViewerLogonPerformance" -LogName "Application" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog |
    Where-Object { $_.Message -match "logon|login|profile|slow|performance|hang|timeout" }

$securityLogonEvents = Get-SafeEventData -Section "EventViewerLogonPerformance" -LogName "Security" -Ids @(4624,4625) -StartTime $startTime -MaxEvents $MaxEventsPerLog

Add-SectionResult -Name "EventViewerLogonPerformance" -Status "ok" -Data ([ordered]@{
    systemEvents      = $systemLogonEvents
    applicationEvents = $applicationPerfEvents
    securityLogonEvents = $securityLogonEvents
})

Write-SectionHeader -Title "Collecting Intune Management Extension Activity"
$imeLogRoot = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$imeLogData = @()
$imeKeywordPattern = "error|fail|retry|win32|install|remediation|policy|timeout|restart"

$imeFiles = Invoke-Safely -Section "IntuneManagementExtension" -Operation "Enumerate IME logs" -DefaultValue @() -ScriptBlock {
    if (Test-Path -Path $imeLogRoot) {
        Get-ChildItem -Path $imeLogRoot -File -ErrorAction Stop |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 10
    }
    else {
        throw [System.IO.DirectoryNotFoundException]::new($imeLogRoot)
    }
}

foreach ($file in $imeFiles) {
    $tail = Invoke-Safely -Section "IntuneManagementExtension" -Operation "Read log tail $($file.FullName)" -DefaultValue @() -ScriptBlock {
        Get-Content -Path $file.FullName -Tail 150 -ErrorAction Stop
    }

    $filteredTail = @($tail | Where-Object { $_ -match $imeKeywordPattern })

    $imeLogData += [pscustomobject]@{
        Name            = $file.Name
        FullName        = $file.FullName
        LastWriteTime   = $file.LastWriteTime
        LengthBytes     = $file.Length
        TailLineCount   = @($tail).Count
        MatchedLineCount= @($filteredTail).Count
        MatchedTail     = $filteredTail
    }
}

$win32StateRoot = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps"
$win32State = Invoke-Safely -Section "IntuneManagementExtension" -Operation "Read Win32 app state registry" -DefaultValue @() -ScriptBlock {
    if (Test-Path -Path $win32StateRoot) {
        Get-ChildItem -Path $win32StateRoot -Recurse -ErrorAction Stop |
            Where-Object { $_.PSChildName -match "[0-9a-fA-F]{8}-" } |
            Select-Object PSPath, PSChildName, Name
    }
    else {
        @()
    }
}

Add-SectionResult -Name "IntuneManagementExtensionActivity" -Status "ok" -Data ([ordered]@{
    imeLogs = $imeLogData
    win32StateRegistryNodes = $win32State
})

Write-SectionHeader -Title "Collecting Application Deployment Activity"
$dmeAdminEvents = Get-SafeEventData -Section "ApplicationDeploymentActivity" -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog
$dmeOperationalEvents = Get-SafeEventData -Section "ApplicationDeploymentActivity" -LogName "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog
$appxEvents = Get-SafeEventData -Section "ApplicationDeploymentActivity" -LogName "Microsoft-Windows-AppXDeploymentServer/Operational" -Ids @() -StartTime $startTime -MaxEvents $MaxEventsPerLog

$deploymentPattern = "install|deployment|win32|intune|error|failed|retry|remediation|policy|detection|requirement"
$filteredAdmin = @($dmeAdminEvents | Where-Object { $_.Message -match $deploymentPattern })
$filteredOperational = @($dmeOperationalEvents | Where-Object { $_.Message -match $deploymentPattern })
$filteredAppx = @($appxEvents | Where-Object { $_.Message -match $deploymentPattern })

Add-SectionResult -Name "ApplicationDeploymentActivity" -Status "ok" -Data ([ordered]@{
    dmeAdminFiltered       = $filteredAdmin
    dmeOperationalFiltered = $filteredOperational
    appxDeploymentFiltered = $filteredAppx
})

# =============================
# SECTION: Summary Metrics for Cross-Device Comparison
# =============================
Write-SectionHeader -Title "Building Summary Metrics"
$loginFailureCount = @($securityLogonEvents | Where-Object { $_.Id -eq 4625 }).Count
$loginSuccessCount = @($securityLogonEvents | Where-Object { $_.Id -eq 4624 }).Count
$bootEvents = @($bootPerfEvents)
$latestBoot = $bootEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1
$topCpu = @($topCpuProcesses | Select-Object -First 5)
$topMem = @($topMemoryProcesses | Select-Object -First 5)

$summaryMetrics = [ordered]@{
    lookedBackHours               = $LookbackHours
    affectedAppHint               = $AppNameHint
    installedAppCount             = @($allApps).Count
    recentInstallCount            = @($recentApps).Count
    startupCommandCount           = @($startupCommands).Count
    startupFolderItemCount        = @($startupFolderItems).Count
    scheduledTaskCount            = @($scheduledTasks).Count
    scheduledTaskHintMatchCount   = @($scheduledTaskCandidates).Count
    serviceCount                  = @($serviceInventory).Count
    serviceHintMatchCount         = @($serviceCandidates).Count
    imeLogFileCount               = @($imeLogData).Count
    imeMatchedLineCount           = (@($imeLogData | Measure-Object -Property MatchedLineCount -Sum).Sum)
    dmeAdminEventCount            = @($filteredAdmin).Count
    dmeOperationalEventCount      = @($filteredOperational).Count
    appxDeploymentEventCount      = @($filteredAppx).Count
    loginFailureEvent4625Count    = $loginFailureCount
    loginSuccessEvent4624Count    = $loginSuccessCount
    latestBootTimeMs              = if ($latestBoot) { $latestBoot.BootTimeMs } else { $null }
    latestBootPostBootTimeMs      = if ($latestBoot) { $latestBoot.BootPostBootTimeMs } else { $null }
    topCpuProcesses               = $topCpu
    topMemoryProcesses            = $topMem
}

Add-SectionResult -Name "SummaryMetrics" -Status "ok" -Data $summaryMetrics

# =============================
# SECTION: Final Output
# =============================
Write-SectionHeader -Title "Writing JSON Output"
$outputDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$result = [ordered]@{
    metadata = [ordered]@{
        scriptName       = "10-Collect-LoginPerformanceEvidence-Improved.ps1"
        scriptVersion    = "1.1"
        generatedAtUtc   = (Get-Date).ToUniversalTime().ToString("o")
        generatedAtLocal = (Get-Date).ToString("o")
        dryRun           = $false
        lookbackHours    = $LookbackHours
        topProcesses     = $TopProcesses
        maxEventsPerLog  = $MaxEventsPerLog
        appNameHint      = $AppNameHint
        hostname         = $env:COMPUTERNAME
        user             = "$env:USERDOMAIN\$env:USERNAME"
    }
    summary  = $summaryMetrics
    sections = $script:Sections
    errors   = $script:CollectorErrors
    notes    = @(
        "Evidence collection only. No remediation or configuration changes performed.",
        "Access-denied and missing-log conditions are captured in the errors section.",
        "Section structure and summary metrics are normalized for cross-device comparison."
    )
}

Invoke-Safely -Section "FinalOutput" -Operation "Write JSON output" -DefaultValue $null -ScriptBlock {
    $result | ConvertTo-Json -Depth 12 | Set-Content -Path $OutputPath -Encoding UTF8 -ErrorAction Stop
}

Write-Host "Evidence JSON written to: $OutputPath" -ForegroundColor Green
Write-Host "Collection complete. Error count: $($script:CollectorErrors.Count)" -ForegroundColor Yellow
