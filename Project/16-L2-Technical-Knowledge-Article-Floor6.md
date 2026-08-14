# Version Header
- Document Name: L2 Technical Knowledge Article - Floor 6 Login and Performance Incident
- Version: 1.0
- Audience: L2 Support Engineers, Endpoint Engineers, Intune Administrators, Incident Responders
- Derived From: Floor 6 Login and Performance Incident Containment Runbook v1.0

## 1. Overview
This article defines the L2 containment process for the Floor 6 Legal incident pattern involving login failures, slow sign-ins, and workstation performance degradation. It is containment-focused and intended to control user impact while preserving evidence for attribution and rollback assurance.

## 2. Symptoms
- Multi-user Floor 6 impact is active.
- Users report login failures.
- Users report slow sign-ins.
- Users report workstation performance degradation.

## 3. Root Cause Indicators
Confirmed indicators from source runbook context:
- Available evidence may be inconclusive for direct causation.
- Current dataset may be non-representative of affected Windows 11 user endpoints.
- Containment-first handling is required when business risk is increasing and attribution is not conclusive.

## 4. Required Access
- Microsoft Graph PowerShell access.
- Permission scopes:
  - `DeviceManagementApps.ReadWrite.All`
  - `Group.Read.All`
  - `Group.ReadWrite.All`
- Permission to execute managed device sync action.
- Access to Intune app assignment and app status views.

## 5. Troubleshooting Workflow
Use this workflow exactly as pre-change triage and control validation before remediation changes.

1. Capture pre-change evidence snapshot:
- App assignments
- Per-device install states
- Affected device check-in timelines
Expected result: baseline evidence preserved.
Escalate if: snapshot capture fails or assignment state cannot be retrieved.

2. Connect to Graph with required scopes.
Expected result: session established with required permissions.
Escalate if: Graph connection or authorization fails.

3. Retrieve current app assignments for suspected app.
Expected result: include and exclude targeting is visible and exportable.
Escalate if: assignment payload is unavailable or incomplete.

## 6. Remediation Workflow
Execute containment controls in this order.

1. Freeze additional exposure by suspending further rollout during containment window.
Expected result: no new devices enter affected assignment flow.
Escalate if: assignment update fails or cannot be confirmed.

2. Exclude Floor 6 group from required assignment using exclusion target.
Expected result: Floor 6 no longer receives required assignment pressure for suspected app.
Escalate if: exclusion target not accepted or not visible after update.

3. If ring membership is used, remove Floor 6 members from active rollout ring and move to holding group.
Expected result: Floor 6 population isolated from further rollout pressure.
Escalate if: membership updates fail or affected users remain in active ring.

4. Trigger managed device check-in for affected devices.
Expected result: containment changes apply sooner.
Escalate if: sync action fails or check-in times do not update.

5. If impact persists and governance approves, apply uninstall intent to affected scope.
Expected result: affected devices move toward app removal on next check-in.
Escalate if: uninstall intent fails or status does not transition from installed or failed to uninstall pending or success.

6. Re-verify assignment state and user-impact trend.
Expected result: assignment controls are in effect and additional spread is reduced.
Escalate if: new users continue entering impact pattern at unchanged or increasing rate.

## 7. Verification
- Check: Assignment retrieval
  - Expected healthy result: assignment payload loads successfully.
  - Evidence of success: exported assignment JSON available for pre and post comparison.

- Check: Floor 6 exclusion
  - Expected healthy result: Floor 6 appears as exclusion target for required assignment.
  - Evidence of success: re-query shows `#microsoft.graph.exclusionGroupAssignmentTarget` with Floor 6 group identifier.

- Check: Rollout suspension
  - Expected healthy result: no active required include targets remain during hold period.
  - Evidence of success: assignment list reflects hold state.

- Check: Ring isolation (if used)
  - Expected healthy result: Floor 6 users or devices are out of active rollout ring.
  - Evidence of success: group membership export confirms move to holding scope.

- Check: Device check-in
  - Expected healthy result: target devices receive sync action and update check-in time.
  - Evidence of success: managed device record shows refreshed last check-in timestamp.

- Check: Uninstall rollback (if invoked)
  - Expected healthy result: app status transitions toward uninstall completion.
  - Evidence of success: device app status moves to uninstall pending then uninstall success.

- Check: Impact containment
  - Expected healthy result: new spread is reduced while review continues.
  - Evidence of success: service desk trend shows no expansion in newly affected users after controls.

## 8. Rollback Procedure
Trigger for rollback:
1. Containment actions show no positive impact on active user disruption.
2. Subsequent validated evidence does not support continued app-scope restriction.
3. Business decision requires controlled restoration of rollout state.

Rollback steps:
1. Retrieve and load pre-change assignment snapshot.
2. Reapply original app assignments from preserved snapshot.
3. Remove temporary uninstall intent where added.
4. Restore previous ring membership for users or devices moved to holding scope.
5. Trigger device check-in for impacted scope.

Expected result:
- Assignment state returns to documented pre-containment baseline.
- Temporary containment controls are removed in a controlled manner.

Validation:
1. Post-rollback assignments match preserved pre-change snapshot.
2. Group memberships match pre-change export.
3. Device app assignment states reflect restored targeting model.

## 9. Escalation Criteria
Escalate when any of the following occurs:
1. Pre-change evidence snapshot cannot be captured.
2. Assignment state cannot be retrieved or is incomplete.
3. Graph connection or authorization fails.
4. Assignment update fails or cannot be validated.
5. Exclusion target is not accepted or not visible after update.
6. Ring membership change fails or affected users remain in active ring.
7. Device sync action fails or check-in timestamps do not update.
8. Uninstall intent fails or uninstall status transition does not occur.
9. New user impact continues at unchanged or increasing rate after containment actions.

## 10. Evidence Preservation Requirements
- App assignment snapshots before and after changes:
  - Reason: proves exact control changes and supports rollback validation.
- Per-device app install status exports (installed, failed, pending, retry, uninstall):
  - Reason: correlates user impact with app execution state.
- Managed device check-in timeline:
  - Reason: validates timing of control application and device response.
- IME logs from real affected Windows 11 devices:
  - Reason: supports or disproves Win32 app execution and retry behavior.
- DME Admin and Operational logs from affected devices:
  - Reason: provides device-side management activity evidence.
- Security, Winlogon, User Profile Service, GroupPolicy, Diagnostics-Performance logs:
  - Reason: preserves timing and sign-in/performance behavior for defensible attribution.
- Startup and process captures during slow sign-in windows:
  - Reason: preserves runtime evidence of user-impact conditions.
- App-specific logs, services, tasks (if present):
  - Reason: links impact to app footprint where applicable.

## 11. Related Documentation
- Floor 6 Login and Performance Incident Containment Runbook v1.0

## Traceability Matrix

| L2 Section | Runbook Section Used |
|---|---|
| 1. Overview | 1. Purpose, 2. Scope |
| 2. Symptoms | 4. Trigger Conditions, 6. Confirmed facts |
| 3. Root Cause Indicators | 6. Assumptions and Dependencies, 11. Risks and Limitations |
| 4. Required Access | 5. Required Access and Permissions |
| 5. Troubleshooting Workflow | 7. Procedure (Steps 1-3) |
| 6. Remediation Workflow | 7. Procedure (Steps 4-9) |
| 7. Verification | 8. Verification |
| 8. Rollback Procedure | 9. Rollback Procedure |
| 9. Escalation Criteria | 7. Procedure (Escalate If), 9. Rollback Procedure (Triggers) |
| 10. Evidence Preservation Requirements | 10. Evidence Preservation Requirements |
| 11. Related Documentation | Version Header and document source context |
