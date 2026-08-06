1. Restore reliable logon script execution after Win11 migration
Why it is likely: The ticket states the script exists but "seems not to run reliably post-upgrade," directly matching the symptom of drives missing each morning.
Check to confirm: Review logon script execution logs/GPO results for the affected user across several mornings to confirm the script did not run (to confirm).
Action if confirmed: Fix the script's trigger/assignment so it runs on every sign-in, then verify S: and P: persist over multiple mornings.

2. Fix drive-mapping timing/dependency order in Group Policy
Why it is likely: Migrations often shift policy processing order, so mapping may attempt to run before network/auth is ready, causing intermittent failure.
Check to confirm: Check startup/logon event timing to see if mapping attempts occur before network or domain resources are available (to confirm).
Action if confirmed: Adjust policy/script processing to wait for required dependencies, then retest.

3. Correct script path/permissions/execution context post-migration
Why it is likely: Win11 migration can change file paths, security context, or permission scope, causing the script to fail silently for this user.
Check to confirm: Validate the script's location, share/NTFS permissions, and execution context for the Finance user's account (to confirm).
Action if confirmed: Update path/permissions/context, then verify successful mapping at next sign-in.

4. Remove conflicting or duplicate drive-mapping mechanisms
Why it is likely: If multiple mapping methods exist (script, GPO Preferences, legacy tool), one could be overriding or removing the other's mappings.
Check to confirm: Inspect for duplicate/legacy mapping definitions for S: and P: tied to this user or OU (to confirm).
Action if confirmed: Consolidate to a single authoritative mapping method and remove conflicts, then retest.

5. Resolve intermittent network/authentication readiness at sign-in
Why it is likely: Manual remapping later succeeding suggests a possible timing gap where resources aren't reachable at first logon.
Check to confirm: Correlate mapping failures with network/domain authentication readiness timestamps at morning logon (to confirm).
Action if confirmed: Remediate the connectivity/auth delay, then verify mapping success at first sign-in.

6. Expand scope check if other Finance users are also affected
Why it is likely: If this is a broader post-migration policy/config issue rather than user-specific, other users may show the same pattern.
Check to confirm: Confirm whether other Finance users/devices lose S: and P: after the overnight cycle (to confirm).
Action if confirmed: Apply the validated fix organization/OU-wide and monitor for recurrence.
