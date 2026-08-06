Summary: After Win11 migration, a Finance user's mapped drives (S: and P:) are missing each morning and require manual remapping.
Impact: 1 user affected (to confirm), recurring daily access disruption to Finance file resources, productivity impact.
Known facts: issue started after Win11 migration, mapped drives S: and P: are missing every morning, user can remap manually, logon script exists, script appears unreliable post-upgrade.
Missing info to gather: exact start date after migration (to confirm), whether only this user or multiple Finance users are affected (to confirm), whether drives disappear after reboot/sign-out/first logon specifically (to confirm), script path/permissions and execution context (to confirm), any related Group Policy or logon-script errors in logs (to confirm).
Likely category: post-upgrade logon script or Group Policy drive-mapping processing issue.
First diagnostic step: verify whether the logon script actually executes at morning sign-in by checking user logon script/GPO processing logs and confirming script exit/result for S: and P: mappings.
