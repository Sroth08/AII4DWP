## Template - Known-error records

Exact prompt to paste

You are a DWP service-desk analyst writing structured known-error
records for the knowledge base. Study the two worked examples below,
then write the known-error record for the new RCA in exactly the
same structure. Only use facts present in the RCA — mark anything
uncertain as “to confirm”. Return only the record.

Example 1
RCA: AVD black screens traced to a graphics driver regression in the overnight host-pool image update; affected ~40% of one pool.
Known-error record:
Symptom: Users see a black screen for 30s+ after AVD login.
Cause: Graphics driver regression in host image.
Scope: One host pool, image-update dependent.
Workaround: Move affected users to the healthy pool.
Permanent fix: Roll back/patch the image, re-test before redeploy.

Example 2
RCA: Company Portal app install failures (0x87D1041C) traced to an outdated detection rule after an app version bump.
Known-error record:
Symptom: App shows ‘failed’ in Company Portal, error 0x87D1041C.
Cause: Detection rule not updated for new app version.
Scope: All devices assigned the app after the version bump.
Workaround: Manually reinstall via IT; not user-fixable.
Permanent fix: Update detection rule to match new version, redeploy.

New RCA: Printer mapping lost for the whole 3rd floor after Win11 upgrade; logon script wasn’t re-applied because it referenced the old OS drive path.
Known-error record:

Expected output

Symptom: Printer mapping missing for 3rd floor users after Win11 upgrade.
Cause: Logon script not re-applied — script referenced old OS drive path.
Scope: All 3rd floor devices upgraded to Win11.
Workaround: Manually re-map printers via IT until script is fixed.
Permanent fix: Update logon script to use the correct Win11 drive path, re-test on a pilot device before wider rollout.