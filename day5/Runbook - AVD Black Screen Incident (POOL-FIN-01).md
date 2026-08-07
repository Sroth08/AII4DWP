# Runbook: AVD Black Screen After Login (POOL-FIN-01)

| Field | Value |
|---|---|
| Title | Runbook: AVD Black Screen After Login (POOL-FIN-01) |
| Version | 1.0 |
| Date | 07/08/2026 |
| Author | Sourav Roth |
| Reviewed | Self |
| Status | Draft |
| Change | Initial version from RCA |

## Purpose
Restore stable AVD sessions on POOL-FIN-01 when users report a black screen after login following an image/driver update, by rolling back the pool to the last known-good image.

## Applies To
- Host pool: POOL-FIN-01 (Azure Virtual Desktop)
- Symptom: Black screen after login — clears after ~30 seconds for some users, persists for others
- Trigger condition: An image/driver update was deployed to the pool within the last 24 hours

## Source Incident
Based on RCA: [RCA - AVD Black Screen Incident (POOL-FIN-01).md](../day4/RCA%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md) — root cause was a graphics driver regression (`igdumd64.dll` v31.0.101.4146) introduced by an overnight image update, causing `dwm.exe` to crash on session load.

---

## Prerequisites

**Access rights:**
- Azure RBAC role **Desktop Virtualization Contributor** (or equivalent) on the AVD host pool — **elevated permission, confirm before starting**
- Local admin / session host admin rights on POOL-FIN-01 hosts — **elevated permission, confirm before starting**
- Read access to Event Viewer logs on affected session hosts (Application and Microsoft-Windows-TerminalServices-LocalSessionManager logs)

**Tools:**
- Azure Portal or PowerShell `Az.DesktopVirtualization` module access
- Remote access tool to connect to session hosts (e.g., Azure Bastion, RDP to host, or Run Command in Azure Portal)
- Event Viewer (or equivalent log query tool)
- List of the last known-good image version/build ID for POOL-FIN-01 (obtain from image gallery / golden image repository before starting)

**System information needed:**
- Host pool name: POOL-FIN-01
- List of affected session host names (e.g., SHFIN-01-A)
- Current (faulty) image version and last known-good image version
- Change ticket/incident number for this event

---

## Procedure

1. **Open Event Viewer on the affected host and locate the crash event.** Connect to SHFIN-01-A (RDP or Azure Bastion), open `eventvwr.msc`, expand **Windows Logs > Application**, then click **Filter Current Log** (right pane) and enter `1000` in "Event sources: <blank>, Event IDs: 1000".
   - *Success looks like:* One or more rows appear with Source = "Application Error", the event description names Faulting application `dwm.exe` and Faulting module `igdumd64.dll`, Exception code `0xc0000005`.

2. **Confirm when the host last rebooted.** In the same Event Viewer window, expand **Windows Logs > System**, click **Filter Current Log**, enter Event ID `1`, and set "Event sources" to `Microsoft-Windows-Kernel-General`.
   - *Success looks like:* The most recent Event ID 1 entry's timestamp is within the last 24 hours and lines up with the known image deployment window (e.g., overnight).

3. **Check a control host that did not receive the update.** Repeat step 1 on SHFIN-02-A (or another host confirmed not to be on the new image).
   - *Success looks like:* Filtering **Windows Logs > Application** for Event ID 1000 on this host returns zero results in the incident time window.

4. **Post a "remediation in progress" update in the incident bridge/Teams channel.** Type: "POOL-FIN-01 confirmed cause: driver regression from overnight image update. Draining pool and rolling back to last known-good image. ETA [x]." and send.
   - *Success looks like:* Message appears in the channel with your name and a timestamp.

5. **Open the host pool in Azure Portal and go to Session hosts.** Go to `portal.azure.com` > search bar > type "Azure Virtual Desktop" > select it > left menu **Host pools** > click **POOL-FIN-01** > left menu **Session hosts**.
   - *Success looks like:* A grid loads listing all session hosts in POOL-FIN-01 with columns including Status, Sessions, and Drain mode.

6. **Turn on drain mode for every host in the pool.** In the Session hosts grid, select the checkbox at the left of each row (or the header checkbox to select all), then click **Drain mode** in the top toolbar and confirm. **Elevated permission required: Desktop Virtualization Contributor.**
   - *Success looks like:* The "Drain mode" column for every row now reads **On**.

7. **Send a warning message to logged-in users.** Click the host name of a row showing active sessions > left menu **Sessions** > select the checkbox next to each active session > click **Send message** in the toolbar > enter title "Maintenance" and message "Your session will be logged off in 5 minutes for urgent maintenance. Save your work now." > click **Send**.
   - *Success looks like:* Portal shows a confirmation notification "Message sent" for the selected sessions.

8. **Wait 5 minutes, then log off remaining active sessions.** Return to the same **Sessions** blade, select the checkbox next to each remaining active session, click **Log off** in the toolbar, and confirm. **Elevated permission required: Desktop Virtualization Contributor.**
   - *Success looks like:* The Sessions grid refreshes and shows zero rows with status "Active" for this host pool.

9. **Look up the last known-good image version.** Go to `portal.azure.com` > search bar > "Azure Compute Gallery" > select your gallery > left menu **Image definitions** > select the POOL-FIN-01 image definition > **Image versions** tab > note the version number dated before the 02:00 update (cross-check the date/time column against the change record).
   - *Success looks like:* You have written down one specific version number (e.g., `1.0.42`) confirmed as the pre-incident build.

10. **Remove the faulty VMs from the host pool.** In **Host pools > POOL-FIN-01 > Session hosts**, select the checkbox next to each affected host, click **Remove** in the toolbar, tick **Delete the underlying VM(s)**, and click **Remove** to confirm. **Elevated permission required: Desktop Virtualization Contributor.**
   - *Success looks like:* The removed host rows disappear from the Session hosts grid and their VM resources no longer appear under **Virtual machines** in the portal.

11. **Add replacement session hosts built from the known-good image version.** On the host pool **Overview** page, click **+ Add** > **Virtual machines** tab > under "Image" click **See all images** > select **Azure Compute Gallery images** > choose the image definition and the version number recorded in step 9 > fill in VM size/network/domain-join fields to match the removed hosts > click **Next** through to **Review + create** > click **Create**. **Elevated permission required: Desktop Virtualization Contributor.**
   - *Success looks like:* Azure Portal notification shows "Deployment succeeded" and the new host names appear in **Session hosts** with Status = **Available**.

12. **Confirm each new host booted on the correct image.** Connect to each new host, open `eventvwr.msc` > **Windows Logs > System**, filter Event ID `1` (source `Microsoft-Windows-Kernel-General`) to confirm the boot timestamp matches the redeployment, then check `C:\Windows\System32\DriverStore` (or Device Manager > Display adapters > driver Properties tab) for the `igdumd64.dll` driver version.
    - *Success looks like:* Boot time matches the redeployment time, and the driver version shown is **not** `31.0.101.4146`.

13. **Take the pool out of drain mode.** Go to **Host pools > POOL-FIN-01 > Session hosts**, select the checkbox for every host, click **Drain mode** in the toolbar, and toggle it off.
    - *Success looks like:* The "Drain mode" column for every row now reads **Off**.

14. **Log in with a test account on each rebuilt host.** Launch the AVD client (or Azure Virtual Desktop web client), connect using a designated test account targeted at POOL-FIN-01, and once connected wait 60 seconds while watching the screen.
    - *Success looks like:* The Windows desktop renders fully within a few seconds and remains visible for the full 60 seconds with no black screen or disconnect.

15. **Post the all-clear update.** In the incident channel, type: "POOL-FIN-01 rolled back to image version [x], drain mode removed, test logins successful. Monitoring for recurrence." and send. Also trigger the end-user communication template if one exists for this incident.
    - *Success looks like:* Message sent in the incident channel and (if applicable) the end-user communication shows as sent/delivered.

---

## Verification

Before closing the incident, confirm **all** of the following:

- [ ] Test login on every rebuilt host completes with no black screen (step 14 repeated per host).
- [ ] On each host, `eventvwr.msc` > **Windows Logs > System**, filtered for Event ID `9011` (source `Desktop Window Manager`), shows a fresh entry within 1 minute of the test login, with no Event ID `9009` from that same source in the following 15 minutes.
- [ ] Helpdesk/incident queue shows at least 3 real (non-test) user logins to POOL-FIN-01 completed successfully with no black-screen report, checked 30 minutes after step 13.
- [ ] Re-run the Application log filter from step 1 (Event ID `1000`) on every rebuilt host 2 hours after re-enabling the pool, confirming zero matching rows.
- [ ] Message the change/image owner directly (not just the incident channel) asking them to confirm the faulty image version has been withdrawn from the deployment pipeline, and get an explicit written confirmation reply before closing.

Only close the incident once every checkbox above is confirmed. If any item fails, return to Procedure step 9 and re-verify the correct known-good image version was recorded and used.

---

## Rollback

**Target: every action below must be completed in under 3 minutes.** If a step doesn't visibly resolve within that window, stop and escalate — do not keep retrying.

### Step 0 — Always do this first (stops further harm, ~30 seconds)
Go to `portal.azure.com` > search bar > "Azure Virtual Desktop" > left menu **Host pools** > **POOL-FIN-01** > left menu **Session hosts** > select the header checkbox (selects all hosts) > click **Drain mode** in the toolbar > confirm **On**.
- *Success looks like:* Every row's "Drain mode" column reads **On** within 10 seconds of confirming.
- This one action is safe to run regardless of which failure below has occurred — it guarantees no new user can connect while you handle the rest.

### 1. New VM deployment failed (step 11 shows "Failed" in Notifications)
1. Click the bell/Notifications icon (top-right of portal) > click the failed deployment entry > click **Operation details**. (~20 seconds)
2. Copy the "Status Message" / error code text shown on that page into the incident channel. (~20 seconds)
3. In Teams, open the incident channel, paste the error, and type: `@platform-team POOL-FIN-01 host deployment failed, need assist — pool is in drain mode.` Send. (~30 seconds)
4. Stop. Do not click **Retry** in the portal — leave the pool in drain mode from Step 0 and wait for platform team response.
- Total: under 2 minutes. No further action is yours to take until the platform team responds.

### 2. Known-good image also crashes on test login (step 14 fails)
1. Confirm Step 0 has already been done (Drain mode = On for all hosts). If not, do it now. (~30 seconds)
2. In Teams incident channel, type: `@platform-team Known-good image also faulting on POOL-FIN-01, escalating as P1. Pool is in drain mode.` Send. (~20 seconds)
3. Stop. Do not select or deploy any other image version yourself. This is now a P1 for the platform/image team, not a repeat of this runbook.
- Total: under 1 minute.

### 3. Forced logoff (step 8) triggered a data-loss complaint
1. Reply to the user directly (Teams/phone): "Log back in, then in the affected app go to File > Info > Manage Document/Workbook > Recover Unsaved Documents." (~30 seconds)
2. Type the user's name, app, and file name into the incident notes/ticket. (~30 seconds)
3. Continue the main procedure — do not pause the pool-wide drain/logoff for this. (~0 seconds, no action needed)
- Total: under 1 minute. Do not investigate further yourself; this is a follow-up item, not a blocker.

### 4. Drain mode won't toggle off after rollback (step 13 fails)
1. Connect to the affected host: portal > **Virtual machines** > select the host > **Connect** > **RDP** (or Bastion). **Requires local admin — elevated permission.** (~40 seconds)
2. Open PowerShell as Administrator on the host and run: `Restart-Service RDAgent` (~20 seconds)
3. Return to **Host pools > POOL-FIN-01 > Session hosts** in the portal, select the host, click **Drain mode**, toggle **Off** once. (~30 seconds)
4. If the column still doesn't show **Off** after this one retry, stop and escalate in Teams: `@platform-team POOL-FIN-01 host [name] stuck in drain mode after RDAgent restart.` (~20 seconds)
- Total: under 2 minutes, including the one permitted retry.

### General rule
Any step above that isn't resolved on the **first retry** is an automatic escalation — page/tag the platform/image team lead in the incident channel and keep the pool in drain mode. Never attempt a third action on the same failure yourself.

---

## Notes

- **Root cause reference:** This incident was caused by graphics driver `igdumd64.dll` v31.0.101.4146 shipped in an overnight image update. If the same driver version reappears in a future image build, reject the deployment before it reaches production.
- **Partial symptom variability:** Some users' sessions self-stabilize after 1-2 reconnect/crash cycles (~30 seconds) while others crash-loop indefinitely. Do not assume the issue has "gone away" for the pool just because some users report it clearing — verify every host per the Verification section.
- **Control pool comparison:** If a similar incident occurs, always check a sibling pool (e.g., POOL-FIN-02) that did *not* receive the same update — matching/non-matching symptoms there quickly confirm or rule out the image as the cause.
- **No pilot/canary validation:** At the time of this incident, there was no canary host validation step before pool-wide image deployment. Until that preventive control is implemented, treat every overnight image update to this pool as a risk factor and check Event 1000/9009 on a sample host first thing each morning.
- **Related incidents:** See [Known-error Record - AVD Black Screen Incident (POOL-FIN-01).md](../day4/Known-error%20Record%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md) and [Closure Note - AVD Black Screen Incident (POOL-FIN-01).md](../day4/Closure%20Note%20-%20AVD%20Black%20Screen%20Incident%20(POOL-FIN-01).md) for prior documentation of this same event.
- **Escalation contact:** Platform/image owning team — confirm current on-call contact in the incident management tool before starting if this recurs outside business hours.
