#requires -Version 5.1
<#!
.SYNOPSIS
Audits startup programs and optionally disables a specific startup entry.

.DESCRIPTION
- Default mode is audit-only and makes no changes.
- Collects startup entries from startup folders and common registry run locations.
- Supports safe disable mode for a specific program name.
- Creates and reuses backups for idempotent operation.
- Supports rollback from backup state.

.NOTES
PowerShell 5.1 compatible.
#>

[CmdletBinding()]
param(
	# Disable mode switch. By default, script runs in audit mode.
	[switch]$Disable,

	# Rollback mode switch. Restores previously disabled entries from backup.
	[switch]$Rollback,

	# Startup program name to target for disable/rollback.
	[string]$ProgramName,

	# Optional location filter used to disambiguate duplicate program names.
	[string]$StartupLocation,

	# Root folder for log, backup, and disabled-item storage.
	[string]$WorkingRoot = "$env:ProgramData\DWPStartupAudit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Section: Initialize run metadata and output paths.
# Creates deterministic folders and a timestamped run log for traceability.
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runDate = Get-Date -Format 'yyyyMMdd'
$runId = "run_$runStamp"

$logRoot = Join-Path -Path $WorkingRoot -ChildPath 'Logs'
$backupRoot = Join-Path -Path $WorkingRoot -ChildPath 'Backups'
$disabledRoot = Join-Path -Path $WorkingRoot -ChildPath 'DisabledStartupItems'
$stateFile = Join-Path -Path $backupRoot -ChildPath 'StartupBackupState.json'

try { New-Item -Path $logRoot -ItemType Directory -Force | Out-Null } catch { throw }
try { New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null } catch { throw }
try { New-Item -Path $disabledRoot -ItemType Directory -Force | Out-Null } catch { throw }

$script:LogFile = Join-Path -Path $logRoot -ChildPath ("StartupAudit_{0}.log" -f $runStamp)

# Section: Logging helper.
# Writes every action to log file and console with severity and timestamp.
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

# Section: Utility helpers.
# Provides stable entry IDs and safe file-name conversion.
function ConvertTo-SafeFileName {
	param([Parameter(Mandatory = $true)][string]$Name)

	$invalid = [System.IO.Path]::GetInvalidFileNameChars()
	$safe = $Name
	foreach ($c in $invalid) {
		$safe = $safe.Replace([string]$c, '_')
	}
	$safe = $safe.Replace('/', '_').Replace('\\', '_').Replace(':', '_')
	return $safe
}

function Get-StableHash {
	param([Parameter(Mandatory = $true)][string]$InputText)

	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		$bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
		$hash = $sha.ComputeHash($bytes)
		return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
	}
	finally {
		$sha.Dispose()
	}
}

function Get-EntryId {
	param([Parameter(Mandatory = $true)][pscustomobject]$Entry)

	$raw = "{0}|{1}|{2}|{3}|{4}" -f $Entry.EntryType, $Entry.UserScope, $Entry.StartupLocation, $Entry.ProgramName, $Entry.SourcePath
	return Get-StableHash -InputText $raw
}

# Section: StartupApproved status helpers.
# Converts StartupApproved binary state into Enabled/Disabled/Unknown.
function Convert-StartupApprovedState {
	param([byte[]]$Data)

	if ($null -eq $Data -or $Data.Count -eq 0) {
		return 'Enabled'
	}

	switch ($Data[0]) {
		2 { return 'Enabled' }
		3 { return 'Disabled' }
		6 { return 'Disabled' }
		7 { return 'Disabled' }
		default { return 'Unknown' }
	}
}

function Get-StartupApprovedStatus {
	param(
		[Parameter(Mandatory = $true)][string]$ApprovedPath,
		[Parameter(Mandatory = $true)][string]$ValueName
	)

	try {
		if (-not (Test-Path -LiteralPath $ApprovedPath)) {
			return 'Enabled'
		}

		$item = Get-ItemProperty -LiteralPath $ApprovedPath -ErrorAction Stop
		$raw = $item.PSObject.Properties[$ValueName]
		if ($null -eq $raw) {
			return 'Enabled'
		}

		return Convert-StartupApprovedState -Data ([byte[]]$raw.Value)
	}
	catch {
		Write-Log -Level 'WARN' -Message "Could not read StartupApproved state at '$ApprovedPath' for '$ValueName': $($_.Exception.Message)"
		return 'Unknown'
	}
}

# Section: Backup state persistence.
# Loads and saves backup metadata used for idempotent disable and rollback.
function Get-BackupState {
	if (-not (Test-Path -LiteralPath $stateFile)) {
		return @()
	}

	try {
		$raw = Get-Content -LiteralPath $stateFile -Raw -ErrorAction Stop
		if ([string]::IsNullOrWhiteSpace($raw)) {
			return @()
		}

		return @(ConvertFrom-Json -InputObject $raw -ErrorAction Stop)
	}
	catch {
		Write-Log -Level 'ERROR' -Message "Failed to load backup state file '$stateFile': $($_.Exception.Message)"
		return @()
	}
}

function Save-BackupState {
	param([Parameter(Mandatory = $true)][object[]]$State)

	try {
		$State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $stateFile -Encoding UTF8
		Write-Log -Message "Backup state saved to '$stateFile'"
	}
	catch {
		Write-Log -Level 'ERROR' -Message "Failed to save backup state file '$stateFile': $($_.Exception.Message)"
		throw
	}
}

# Section: Startup entry collection.
# Collects entries from startup folders and common registry startup locations.
function Get-StartupEntries {
	$entries = New-Object System.Collections.Generic.List[object]

	# Current-user and all-users startup folder locations.
	$startupFolderLocations = @(
		[pscustomobject]@{
			Scope = 'Current User'
			Path = [Environment]::GetFolderPath('Startup')
			ApprovedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
		},
		[pscustomobject]@{
			Scope = 'All Users'
			Path = [Environment]::GetFolderPath('CommonStartup')
			ApprovedPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
		}
	)

	foreach ($location in $startupFolderLocations) {
		try {
			if ([string]::IsNullOrWhiteSpace($location.Path) -or -not (Test-Path -LiteralPath $location.Path)) {
				continue
			}

			$items = Get-ChildItem -LiteralPath $location.Path -File -ErrorAction Stop
			foreach ($item in $items) {
				$status = Get-StartupApprovedStatus -ApprovedPath $location.ApprovedPath -ValueName $item.Name
				$entries.Add([pscustomobject]@{
					ProgramName = $item.BaseName
					StartupLocation = "Startup Folder ($($location.Path))"
					CommandPath = $item.FullName
					Status = $status
					UserScope = $location.Scope
					EntryType = 'StartupFile'
					SourcePath = $item.FullName
					ValueName = $null
					RegistryPath = $null
					ApprovedPath = $location.ApprovedPath
				}) | Out-Null
			}
		}
		catch {
			Write-Log -Level 'WARN' -Message "Failed reading startup folder '$($location.Path)': $($_.Exception.Message)"
		}
	}

	# Common registry startup keys, including current/all-user and policy-based locations.
	$registryLocations = @(
		[pscustomobject]@{ Scope = 'Current User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'Current User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'Current User'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'All Users'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'All Users'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'All Users'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'All Users'; Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' },
		[pscustomobject]@{ Scope = 'All Users'; Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
	)

	foreach ($location in $registryLocations) {
		try {
			if (-not (Test-Path -LiteralPath $location.Path)) {
				continue
			}

			$props = Get-ItemProperty -LiteralPath $location.Path -ErrorAction Stop
			$valueProperties = $props.PSObject.Properties | Where-Object {
				$_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
			}

			foreach ($vp in $valueProperties) {
				$status = Get-StartupApprovedStatus -ApprovedPath $location.Approved -ValueName $vp.Name
				$entries.Add([pscustomobject]@{
					ProgramName = [string]$vp.Name
					StartupLocation = "Registry Run Key ($($location.Path))"
					CommandPath = [string]$vp.Value
					Status = $status
					UserScope = $location.Scope
					EntryType = 'RegistryValue'
					SourcePath = $location.Path
					ValueName = [string]$vp.Name
					RegistryPath = $location.Path
					ApprovedPath = $location.Approved
				}) | Out-Null
			}
		}
		catch {
			Write-Log -Level 'WARN' -Message "Failed reading registry startup key '$($location.Path)': $($_.Exception.Message)"
		}
	}

	# Include script-disabled startup folder files as explicit disabled entries.
	try {
		if (Test-Path -LiteralPath $disabledRoot) {
			$disabledItems = Get-ChildItem -LiteralPath $disabledRoot -Recurse -File -ErrorAction Stop
			foreach ($item in $disabledItems) {
				$entries.Add([pscustomobject]@{
					ProgramName = $item.BaseName
					StartupLocation = "Disabled Store ($disabledRoot)"
					CommandPath = $item.FullName
					Status = 'Disabled'
					UserScope = 'Unknown'
					EntryType = 'StartupFileDisabledStore'
					SourcePath = $item.FullName
					ValueName = $null
					RegistryPath = $null
					ApprovedPath = $null
				}) | Out-Null
			}
		}
	}
	catch {
		Write-Log -Level 'WARN' -Message "Failed reading disabled startup store '$disabledRoot': $($_.Exception.Message)"
	}

	foreach ($e in $entries) {
		$e | Add-Member -NotePropertyName EntryId -NotePropertyValue (Get-EntryId -Entry $e) -Force
	}

	return ,$entries
}

# Section: Verification checklist.
# Clearly flags commands and registry paths that should be reviewed before modifications.
function Show-VerificationChecklist {
	Write-Log -Level 'WARN' -Message 'VERIFY BEFORE EXECUTION: Disable/Rollback modifies startup configuration.'
	Write-Log -Level 'WARN' -Message 'VERIFY COMMANDS: Remove-ItemProperty, Set-ItemProperty, New-Item, New-ItemProperty, Move-Item, Copy-Item.'
	Write-Log -Level 'WARN' -Message 'VERIFY REGISTRY PATHS: HKCU/HKLM Run, RunOnce, Policies\Explorer\Run, Explorer\StartupApproved\Run, Explorer\StartupApproved\StartupFolder.'
	Write-Log -Level 'WARN' -Message 'VERIFY PRIVILEGES: HKLM and Common Startup Folder changes usually require elevation.'
}

# Section: Disable implementation.
# Disables only the explicitly requested startup entry after validation and backup.
function Disable-StartupEntry {
	param(
		[Parameter(Mandatory = $true)][pscustomobject]$Entry,
		[Parameter(Mandatory = $true)][ref]$State,
		[Parameter(Mandatory = $true)][ref]$Summary
	)

	$entryId = $Entry.EntryId
	$existing = $State.Value | Where-Object { $_.EntryId -eq $entryId } | Select-Object -First 1

	if ($Entry.Status -eq 'Disabled') {
		$Summary.Value.TotalSkipped++
		Write-Log -Message "Skip disable for '$($Entry.ProgramName)'; entry is already disabled."
		return
	}

	if ($null -ne $existing -and $existing.DisabledState -eq $true) {
		$Summary.Value.TotalSkipped++
		Write-Log -Message "Skip disable for '$($Entry.ProgramName)'; backup state already marks entry as disabled (idempotent)."
		return
	}

	# Create base backup record once per unique entry.
	if ($null -eq $existing) {
		$existing = [pscustomobject]@{
			EntryId = $entryId
			ProgramName = $Entry.ProgramName
			StartupLocation = $Entry.StartupLocation
			CommandPath = $Entry.CommandPath
			UserScope = $Entry.UserScope
			EntryType = $Entry.EntryType
			SourcePath = $Entry.SourcePath
			ValueName = $Entry.ValueName
			BackupCreatedAt = (Get-Date)
			DisabledState = $false
			DisabledAt = $null
			RestoredAt = $null
			BackupArtifact = $null
			DisabledArtifact = $null
			RunId = $runId
		}
		$State.Value += $existing
	}

	# Disable registry startup values by moving values into a script-owned DisabledValues subkey.
	if ($Entry.EntryType -eq 'RegistryValue') {
		$disabledSubKey = Join-Path -Path $Entry.RegistryPath -ChildPath 'DWPDisabledValues'
		$backupFileName = "{0}_{1}.txt" -f (ConvertTo-SafeFileName -Name $Entry.ProgramName), $Entry.EntryId
		$backupFilePath = Join-Path -Path $backupRoot -ChildPath $backupFileName

		try {
			if (-not (Test-Path -LiteralPath $Entry.RegistryPath)) {
				throw "Registry path does not exist: $($Entry.RegistryPath)"
			}

			# Idempotent backup creation for registry entry metadata.
			if (-not (Test-Path -LiteralPath $backupFilePath)) {
				$backupText = @(
					"ProgramName=$($Entry.ProgramName)",
					"RegistryPath=$($Entry.RegistryPath)",
					"ValueName=$($Entry.ValueName)",
					"CommandPath=$($Entry.CommandPath)",
					"BackupCreatedAt=$(Get-Date -Format s)"
				) -join [Environment]::NewLine
				Set-Content -LiteralPath $backupFilePath -Value $backupText -Encoding UTF8 -ErrorAction Stop
				Write-Log -Message "Backup created: $backupFilePath"
			}
			else {
				Write-Log -Message "Backup already exists (idempotent): $backupFilePath"
			}

			if (-not (Test-Path -LiteralPath $disabledSubKey)) {
				New-Item -Path $disabledSubKey -Force -ErrorAction Stop | Out-Null
			}

			# Only disable if value currently exists in active key.
			$sourceProps = Get-ItemProperty -LiteralPath $Entry.RegistryPath -ErrorAction Stop
			$sourceVal = $sourceProps.PSObject.Properties[$Entry.ValueName]
			if ($null -eq $sourceVal) {
				$disabledProps = $null
				if (Test-Path -LiteralPath $disabledSubKey) {
					$disabledProps = Get-ItemProperty -LiteralPath $disabledSubKey -ErrorAction SilentlyContinue
				}

				if ($null -ne $disabledProps -and $null -ne $disabledProps.PSObject.Properties[$Entry.ValueName]) {
					$Summary.Value.TotalSkipped++
					Write-Log -Message "Skip disable for '$($Entry.ProgramName)'; value already moved to disabled subkey (idempotent)."
					return
				}

				throw "Startup entry value not found at source: $($Entry.RegistryPath) -> $($Entry.ValueName)"
			}

			Set-ItemProperty -LiteralPath $disabledSubKey -Name $Entry.ValueName -Value $Entry.CommandPath -ErrorAction Stop
			Remove-ItemProperty -LiteralPath $Entry.RegistryPath -Name $Entry.ValueName -ErrorAction Stop

			$existing.DisabledState = $true
			$existing.DisabledAt = Get-Date
			$existing.BackupArtifact = $backupFilePath
			$existing.DisabledArtifact = "$disabledSubKey -> $($Entry.ValueName)"

			$Summary.Value.TotalDisabled++
			Write-Log -Message "Disabled registry startup entry '$($Entry.ProgramName)' from '$($Entry.RegistryPath)'"
			return
		}
		catch {
			$Summary.Value.TotalErrors++
			Write-Log -Level 'ERROR' -Message "Failed to disable registry startup entry '$($Entry.ProgramName)': $($_.Exception.Message)"
			return
		}
	}

	# Disable startup folder entries by moving them to script-managed disabled storage.
	if ($Entry.EntryType -eq 'StartupFile') {
		$scopeFolder = ConvertTo-SafeFileName -Name $Entry.UserScope
		$programFolder = ConvertTo-SafeFileName -Name $Entry.ProgramName
		$backupFolder = Join-Path -Path $backupRoot -ChildPath "StartupFiles\$scopeFolder\$programFolder"
		$disabledFolder = Join-Path -Path $disabledRoot -ChildPath "$scopeFolder\$programFolder"
		$backupFilePath = Join-Path -Path $backupFolder -ChildPath (Split-Path -Path $Entry.SourcePath -Leaf)
		$disabledFilePath = Join-Path -Path $disabledFolder -ChildPath (Split-Path -Path $Entry.SourcePath -Leaf)

		try {
			if (-not (Test-Path -LiteralPath $Entry.SourcePath)) {
				if (Test-Path -LiteralPath $disabledFilePath) {
					$Summary.Value.TotalSkipped++
					Write-Log -Message "Skip disable for '$($Entry.ProgramName)'; startup file already in disabled storage (idempotent)."
					return
				}
				throw "Startup file not found: $($Entry.SourcePath)"
			}

			try { New-Item -Path $backupFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null } catch { throw }
			try { New-Item -Path $disabledFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null } catch { throw }

			# Idempotent backup creation for startup folder files.
			if (-not (Test-Path -LiteralPath $backupFilePath)) {
				Copy-Item -LiteralPath $Entry.SourcePath -Destination $backupFilePath -Force -ErrorAction Stop
				Write-Log -Message "Backup created: $backupFilePath"
			}
			else {
				Write-Log -Message "Backup already exists (idempotent): $backupFilePath"
			}

			Move-Item -LiteralPath $Entry.SourcePath -Destination $disabledFilePath -Force -ErrorAction Stop

			$existing.DisabledState = $true
			$existing.DisabledAt = Get-Date
			$existing.BackupArtifact = $backupFilePath
			$existing.DisabledArtifact = $disabledFilePath

			$Summary.Value.TotalDisabled++
			Write-Log -Message "Disabled startup file entry '$($Entry.ProgramName)' by moving to '$disabledFilePath'"
			return
		}
		catch {
			$Summary.Value.TotalErrors++
			Write-Log -Level 'ERROR' -Message "Failed to disable startup file entry '$($Entry.ProgramName)': $($_.Exception.Message)"
			return
		}
	}

	$Summary.Value.TotalSkipped++
	Write-Log -Level 'WARN' -Message "Skip disable for '$($Entry.ProgramName)'; unsupported entry type '$($Entry.EntryType)'."
}

# Section: Rollback implementation.
# Restores startup entries previously disabled by this script using backup state.
function Invoke-Rollback {
	param(
		[Parameter(Mandatory = $true)][ref]$State,
		[Parameter(Mandatory = $true)][ref]$Summary,
		[string]$NameFilter
	)

	$targets = $State.Value | Where-Object { $_.DisabledState -eq $true }
	if (-not [string]::IsNullOrWhiteSpace($NameFilter)) {
		$targets = $targets | Where-Object { $_.ProgramName -ieq $NameFilter }
	}

	if ($null -eq $targets -or @($targets).Count -eq 0) {
		Write-Log -Message 'No disabled entries matched rollback request.'
		return
	}

	foreach ($record in $targets) {
		if ($record.EntryType -eq 'RegistryValue') {
			try {
				$regPath = [string]$record.SourcePath
				$valueName = [string]$record.ValueName
				$disabledSubKey = Join-Path -Path $regPath -ChildPath 'DWPDisabledValues'

				if (-not (Test-Path -LiteralPath $disabledSubKey)) {
					$Summary.Value.TotalSkipped++
					Write-Log -Level 'WARN' -Message "Rollback skip for '$($record.ProgramName)'; disabled subkey not found: $disabledSubKey"
					continue
				}

				$disabledProps = Get-ItemProperty -LiteralPath $disabledSubKey -ErrorAction Stop
				$disabledVal = $disabledProps.PSObject.Properties[$valueName]
				if ($null -eq $disabledVal) {
					$Summary.Value.TotalSkipped++
					Write-Log -Level 'WARN' -Message "Rollback skip for '$($record.ProgramName)'; disabled value not found in subkey."
					continue
				}

				if (-not (Test-Path -LiteralPath $regPath)) {
					New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
				}

				Set-ItemProperty -LiteralPath $regPath -Name $valueName -Value $record.CommandPath -ErrorAction Stop
				Remove-ItemProperty -LiteralPath $disabledSubKey -Name $valueName -ErrorAction Stop

				$record.DisabledState = $false
				$record.RestoredAt = Get-Date
				$Summary.Value.TotalDisabled++
				Write-Log -Message "Rollback restored registry startup entry '$($record.ProgramName)' to '$regPath'"
			}
			catch {
				$Summary.Value.TotalErrors++
				Write-Log -Level 'ERROR' -Message "Rollback failed for registry entry '$($record.ProgramName)': $($_.Exception.Message)"
			}

			continue
		}

		if ($record.EntryType -eq 'StartupFile') {
			try {
				$sourceDisabledFile = [string]$record.DisabledArtifact
				$targetPath = [string]$record.SourcePath
				$targetFolder = Split-Path -Path $targetPath -Parent

				if (-not (Test-Path -LiteralPath $sourceDisabledFile)) {
					$Summary.Value.TotalSkipped++
					Write-Log -Level 'WARN' -Message "Rollback skip for '$($record.ProgramName)'; disabled file not found: $sourceDisabledFile"
					continue
				}

				if (-not (Test-Path -LiteralPath $targetFolder)) {
					New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
				}

				if (Test-Path -LiteralPath $targetPath) {
					$Summary.Value.TotalSkipped++
					Write-Log -Level 'WARN' -Message "Rollback skip for '$($record.ProgramName)'; target already exists: $targetPath"
					continue
				}

				Move-Item -LiteralPath $sourceDisabledFile -Destination $targetPath -Force -ErrorAction Stop
				$record.DisabledState = $false
				$record.RestoredAt = Get-Date
				$Summary.Value.TotalDisabled++
				Write-Log -Message "Rollback restored startup file entry '$($record.ProgramName)' to '$targetPath'"
			}
			catch {
				$Summary.Value.TotalErrors++
				Write-Log -Level 'ERROR' -Message "Rollback failed for startup file entry '$($record.ProgramName)': $($_.Exception.Message)"
			}

			continue
		}

		$Summary.Value.TotalSkipped++
		Write-Log -Level 'WARN' -Message "Rollback skip for '$($record.ProgramName)'; unsupported entry type '$($record.EntryType)'."
	}
}

# Section: Entry selection helper.
# Validates target program name and returns exactly one match for safe disable operations.
function Resolve-DisableTarget {
	param(
		[Parameter(Mandatory = $true)][object[]]$Entries,
		[Parameter(Mandatory = $true)][string]$Name,
		[string]$LocationFilter
	)

	$matches = $Entries | Where-Object { $_.ProgramName -ieq $Name }

	if (-not [string]::IsNullOrWhiteSpace($LocationFilter)) {
		$matches = $matches | Where-Object { $_.StartupLocation -like "*$LocationFilter*" }
	}

	if ($null -eq $matches -or @($matches).Count -eq 0) {
		Write-Log -Level 'ERROR' -Message "No startup entry found for ProgramName='$Name'."
		return $null
	}

	if (@($matches).Count -gt 1) {
		Write-Log -Level 'ERROR' -Message "Multiple startup entries found for ProgramName='$Name'. Provide -StartupLocation to disambiguate."
		$matches | Select-Object ProgramName, StartupLocation, CommandPath, Status, UserScope | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log -Message $_ }
		return $null
	}

	return @($matches)[0]
}

# Section: Script entry point and mode orchestration.
# Runs audit by default, and only modifies state for explicit Disable or Rollback requests.
Write-Log -Message '=================================================='
Write-Log -Message ("Script start. Disable={0}; Rollback={1}; ProgramName={2}; StartupLocation={3}; WorkingRoot={4}" -f $Disable.IsPresent, $Rollback.IsPresent, $ProgramName, $StartupLocation, $WorkingRoot)

$summary = [ordered]@{
	TotalEntriesFound = 0
	TotalDisabled = 0
	TotalSkipped = 0
	TotalErrors = 0
}

if ($Disable -and $Rollback) {
	Write-Log -Level 'ERROR' -Message 'Invalid parameter set: -Disable and -Rollback cannot be used together.'
	$summary.TotalErrors++
}
elseif ($Disable -and [string]::IsNullOrWhiteSpace($ProgramName)) {
	Write-Log -Level 'ERROR' -Message 'ProgramName is required when -Disable is provided.'
	$summary.TotalErrors++
}
else {
	Show-VerificationChecklist

	$entries = @(Get-StartupEntries)
	$summary.TotalEntriesFound = $entries.Count

	Write-Log -Message "Startup entries collected: $($entries.Count)"
	$entries |
		Select-Object ProgramName, StartupLocation, CommandPath, Status, UserScope |
		Sort-Object UserScope, ProgramName |
		Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log -Message $_ }

	$state = @(Get-BackupState)

	if ($Disable) {
		$target = Resolve-DisableTarget -Entries $entries -Name $ProgramName -LocationFilter $StartupLocation
		if ($null -eq $target) {
			$summary.TotalSkipped++
		}
		else {
			Disable-StartupEntry -Entry $target -State ([ref]$state) -Summary ([ref]$summary)
			try {
				Save-BackupState -State $state
			}
			catch {
				$summary.TotalErrors++
			}
		}
	}
	elseif ($Rollback) {
		Invoke-Rollback -State ([ref]$state) -Summary ([ref]$summary) -NameFilter $ProgramName
		try {
			Save-BackupState -State $state
		}
		catch {
			$summary.TotalErrors++
		}
	}
	else {
		Write-Log -Message 'Audit mode complete. No changes were made.'
	}
}

# Section: End-of-run summary.
# Reports required counters for quick run validation.
Write-Log -Message 'Summary:'
foreach ($kv in $summary.GetEnumerator()) {
	Write-Log -Message ("  {0}: {1}" -f $kv.Key, $kv.Value)
}

Write-Log -Message 'Script end.'
Write-Log -Message '=================================================='
