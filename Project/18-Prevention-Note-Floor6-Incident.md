# Prevention Note - Floor 6 Incident

## 1. Control Name
Monday Morning Business Readiness Hold Point

## 2. Purpose
Detect high-impact business disruption (sign-in failure, severe sign-in delay, and major performance degradation) in the first business window after a late-week production change, before full user exposure begins.

## 3. Trigger
Execute automatically at 08:00 on the first business day after any Friday production release to a business floor, department, or equivalent scoped user population.

## 4. Owner
Primary owner: Endpoint Engineering Duty Lead.
Supporting owners: Service Desk Duty Manager and Business IT Relationship Lead for the affected department.

## 5. Procedure
1. Place the released scope into a temporary hold state before first-business-day start.
2. Validate a fixed representative sample from the released scope for three business-critical outcomes:
- Successful sign-in completion.
- Sign-in duration within normal business tolerance.
- Acceptable workstation responsiveness after sign-in.
3. Confirm no concentrated surge of related user-impact calls from that scope during the first check window.
4. If all criteria pass, lift hold and continue normal release state.
5. If any criterion fails, keep hold in place, start incident flow, and apply targeted containment for the affected scope.

## 6. Success Criteria
1. Sample users complete sign-in successfully.
2. Sign-in time is within agreed business tolerance.
3. Post-sign-in performance is acceptable for normal legal work.
4. No concentrated early-morning spike of matching disruption from the released scope.

## 7. Escalation Criteria
1. Any sampled user cannot sign in.
2. Repeated severe sign-in delay appears in the sample.
3. Repeated severe post-sign-in slowdown appears in the sample.
4. Concentrated early-morning disruption reports emerge from the released scope.

## 8. Why This Would Have Caught This Incident
The incident timeline shows a Friday scoped change and Monday morning disruption affecting a notable share of Floor 6 users. Reported impact included sign-in failure, very slow sign-in, and poor performance after sign-in. This control is designed for that exact risk window: first business use after late-week release. A mandatory hold with explicit go or no-go criteria at start of day would likely have detected the same user-impact pattern in a limited sample before broad exposure, enabling containment before the larger workday disruption expanded.

## 9. Prevention Note (Executive-Facing)
To reduce recurrence risk, we recommend implementing a Monday Morning Business Readiness Hold Point for all late-week scoped production changes. This is a specific operating control, not a general improvement request. It requires a short, structured go or no-go check at the start of the first business day before full release continuation. The control checks only business outcomes that matter to users: successful sign-in, normal sign-in speed, and usable performance immediately after sign-in. If those outcomes pass in a representative sample, release proceeds. If any fail, release remains in hold and containment begins immediately for the affected scope. This control directly addresses what occurred in this incident: a Friday change followed by broad Monday morning user disruption in one business area. By forcing an early business-readiness decision point, it would likely have limited the impact to a smaller subset and reduced start-of-day disruption for Legal staff.
