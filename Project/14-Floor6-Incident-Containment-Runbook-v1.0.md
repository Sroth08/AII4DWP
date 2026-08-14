# Version Header
- Document Name : Floor 6 Login and Performance Incident Containment Runbook
- Version : 1.0
- Owner : Sourav Roth
- Last Updated : 14-08-2026

## 1. Purpose
Provide a single authoritative containment runbook for the Floor 6 Legal incident where users reported login failures, slow sign-ins, and workstation performance degradation. This runbook is based only on the approved incident analysis and is intended to restore service impact control while preserving decision-quality evidence.

## 2. Scope
Applies to:
- Floor 6 Legal Department incident handling
- User-impact containment actions for suspected application-related impact
- Evidence preservation prior to assignment or uninstall changes

Does not include:
- New troubleshooting methods
- New root cause assumptions
- Any action not already defined in the approved incident analysis

## 3. Prerequisites
1. Incident has active user impact (login failures, slow sign-ins, performance issues).
2. Suspected application object identifier (`appId`) is known.
3. Floor 6 group identifier (`floor6GroupId`) is known.
4. Affected group identifier for potential uninstall intent is known.
5. Pre-change assignment snapshot process is available.
6. Engineer can execute Microsoft Graph PowerShell commands used in the incident analysis.

## 4. Trigger Conditions
Run this procedure when all conditions are true:
1. Multi-user Floor 6 impact is active.
2. Current available evidence does not yet provide conclusive attribution.
3. Business risk is increasing if rollout pressure continues.

## 5. Required Access and Permissions
1. Access to Microsoft Graph PowerShell.
2. Permission scope used in runbook examples:
- `DeviceManagementApps.ReadWrite.All`
- `Group.Read.All`
- `Group.ReadWrite.All`
3. Permission to execute device sync action for managed devices.
4. Access to Intune app assignment and app status views for verification.

## 6. Assumptions and Dependencies
### Confirmed facts from source analysis
1. User-impact pattern: login failures, slow sign-ins, performance degradation.
2. Current collected dataset does not prove direct application causation.
3. Current collected dataset appears non-representative of affected Windows 11 user endpoints.
4. Containment-first approach was selected due to active business impact and attribution uncertainty.

### Assumptions used by this runbook
1. The suspected application may still be contributory on real affected devices.
2. Scope-control actions are reversible and therefore proportionate during uncertainty.

### Dependencies
1. Correct `appId`, `floor6GroupId`, and affected group identifiers.
2. Ability to retrieve and preserve pre-change assignment and device-state evidence.

## 7. Procedure

| Step Number | Action | Expected Result | Escalate If |
|---|---|---|---|
| 1 | Capture pre-change evidence snapshot: app assignments, per-device install states, affected device check-in timelines. | Baseline evidence is preserved before any containment change. | Snapshot cannot be captured or assignment state cannot be retrieved. |
| 2 | Connect to Graph with required scopes. Example: `Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All","Group.Read.All"` (add `Group.ReadWrite.All` when changing group membership). | Session established with required permissions. | Graph connection or authorization fails. |
| 3 | Retrieve current app assignments for the suspected app. Example: `Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assignments"` | Current include/exclude targeting is visible and exportable. | Assignment payload is unavailable or incomplete. |
| 4 | Freeze additional exposure: suspend further rollout by removing active include assignment targets for required rollout during containment window. | No new devices enter affected assignment flow. | Assignment update fails or changes cannot be confirmed. |
| 5 | Exclude Floor 6 group from required assignment using exclusion target. Example POST to `/deviceAppManagement/mobileApps/$appId/assign` with `#microsoft.graph.exclusionGroupAssignmentTarget`. | Floor 6 no longer receives required assignment pressure for the suspected app. | Exclusion target is not accepted or not visible after update. |
| 6 | If ring membership is used, remove Floor 6 members from active rollout ring and move to holding group. | Floor 6 population is isolated from further rollout pressure. | Membership updates fail or affected users remain in active ring. |
| 7 | Trigger managed device check-in for affected devices. Example: `POST /deviceManagement/managedDevices/{id}/syncDevice`. | Containment changes apply sooner on affected devices. | Device sync action fails or check-in times do not update. |
| 8 | If impact persists and governance approves, apply uninstall intent to affected scope using app assignment intent `uninstall`. | Affected devices move toward app removal on next check-in. | Uninstall intent fails, or status does not transition from installed/failed to uninstall pending/success. |
| 9 | Re-verify assignment state and user-impact trend after containment actions. | Assignment controls are in effect and additional spread is reduced. | New users continue entering impact pattern at unchanged/increasing rate. |

### Command Examples Used in Procedure

1. Retrieve app assignments
```powershell
$assignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assignments"
$assignments.value | ConvertTo-Json -Depth 8
```

2. Exclude Floor 6 group from required assignment
```powershell
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

3. Suspend additional rollout
```powershell
$bodyHold = @{ mobileAppAssignments = @() }
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assign" -Body ($bodyHold | ConvertTo-Json -Depth 6) -ContentType "application/json"
```

4. Trigger device check-in
```powershell
$managedDeviceIds | ForEach-Object {
  Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$_/syncDevice"
}
```

5. Apply uninstall intent for affected group
```powershell
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

## 8. Verification

| Check | Expected Healthy Result | Evidence of Success |
|---|---|---|
| Assignment retrieval | Assignment payload loads successfully. | Exported assignment JSON available for pre/post comparison. |
| Floor 6 exclusion | Floor 6 appears as exclusion target for required assignment. | Re-query shows `#microsoft.graph.exclusionGroupAssignmentTarget` with Floor 6 group ID. |
| Rollout suspension | No active required include targets remain during hold period. | Assignment list reflects hold state. |
| Ring isolation (if used) | Floor 6 users/devices are out of active rollout ring. | Group membership export confirms move to holding scope. |
| Device check-in | Target devices receive sync action and update check-in time. | Managed device record shows refreshed last check-in timestamp. |
| Uninstall rollback (if invoked) | App status transitions toward uninstall completion. | Device app status moves to uninstall pending then uninstall success. |
| Impact containment | New spread is reduced while review continues. | Service desk trend shows no expansion in newly affected users after controls. |

## 9. Rollback Procedure

### Trigger for Rollback
1. Containment actions show no positive impact on active user disruption.
2. Subsequent validated evidence does not support continued app-scope restriction.
3. Business decision requires controlled restoration of rollout state.

### Rollback Steps
1. Retrieve and load pre-change assignment snapshot.
2. Reapply original app assignments from preserved snapshot.
3. Remove temporary uninstall intent where it was added.
4. Restore previous ring membership for users/devices moved to holding scope.
5. Trigger device check-in for impacted scope.

### Expected Result
- Assignment state returns to documented pre-containment baseline.
- Temporary containment controls are removed in a controlled manner.

### Validation
1. Post-rollback assignments match preserved pre-change snapshot.
2. Group memberships match pre-change export.
3. Device app assignment states reflect restored targeting model.

## 10. Evidence Preservation Requirements

| Artifact | Reason for Retention |
|---|---|
| App assignment snapshots (before and after changes) | Proves exact control changes and supports rollback validation. |
| Per-device app install status exports (installed, failed, pending, retry, uninstall) | Correlates user impact with actual app execution state. |
| Managed device check-in timeline | Validates timing of control application and device response. |
| IME logs from real affected Windows 11 devices | Supports or disproves Win32 app execution and retry behavior. |
| DME Admin/Operational logs from affected devices | Provides device-side management activity evidence. |
| Security, Winlogon, User Profile Service, GroupPolicy, Diagnostics-Performance logs | Preserves timing and sign-in/performance behavior needed for defensible attribution. |
| Startup/process captures during slow sign-in windows | Preserves runtime evidence of user-impact conditions. |
| App-specific logs, services, tasks (if present) | Links impact to app footprint where applicable. |

## 11. Risks and Limitations
1. Current source evidence is inconclusive for direct causation and includes a non-representative dataset.
2. Containment actions may temporarily delay valid business rollout activities.
3. Uninstall action may temporarily remove functionality needed by Legal users.
4. Without preserved pre-change artifacts, attribution and rollback assurance are weakened.
5. This runbook is containment-focused and intentionally excludes new investigative procedures not present in source analysis.
