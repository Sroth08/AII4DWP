# Floor 6 Differential Diagnosis

## Scenario
- Floor 6 Legal Department
- 45 users
- Windows 11
- Intune managed
- Recent Windows 11 migration and Intune enrollment
- New document management application deployed Friday afternoon
- Monday morning reports from at least a dozen users: login failures, extremely slow sign-ins, and general performance degradation
- There is currently no evidence proving the Friday application deployment caused the issue

## Reference point
This differential uses the current sign-in issue framing from the Project triage: login failures and slow sign-ins are treated as one combined start-of-day access and performance issue, while still separating authentication-side causes from device-side causes during validation.

## SECTION 1 – REASONING PROCESS

### Timing correlation versus actual causation
Timing is used to identify plausible change windows, not to prove blame. A Friday deployment, recent Windows 11 migration, Intune enrollment changes, or an unrelated Monday service issue can all sit near the same symptom window, so the correct approach is to test each hypothesis against actual deployment state, sign-in telemetry, and device behavior.

### Why a Friday deployment is suspicious but not yet proven
The deployment is suspicious because it is a recent scoped change applied to the affected floor immediately before the first large cluster of complaints. It is not proven because there is no current evidence that affected users share the same installation outcome, that the application is active during sign-in, or that unaffected users without the same deployment pattern are free of the same symptoms.

### How authentication issues are distinguished from workstation performance issues
Authentication issues tend to produce centralized evidence such as Microsoft Entra ID failures, Conditional Access blocks, or compliance-related access denials. Workstation performance issues tend to appear as long sign-in duration, delayed profile loading, heavy CPU, disk or memory use, startup process contention, or broad device slowness after sign-in even when central authentication succeeds.

### How confirmation bias is avoided
The deployment is kept as a leading candidate, not a conclusion. Confirmation bias is avoided by comparing affected and unaffected devices, testing identity evidence separately from endpoint evidence, and requiring a consistent pattern before tying the incident to a single cause.

## SECTION 2 – RANKED DIFFERENTIAL

### Rank 1
Hypothesis:
Faulty Intune Win32 application deployment

Why it fits the timeline:
A scoped application deployment happened Friday afternoon and the complaints began Monday morning when users returned and devices entered a common sign-in window.

Why it might affect only Floor 6:
The deployment scope may be limited to the Floor 6 Legal population.

Evidence supporting the hypothesis:
- Affected users or devices are in the app assignment scope
- Affected devices show failed, pending, retrying, or partially completed deployment states
- Unaffected users do not share the same abnormal deployment pattern

Evidence that would weaken the hypothesis:
- Affected and unaffected devices both show the same clean install state
- No abnormal deployment states or install failures are present on affected devices

Evidence that would completely rule it out:
- Affected devices were not targeted for the application, or the application was not present on the affected population during the incident window

### Rank 2
Hypothesis:
Startup process introduced by the document management application

Why it fits the timeline:
A new application can add startup agents, services, shell extensions, or repository checks that only become visible during the next large Monday morning sign-in event.

Why it might affect only Floor 6:
Only Floor 6 received the new application.

Evidence supporting the hypothesis:
- The application or a related process starts during sign-in or immediately after login on affected devices
- The process correlates with high CPU, disk, or memory use
- Sign-in delay is reproducible where the application is installed

Evidence that would weaken the hypothesis:
- The application is installed but not materially active during the slowdown window
- Another unrelated process is clearly driving the performance issue

Evidence that would completely rule it out:
- The application installs no startup-time component, service, or shell integration relevant to sign-in behavior

### Rank 3
Hypothesis:
Application installation failure or repair loop

Why it fits the timeline:
A failed install or repeated repair cycle can surface most clearly when users return, sign in, and the application attempts remediation or dependency checks.

Why it might affect only Floor 6:
Only the targeted Floor 6 deployment group would share the same install or repair behavior.

Evidence supporting the hypothesis:
- IME or local install logs show repeated retries, failures, or repair attempts
- Affected devices show recurring installer activity around sign-in
- Users with symptoms share the same error code or install state

Evidence that would weaken the hypothesis:
- Installation completed cleanly once with no recurring activity
- Affected devices show no retry or repair behavior

Evidence that would completely rule it out:
- Deployment and local logs confirm stable installation with no repeated install, repair, or retry cycle on affected devices

### Rank 4
Hypothesis:
Configuration profile deployed with the application

Why it fits the timeline:
A configuration profile, remediation, script, or settings payload deployed alongside the app could alter startup behavior, mapped resources, services, or login processing.

Why it might affect only Floor 6:
The same assignment scope may have been used for both the app and an accompanying configuration.

Evidence supporting the hypothesis:
- A new profile, remediation, or script was assigned with the app rollout
- Affected devices share the same recent policy application state
- The timing of policy application aligns with the first failures

Evidence that would weaken the hypothesis:
- No relevant policy or script changes were deployed with the app
- Affected devices do not share common policy results

Evidence that would completely rule it out:
- Review confirms no relevant configuration profile, script, remediation, or settings payload was delivered with or near the application rollout

### Rank 5
Hypothesis:
Windows 11 migration side effects

Why it fits the timeline:
Recent migration and Intune enrollment can leave residual profile, policy, driver, or performance issues that become visible across a user cohort after cutover.

Why it might affect only Floor 6:
Floor 6 may share the same migration wave, hardware baseline, or enrollment timing.

Evidence supporting the hypothesis:
- Affected devices share migration timing or common build state
- Similar slowness or sign-in complaints appeared before or independent of the Friday deployment
- No clean deployment-state correlation appears

Evidence that would weaken the hypothesis:
- Devices from the same migration wave outside Floor 6 are healthy
- Symptoms align much more strongly to the Friday deployment state than to migration status

Evidence that would completely rule it out:
- Affected devices show no common migration-related characteristic and no relevant post-migration issues are present

### Rank 6
Hypothesis:
Device compliance evaluation delays

Why it fits the timeline:
Recent Intune enrollment can produce compliance recalculation or delayed state transitions that affect sign-in or access behavior.

Why it might affect only Floor 6:
The affected devices may share the same recent enrollment or compliance-evaluation window.

Evidence supporting the hypothesis:
- Affected devices show stale, pending, or recently changing compliance states
- Sign-in problems correlate with compliance-dependent access decisions
- Slow sign-ins align with device management processing windows

Evidence that would weaken the hypothesis:
- Compliance is healthy and stable across affected devices
- Access failures occur without any compliance relevance

Evidence that would completely rule it out:
- Compliance state played no role in the affected sign-ins and no delay or denial ties back to device evaluation

### Rank 7
Hypothesis:
Entra ID authentication issues

Why it fits the timeline:
A central authentication issue can cause many users to fail sign-in within the same window and may be reported together with slow access complaints.

Why it might affect only Floor 6:
This is a weaker fit for a floor-limited issue, but Floor 6 may simply be the first or loudest reporting group.

Evidence supporting the hypothesis:
- Affected users show failed or abnormal Microsoft Entra ID sign-in results during the incident window
- The same error pattern appears across multiple users

Evidence that would weaken the hypothesis:
- Microsoft Entra ID sign-ins are normal for affected users while local devices remain slow

Evidence that would completely rule it out:
- No identity-side failures, delays, or abnormal patterns exist for affected users during the reported timeframe

### Rank 8
Hypothesis:
Conditional Access misconfiguration

Why it fits the timeline:
A Conditional Access dependency on compliance, device state, or sign-in conditions can produce login failures that appear suddenly after migration or policy change.

Why it might affect only Floor 6:
The relevant users or devices may be in a shared policy scope.

Evidence supporting the hypothesis:
- Affected users share the same Conditional Access failure or block result
- The same policy applies to the Floor 6 cohort

Evidence that would weaken the hypothesis:
- Users authenticate successfully and are not blocked by access policy

Evidence that would completely rule it out:
- Conditional Access evaluation is normal and unrelated to the affected sign-ins

### Rank 9
Hypothesis:
Network dependency introduced by the application

Why it fits the timeline:
A new application may require repository access, authentication to a remote service, or network-based initialization that slows sign-in and post-login performance.

Why it might affect only Floor 6:
Only the devices with the new application would have that dependency.

Evidence supporting the hypothesis:
- The application performs network-dependent activity during sign-in or startup
- Affected devices show stalls while the application waits on remote connectivity or service response
- The slowdown tracks the application's network activity

Evidence that would weaken the hypothesis:
- The application shows no relevant network activity during the affected window
- Network reachability is healthy and unrelated to symptom timing

Evidence that would completely rule it out:
- The application has no startup-time network dependency relevant to sign-in or device performance

### Rank 10
Hypothesis:
Security software conflict

Why it fits the timeline:
A newly deployed application can trigger repeated scanning, blocking, or verification by security tooling, causing slowdown or startup contention.

Why it might affect only Floor 6:
Only the devices with the new software would experience the conflict.

Evidence supporting the hypothesis:
- Security-related processes show heavy activity around sign-in on affected devices
- The application's files or processes are repeatedly scanned, blocked, or delayed

Evidence that would weaken the hypothesis:
- Security tooling behaves normally during the incident window
- No unusual contention appears around the application's files or services

Evidence that would completely rule it out:
- Logs and runtime behavior confirm no interaction between security controls and the application's install or startup path

### Rank 11
Hypothesis:
Windows profile corruption

Why it fits the timeline:
Profile issues after migration can cause long sign-ins, failed logons, and unstable user state.

Why it might affect only Floor 6:
Users on the same migration wave may share a profile-affecting issue.

Evidence supporting the hypothesis:
- Affected devices show user-profile service errors or repeated profile-load problems
- Symptoms center on profile loading rather than shared deployment state

Evidence that would weaken the hypothesis:
- Multiple affected users show no profile-related errors
- The strongest common factor remains the new application rollout rather than profile state

Evidence that would completely rule it out:
- Profile loading is healthy on affected devices and no relevant user-profile errors are present

### Rank 12
Hypothesis:
General service outage unrelated to the deployment

Why it fits the timeline:
A separate tenant-side or infrastructure issue could happen Monday morning and overlap coincidentally with the recent changes.

Why it might affect only Floor 6:
This is the weakest floor-specific fit unless other departments simply have not reported yet.

Evidence supporting the hypothesis:
- Broader service health issues appear in the same period
- Other departments or non-Floor 6 users report comparable sign-in or performance symptoms

Evidence that would weaken the hypothesis:
- The issue remains tightly aligned to the Floor 6 deployment or migration cohort

Evidence that would completely rule it out:
- Tenant services are healthy and unaffected departments show no matching symptoms

## SECTION 3 – FASTEST VALIDATION CHECK

| Hypothesis | Fastest Check | Expected Result if True | Expected Result if False | Estimated Confidence Level |
|---|---|---|---|---|
| Faulty Intune Win32 application deployment | Compare Intune app deployment status for affected versus unaffected devices | Affected devices cluster around failed, pending, retrying, or abnormal deployment states | Affected and unaffected devices show the same clean deployment state | Medium-High |
| Startup process introduced by the document management application | Check process state and resource usage immediately after sign-in on an affected device | The application or related service is active and consuming notable CPU, memory, or disk | The application is absent or not materially active during the slowdown | Medium |
| Application installation failure or repair loop | Review IME and local install logs on an affected device | Repeated install, repair, or retry behavior appears around sign-in | Installation is stable with no repeat activity | Medium |
| Configuration profile deployed with the application | Check recent Intune profile, remediation, and script assignments for the same scope | A related settings payload was newly assigned to Floor 6 | No related profile or script was deployed with the app | Medium |
| Windows 11 migration side effects | Compare affected devices by migration timing and build state | Affected devices cluster by migration wave or common post-migration condition | No migration-related commonality appears | Medium |
| Device compliance evaluation delays | Review compliance status and last check-in for affected devices | Affected devices show stale, pending, or recently changing compliance state | Compliance is healthy and stable | Medium-Low |
| Entra ID authentication issues | Check Microsoft Entra ID sign-in logs for affected users | A common sign-in failure or abnormal pattern appears | Central sign-ins are normal | Medium-Low |
| Conditional Access misconfiguration | Review Conditional Access results for affected sign-ins | A common policy block or requirement appears | Policy results are normal | Medium-Low |
| Network dependency introduced by the application | Check whether the application is making network-dependent calls during sign-in or startup | Delay aligns with the application waiting on remote connectivity or service response | No such dependency or stall appears | Low-Medium |
| Security software conflict | Check endpoint security and process behavior during the slowdown | Security processes repeatedly scan, block, or contend with the app | No notable security-tool interaction appears | Low-Medium |
| Windows profile corruption | Review User Profile Service and related logon events on an affected device | Profile-load errors or profile-specific failures appear | No profile issues are logged | Low-Medium |
| General service outage unrelated to the deployment | Check service health and compare with unaffected departments | Similar problems appear outside Floor 6 or a known outage exists | The issue remains isolated to Floor 6 | Low |

## SECTION 4 – DEPLOYMENT ATTRIBUTION TEST

Evidence required to confirm the Friday deployment as the cause:

### Device groups affected
- Affected users or devices align strongly with the deployment target group
- Unaffected users are not showing the same issue pattern at the same rate

### Successful vs failed installations
- Affected devices share a common abnormal installation result such as failed, pending, retrying, or partially installed state
- Unaffected devices do not show the same abnormal pattern consistently

### Timing correlation
- Device-side timestamps for install, repair, startup, or policy activity align with the Monday morning complaints
- The symptom onset follows the rollout in a way consistent with the application's behavior

### Event logs
- Windows and application logs show install failures, repeated retries, service issues, shell extension problems, or startup delays tied to the deployed application

### Intune deployment status
- Intune reporting shows a common abnormal deployment state across affected devices that is not equally present in unaffected users or departments

### Process behavior after login
- The application or related component starts during or just after sign-in on affected devices
- Its runtime behavior correlates with login delay or degraded workstation performance

### CPU and memory impact
- The application or a dependent process shows measurable resource contention during the affected period on impacted devices

### User experience comparison with unaffected departments
- Departments or user groups without the same deployment do not report comparable symptoms at similar rates
- The incident follows the deployment scope more closely than broader Windows 11 or tenant-wide factors

Evidence that would rule out the Friday deployment as the cause:
- Affected devices were not targeted by the deployment
- Deployment status is clean and stable across affected devices with no abnormal logs or startup behavior
- Unaffected devices with the same deployment state show no symptoms at a comparable rate
- Identity, compliance, migration, or service-health evidence explains the symptoms more strongly than the application state does
- Similar issues are occurring outside the deployment scope at the same time

## SECTION 5 – INVESTIGATION DECISION

### Current leading hypothesis
Faulty Intune Win32 application deployment, including the possibility of install failure, retry behavior, or startup impact introduced by the new document management application.

### Confidence level
Medium.

### Why it is leading
It is the strongest scoped change tied directly to the affected population and it fits both the timing and the floor-specific nature of the incident. It also offers a plausible explanation for the combined symptom set of login disruption, slow sign-ins, and degraded workstation performance.

### What evidence is still missing
- Whether affected users and devices share the same deployment state
- Whether the application starts, retries, or consumes heavy resources during sign-in
- Whether Microsoft Entra ID or Conditional Access shows a common central failure pattern
- Whether unaffected users with the same application state exist
- Whether migration-related or compliance-related conditions explain the symptoms better

### What investigation should occur next
First compare affected and unaffected devices for Intune deployment status, installation outcome, and recent policy activity. In parallel, review Microsoft Entra ID sign-in results for affected users and capture one affected device's startup, sign-in, and process behavior to determine whether the incident is primarily deployment-driven, identity-driven, or a broader post-migration endpoint issue.
