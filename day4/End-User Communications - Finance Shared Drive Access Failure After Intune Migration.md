# End-User Communications: Finance Shared Drive Access Failure After Intune Migration

## Audience 1 - Non-Technical Executive

Your access and data were never at risk during this issue. Finance users were temporarily unable to access their shared drives following a recent change to how those drives connect. The cause has been identified and corrected, and shared drive access has been confirmed as working normally again for affected users. No action is required from you at this time.

## Audience 2 - Affected End User Team

Hi team, some Finance users were unable to access their shared drives after a recent change to how drive connections are set up, which caused the drive-mapping process to fail. This has now been fixed, and access to the Finance shared drive has been confirmed as restored with no further issues found. If you experience this issue again, please restart your computer and check drive access, and if it's still not working, contact the IT Service Desk for help. Thanks for your patience!

## Audience 3 - Engineer-to-Engineer Internal Note

**Incident:** Finance shared drive mapping unavailable for all Finance users (DESKTOP-FB* devices, OU=Finance) at start of business hours.

**Root cause:** Drive mapping was migrated from a GPO Logon Script (USER context) to an Intune PowerShell Script (SYSTEM context). The new script executed under the SYSTEM account context, a different context than the previous method, and as a result could not present the user credentials required to reach the Finance UNC path, causing the shared drive mapping script to fail.

**Script execution context:** New drive-mapping script ran under the SYSTEM account rather than the signed-in user's context used by the prior GPO logon script.

**Intune deployment details:** Script executed successfully as an Intune-deployed script (confirming assignment/targeting and delivery were not at fault) but failed at the point of network path access due to the SYSTEM execution context.

**Resolution actions:** Drive mapping configuration was corrected so the script runs using the signed-in user's credentials/context instead of SYSTEM, and the corrected script was redeployed via Intune to affected devices.

**Recovery validation:** Shared drives are now available; verification confirmed users can access the Finance shared drive; no further issues have been detected.

**Preventive measures:** When migrating drive-mapping or similar logon mechanisms between execution contexts (e.g., GPO USER-context scripts to Intune SYSTEM-context scripts), explicitly verify and configure the required run context, and validate UNC/share access under the new script's actual execution context before full rollout.
