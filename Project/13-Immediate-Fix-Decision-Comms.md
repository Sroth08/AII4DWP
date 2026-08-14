# Floor 6 Immediate Fix and Communication Pack

## SECTION 1 - IMMEDIATE FIX

### 1. Immediate technical action
Take containment-first action now:
1. Freeze additional app exposure to the impacted Floor 6 cohort.
2. Exclude the Floor 6 group from required assignment for the suspected application.
3. Force managed device check-in for affected devices so assignment changes apply quickly.
4. Initiate uninstall assignment only for impacted scope if user impact continues after exclusion.

### 2. Why this action is justified by the evidence
Confirmed from the incident analysis:
- The current collected dataset does not prove direct causation by the Friday app release.
- The dataset is likely non-representative of affected Windows 11 users.
- User impact is active and broad (login failures, slow sign-ins, performance degradation).

Evidence-based conclusion:
- Immediate containment is justified to reduce additional impact while preserving decision quality.

### 3. Operational risk reduced
- Reduces risk of further user disruption while attribution is still uncertain.
- Reduces risk of expanding impact to more users in the same scope.
- Reduces risk of making an irreversible broad rollback before evidence is preserved.

### 4. Evidence to preserve before action
Preserve first:
- App assignment snapshot (before and after change).
- Device-level install state exports (installed, failed, pending, retry, uninstall).
- Affected device check-in timeline.
- Relevant device activity records from real affected Windows 11 devices.
- Startup/process evidence captured during slow sign-in windows.

Reason:
- These artifacts are required to prove or disprove causation and defend incident decisions.

### Operational command examples (Intune and Microsoft Graph)

#### A. Remove devices from affected ring (group-based scope change)
```powershell
Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All","Group.ReadWrite.All"

# Example IDs - replace with real values
$floor6GroupId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
$holdingGroupId = "ffffffff-1111-2222-3333-444444444444"

# Remove Floor 6 members from active rollout ring and place in holding group
Get-MgGroupMember -GroupId $floor6GroupId -All | ForEach-Object {
    $memberId = $_.Id
    Remove-MgGroupMemberByRef -GroupId $floor6GroupId -DirectoryObjectId $memberId
    New-MgGroupMemberByRef -GroupId $holdingGroupId -BodyParameter @{"@odata.id"="https://graph.microsoft.com/v1.0/directoryObjects/$memberId"}
}
```
Purpose:
- Moves users/devices out of active rollout targeting.
Expected outcome:
- New app enforcement no longer applies to those moved members.
Verification:
- Confirm membership changes in both groups.
- Confirm affected members are no longer in active rollout scope.

#### B. Exclude Floor 6 group from required assignment
```powershell
$appId = "11111111-2222-3333-4444-555555555555"
$floor6GroupId = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

# Inspect current assignments
$assignments = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assignments"
$assignments.value | ConvertTo-Json -Depth 8

# Apply exclusion target for Floor 6
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
      }
    }
  )
}
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assign" -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
```
Purpose:
- Stops required install pressure for Floor 6.
Expected outcome:
- Floor 6 is excluded from required assignment.
Verification:
- Re-query assignments and confirm exclusion target exists.

#### C. Suspend additional rollout
```powershell
# Replace required assignment set with no active include targets (containment hold)
$bodyHold = @{ mobileAppAssignments = @() }
Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assign" -Body ($bodyHold | ConvertTo-Json -Depth 6) -ContentType "application/json"
```
Purpose:
- Prevents new devices from entering affected state during containment.
Expected outcome:
- No further assignment expansion.
Verification:
- Assignment list shows no active required include targets.

#### D. Trigger device policy refresh
```powershell
# Example managed device IDs - replace with real values
$managedDeviceIds = @(
  "99999999-8888-7777-6666-555555555555",
  "99999999-8888-7777-6666-555555555556"
)

$managedDeviceIds | ForEach-Object {
  Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$_/syncDevice"
}
```
Purpose:
- Accelerates application of containment changes.
Expected outcome:
- Affected devices check in and receive updated assignment state sooner.
Verification:
- Last check-in time updates.
- App assignment status begins changing on targeted devices.

#### E. Initiate uninstall rollback for affected scope
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
- Removes suspected app impact from the affected group.
Expected outcome:
- Devices move toward uninstall on next check-in.
Verification:
- Device app status transitions to uninstall pending and then uninstall success.

## SECTION 2 - DECISION JUSTIFICATION

### Confirmed facts
- Users reported active disruption: login failures, very slow sign-ins, and degraded performance.
- Current collected dataset does not prove direct app causation.
- Current collected dataset appears non-representative of the affected Windows 11 population.

### Evidence-based conclusions
- Immediate containment is appropriate because user impact is high and ongoing.
- Waiting for perfect attribution before containment increases business disruption.
- Exclusion/suspension/scope control is proportionate because it is reversible and limits blast radius.

### Remaining assumptions and uncertainty
- Assumption: The suspected app could still be contributory on true affected devices.
- Uncertainty: Causal chain remains unproven until evidence is collected from verified affected Windows 11 devices.

### Why waiting creates additional risk
- More users may become impacted while rollout pressure continues.
- Business productivity loss increases with each login cycle.
- Corrective actions become harder if incident scope expands.

### What continues after containment
- Continue targeted evidence collection from verified affected Windows 11 devices.
- Correlate assignment state, install outcomes, and user impact timing.
- Reassess whether uninstall should remain, broaden, or be reversed.

## SECTION 3 - MESSAGE TO FLOOR 6

We know this morning has been difficult for many people on Floor 6. Some people cannot sign in. Others can sign in, but it takes much longer than normal. Some people are also seeing very slow computer performance after sign in.

Our information technology team is actively taking steps to reduce further impact while we continue to review what happened. We are applying controlled changes to the affected group first so we can reduce disruption and keep business work moving as much as possible.

If you are already signed in, please save your work often. If you are still unable to sign in, or if your computer remains very slow, please contact the Service Desk and share your device name and the time you noticed the issue.

Please avoid repeated restart attempts unless we ask you to do so, because that can make it harder for us to stabilize the situation quickly.

We will send another update as soon as we confirm the effect of the current actions.

## SECTION 4 - LEADERSHIP UPDATE

FACTS
Multiple Floor 6 users reported sign-in failures, long sign-in delays, and poor performance during business start of day. The current evidence set does not confirm a single direct cause and does not yet provide a complete view of affected user devices.

CURRENT ACTIONS
The team has moved to immediate containment to limit further user impact while preserving records needed for defensible decisions. Controlled scope changes are underway for the affected group, and focused validation is continuing on confirmed impacted devices.

OPEN QUESTIONS
The primary open question is whether the recent Floor 6 application change is causal or only time-correlated. We are also confirming whether all affected users share the same execution path. Current business risk remains high due to ongoing user disruption, but containment actions are designed to reduce additional spread while evidence quality is improved.

## SECTION 5 - OUTPUT QUALITY CHECK

1. User communication jargon check: Passed. No technical jargon terms were used.
2. Leadership update jargon check: Passed. Business language only; no implementation detail.
3. Resolution time commitment check: Passed. No time promises were made.
4. Speculation separation check: Passed. Facts, conclusions, and uncertainty are clearly separated.
5. Evidence support check: Passed. Recommendations align with the prior incident analysis (containment-first due to active impact and inconclusive attribution).
