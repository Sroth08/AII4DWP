# Floor 6 Incident Analysis (Evidence-Based)

## SECTION 1 - EVIDENCE SUMMARY

### Confirmed facts
- The collected run output is from host `c261-21-1`, and the OS is `Microsoft Windows Server 2022 Datacenter` (build `20348`), not Windows 11.
- The evidence set contains 10 collector errors, including:
  - Missing Intune Management Extension log folder (`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`).
  - No matching DeviceManagement-Enterprise-Diagnostics-Provider Admin/Operational events.
  - Missing Diagnostics-Performance log.
  - Security log query returned no matching events in the selected window.
  - Installed application registry queries failed on `DisplayName` property lookup.
- Installed applications section returned `itemCount: 0`.
- Startup commands found are `aw-qt`, `SecurityHealth`, and `AzureArcSetup`; none matched the document-management app hint.
- Services matched against app hint returned no matches.
- App deployment activity captured is primarily AppX events, including Microsoft Edge package registration/update activity.
- Recent MSI install evidence shows `Microsoft Azure CLI (64-bit)` installation success.

### Patterns that repeat
- Repeated lack of modern Intune endpoint evidence (IME logs absent, DME deployment logs absent).
- Repeated absence of direct artifacts tied to the suspected Friday document-management deployment.
- Repeated evidence of general platform/background package operations (Edge/AppX), not legal-document app activity.

### Findings that appear correlated
- The absence of Intune/IME artifacts correlates with the device identity and OS profile (server-class endpoint, not a typical Windows 11 Intune-managed user workstation).
- AppX events correlate with Edge servicing behavior, not with a line-of-business document-management rollout.

### Findings likely to be noise for this incident
- Azure CLI MSI install records.
- Generic AppX and Edge package events without any document-management identifiers.
- Service inventory volume by itself without app-specific matches.

### Reasonable conclusions
- The supplied evidence set does not currently demonstrate a causal link between the Friday document-management deployment and the Floor 6 login/performance incident.
- The strongest signal is evidence-source mismatch: the collected host characteristics and missing Intune artifacts indicate this dataset is likely not representative of an affected Floor 6 Windows 11 Intune endpoint.

### Remaining uncertainty
- Whether true affected Floor 6 devices show Win32 app install retries, startup hooks, or IME errors remains unknown from this dataset.
- Whether authentication-side failures (Entra ID/Conditional Access/compliance) are present on the affected users is not proven by this data.

## SECTION 2 - MOST LIKELY CAUSE

### Leading root cause hypothesis
- The current evidence package is from a non-representative endpoint and therefore cannot yet prove the production root cause; no direct artifact in the logs ties the Friday document-management deployment to the reported user impact.

### Confidence level
- High confidence in this conclusion about dataset quality and non-attribution.
- Low confidence in any single production root cause attribution from the provided evidence alone.

### Why this best fits the evidence
- The host is Windows Server 2022, while the incident scope is Windows 11 user endpoints.
- Intune endpoint artifacts expected on managed client devices are absent.
- No app-hint matches in startup/services/scheduled-task candidates.
- Deployment logs do not show relevant Win32 deployment events for the suspected app.

### Alternatives considered and deprioritized
- Faulty document-management deployment: deprioritized in this dataset because there is no direct app identifier, no IME deployment trail, and no DME event support.
- Authentication/Conditional Access failure as primary cause: not supported or disproven here; evidence is insufficient because security and identity telemetry is incomplete for affected users/devices.
- General service outage: not supported by provided evidence.

## SECTION 3 - IMMEDIATE TECHNICAL ACTION

Objective: restore service quickly, preserve evidence, and prevent further potential impact while attribution is completed.

### Step 1 - Freeze additional deployment blast radius
Action:
- Pause new assignments and exclude Floor 6 from the app assignment scope.

Example (Microsoft Graph PowerShell):
```powershell
Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All","Group.Read.All"

# Example IDs - replace with real values
$appId = "11111111-2222-3333-4444-555555555555"
$floor6GroupId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

# Get current mobile app assignments
$assignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assignments"
$assignments.value | ConvertTo-Json -Depth 8
```
Purpose:
- Confirm current assignment state before change.
Expected result:
- You can identify where Floor 6 is targeted.
Verification:
- Assignment payload shows include/exclude targets.

Action (exclude Floor 6):
```powershell
# Build a new assignment target excluding Floor 6 group
$body = @{
  mobileAppAssignments = @(
    @{
      "@odata.type" = "#microsoft.graph.mobileAppAssignment"
      intent = "required"
      target = @{
        "@odata.type" = "#microsoft.graph.exclusionGroupAssignmentTarget"
        groupId = $floor6GroupId
      }
      settings = @{
        "@odata.type" = "#microsoft.graph.win32LobAppAssignmentSettings"
        notifications = "showAll"
        restartSettings = $null
      }
    }
  )
}
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assign" -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
```
Purpose:
- Stop further rollout pressure on the impacted cohort.
Expected result:
- Floor 6 is excluded from new required assignment enforcement.
Verification:
- Re-query assignments and confirm exclusion target present.
Risks:
- May delay legitimate app rollout for Floor 6 until investigation completes.

### Step 2 - Force policy refresh on affected endpoints
Action:
```powershell
# Sync one managed device
$managedDeviceId = "99999999-8888-7777-6666-555555555555"
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId/syncDevice"
```
Purpose:
- Apply changed assignment/exclusion quickly.
Expected result:
- Device checks in and receives updated policy/app intent.
Verification:
- Intune device last check-in time updates and app assignment status changes.
Risks:
- Temporary management traffic spike if done in bulk.

### Step 3 - Initiate uninstall intent if deployment is confirmed harmful
Action:
- Create uninstall assignment to the affected group after preserving evidence.

Example:
```powershell
$affectedGroupId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

$uninstallBody = @{
  mobileAppAssignments = @(
    @{
      "@odata.type" = "#microsoft.graph.mobileAppAssignment"
      intent = "uninstall"
      target = @{
        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
        groupId = $affectedGroupId
      }
      settings = @{
        "@odata.type" = "#microsoft.graph.win32LobAppAssignmentSettings"
        notifications = "showAll"
      }
    }
  )
}
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assign" -Body ($uninstallBody | ConvertTo-Json -Depth 10) -ContentType "application/json"
```
Purpose:
- Remove the suspected problematic app from impacted endpoints.
Expected result:
- Devices move toward uninstall state on next policy cycle.
Verification:
- Intune app install status shows transition from installed/failed to uninstall pending/succeeded.
Risks:
- Potential temporary business-function loss if app is needed for Legal workflows.

### Step 4 - Stop further deployments during containment window
Action:
- Temporarily remove include assignment groups for required deployment.
- Keep a rollback snapshot of assignments before edits.

Purpose:
- Prevent expansion while evidence correlation is completed.
Expected result:
- No new devices begin app install.
Verification:
- Assignment list shows no active required include targets for impacted cohorts.
Risks:
- Planned rollout schedule disruption.

## SECTION 4 - EVIDENCE PRESERVATION

Retain before rollback/uninstall:
- Intune app assignment snapshots (before and after containment changes).
- Intune app install status exports per device (success, failed, pending, retry, uninstall).
- Managed device timeline/check-in records for affected users.
- IME logs (`IntuneManagementExtension.log`, `AgentExecutor.log`, related logs) from real affected Windows 11 devices.
- DME Admin/Operational event logs from affected endpoints.
- Security, Winlogon, User Profile Service, GroupPolicy, and Diagnostics-Performance logs from affected endpoints.
- Process and startup inventories captured during slow sign-in windows.
- Any app-specific logs/services/tasks introduced by the document-management package.

Why these matter:
- They establish exact deployment intent, device execution path, and timing correlation, which is required to prove or disprove causation and defend incident decisions.

## SECTION 5 - MESSAGE TO FLOOR 6

We know many of you on Floor 6 are having trouble this morning, including sign-in failures, very slow logins, and poor device performance after login. We understand how disruptive this is, especially for Legal work, and we are treating it as a high-priority service incident.

Our engineering team is actively isolating the affected device group and applying controlled changes in Intune to prevent further impact while we continue technical validation. We are also preserving system and deployment evidence so we can confirm exactly what happened and avoid repeating the issue.

For now, please do not repeatedly reboot or attempt repeated login retries unless IT asks you to, because that can delay recovery and reduce the quality of diagnostic evidence. If you are already logged in, save work frequently and report any severe slowdown or new login failures to the Service Desk with your device name and time of impact.

We will provide the next update as soon as the containment actions complete and we confirm their effect.

## SECTION 6 - IT LEADERSHIP UPDATE

Known:
- Reported Floor 6 impact remains login failures, slow sign-ins, and performance degradation.
- Current supplied evidence does not show direct linkage to the Friday document-management deployment.
- Evidence quality issue identified: provided dataset appears to be from a non-representative server-class endpoint rather than an affected Windows 11 Intune client.

Action underway:
- Containment plan is to freeze additional app exposure for Floor 6, preserve assignment/device evidence, and run targeted collection from verified affected Windows 11 endpoints.
- Prepared Graph-based actions for exclusion, sync, and conditional uninstall if attribution is confirmed.

Remaining uncertainty:
- Direct causal chain between deployment and user impact remains unproven.
- Identity-side contribution (Entra/Conditional Access/compliance) remains unverified in this dataset.

Current risk assessment:
- Operational risk: High (multi-user productivity disruption).
- Attribution confidence: Low with current dataset; high risk of wrong corrective action if changes proceed without representative evidence.

## SECTION 7 - INCIDENT DECISION RECORD

| Decision | Reason | Evidence Used | Risk Accepted |
|---|---|---|---|
| Treat current dataset as non-attributable for root-cause confirmation | Device profile and telemetry mismatch with incident scope | Host OS is Server 2022; no IME log path; no DME deployment evidence for suspect app | Delay in final RCA while recollecting representative endpoint evidence |
| Initiate containment-first change control | User impact is active and broad; attribution incomplete | Incident reports plus absence of direct app causation proof in supplied logs | Possible temporary interruption of app rollout |
| Preserve pre-change assignment and endpoint evidence | Needed for defensible causation analysis and audit trail | Assignment state, endpoint logs, event timelines | Additional operational overhead during live incident |
| Only execute uninstall at scale if causation indicators appear on affected Windows 11 endpoints | Prevents incorrect rollback based on weak evidence | Current evidence lacks app-specific failure artifacts | Slower restoration if app is ultimately confirmed as cause |
