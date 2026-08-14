# Floor 6 Legal Incident Triage

## Scenario
- Time: 09:14 Monday morning
- Source report: IT Operations Slack message
- Location: Floor 6 Legal Department
- User population: 45 users
- Platform: Windows 11
- Management: Intune managed
- Recent change: New document management application deployed Friday afternoon

## Working rule for first 30 minutes
Treat each reported symptom as a separate incident stream unless the intake already supports combining them.

## 1. Incident separation

| Issue | Symptom | Potential business impact | Severity | Could represent a security incident? | May be related to Friday deployment? |
|---|---|---|---|---|---|
| Login failures and slow sign-ins | Some users cannot log in, while others can log in but only after a long delay | Users are either blocked from starting work or significantly delayed | Critical | Possibly, but not proven | Possible, but unproven |
| Copilot matter access concern | One paralegal reports Copilot surfaced a client matter they believe they never had access to | Potential confidentiality or inappropriate data exposure concern | Critical | Yes, potentially | Unknown |
| Missing desktop shortcuts | One user reports vanished desktop shortcuts | Reduced user productivity and possible confusion about application access | Medium | Not by itself | Possible, but unproven |
| Recent application deployment | Friday application rollout is a known recent change | If relevant, it could affect multiple users | High as a correlation point, not as a confirmed cause | Not by itself | Yes as a change event, but causation unproven |

## 2. Urgency ranking

### 1. Copilot matter access concern
Why it deserves this position:
Potential unauthorized exposure of legal matter information is the highest-risk issue in the report.

Risks of delaying investigation:
Possible continued inappropriate access to sensitive matter information and delayed containment if the report is accurate.

What the first check is expected to provide:
Whether the report describes actual exposed content, what content was shown, and whether the matter can be identified and validated.

### 2. Login failures and slow sign-ins
Why it deserves this position:
This is a single start-of-day access issue affecting multiple users, with some fully blocked and others significantly delayed.

Risks of delaying investigation:
More users may become unable to start work promptly, and the affected count may grow as additional users sign in.

What the first check is expected to provide:
Whether the problem appears as a common sign-in pattern across affected users and whether the issue is centered on authentication, sign-in processing, or both.

### 3. Recent application deployment
Why it deserves this position:
It is the only named recent change and must be checked early, but it is still only a correlation point.

Risks of delaying investigation:
If the deployment is involved, affected devices may continue processing or failing in the same state without detection.

What the first check is expected to provide:
Whether affected users share a common deployment or installation pattern that unaffected users do not.

### 4. Missing desktop shortcuts
Why it deserves this position:
It matters, but current impact is lower than possible data exposure and multi-user access disruption.

Risks of delaying investigation:
User productivity impact continues, and a broader profile or shell issue could be missed if the symptom is more widespread than currently reported.

What the first check is expected to provide:
Whether the symptom is isolated to one user or present across multiple users.

## 3. First checks by incident

| Issue | First Check | Why That Check Comes First | Evidence Expected | Escalation Trigger |
|---|---|---|---|---|
| Login failures and slow sign-ins | Check Microsoft Entra ID sign-in records for affected users during the Monday morning incident window, then compare with startup and sign-in performance on an affected device | This checks first for a shared central sign-in pattern before treating the issue as device-local slowness only | Recorded failures, timing pattern, common sign-in behavior, and whether sign-in delay is reproducible on an affected device | Multiple users show the same sign-in failure pattern, the affected count increases, or severe repeatable sign-in delay is present across multiple devices |
| Copilot surfacing an allegedly inaccessible matter | Validate the user, exact prompt, exact output, time, and matter reference | Security-sensitive report must first be confirmed precisely before broader interpretation | User statement, screenshot or example if available, matter reference, timestamp | Confirmed display of matter information the user is not authorized to access |
| Missing desktop shortcuts | Confirm whether the symptom affects one user or multiple users | Establishes whether the issue is isolated or part of a broader configuration problem | Number of affected users and whether the missing items are consistent | Multiple users report the same shortcut loss or a wider profile issue is indicated |
| Recent application deployment | Review deployment assignment and install state for affected and unaffected users/devices | Confirms whether the recent change is even shared by the reported users | Targeting, install completion, failed or pending states | Affected users consistently share abnormal deployment state not seen on unaffected users |

## 4. Triage table

| Priority | Incident | Initial Owner | First Check | Reason | Escalate If |
|---|---|---|---|---|---|
| 1 | Copilot matter access concern | DWP Engineer with Security coordination | Validate exact user report, matter reference, and surfaced content | Potential confidentiality issue requires immediate fact validation | Unauthorized matter exposure is confirmed |
| 2 | Login failures and slow sign-ins | DWP Engineer | Review Microsoft Entra ID sign-in records for affected users, then compare with sign-in performance on an affected device | Multi-user start-of-day access issue with both blocked and delayed users | Common failure pattern appears, scope grows, or severe repeatable sign-in delay is present across multiple devices |
| 3 | Recent application deployment | DWP Engineer / Endpoint Management | Review deployment assignment and installation state | Known recent change that may help explain scope | Affected devices share abnormal deployment status |
| 4 | Missing desktop shortcuts | DWP Engineer | Confirm whether impact is isolated or widespread | Lower current impact unless tied to broader profile changes | Multiple users show the same symptom |

## 5. DWP Engineer 30-minute update

### Facts
- IT Operations reported Monday morning disruption on Floor 6 Legal.
- The report states at least a dozen users are affected out of 45.
- Reported symptoms are not uniform: a combined sign-in access issue affecting multiple users, one Copilot access concern, and one report of missing desktop shortcuts.
- A new document management application was deployed to that floor on Friday afternoon.

### Verified in the first 30-minute triage frame
- The report contains multiple problem streams, but login failures and slow sign-ins can be treated as one start-of-day sign-in issue from intake.
- The Copilot matter-access report has higher risk than the desktop shortcut issue because it may represent unauthorized access to legal matter information.
- The Friday deployment is a valid recent-change checkpoint, but not a confirmed cause.

### Unknown
- Whether the combined sign-in issue is centered on authentication, sign-in processing, or both.
- Whether the Copilot report reflects actual unauthorized access, incorrect matter identification, or a misunderstanding of what was shown.
- Whether the missing desktop shortcuts issue is isolated to one user.
- Whether affected users/devices share the same Friday deployment outcome.

### Next investigative actions
- Validate the Copilot report with exact user details, output, timestamp, and matter reference.
- Check Microsoft Entra ID sign-in activity for affected users and compare with sign-in performance on an affected device.
- Compare deployment and installation state for the Friday application across affected and unaffected devices.
- Confirm whether missing desktop shortcuts affect more than one user.
