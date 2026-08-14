# Copilot Potential Information Exposure Assessment

## Scenario
- Reporting user: Paralegal in the Legal department
- Reported statement: "Copilot pulled up a client matter she swears she has never had access to."
- Environment: Microsoft 365 Copilot enabled
- Platform and services: Microsoft 365 tenant, SharePoint Online, OneDrive
- Recent changes: Windows 11 and Intune migration, new document management application deployed on Friday

## SECTION 1 – WHAT THIS ACTUALLY IS

This is not a normal support ticket. It is a potential information exposure incident involving legal matter data and must be treated first as a security and access-boundary investigation.

### Why it must be treated as a security signal
The user is alleging that Copilot surfaced matter-related information outside her expected access boundary. If accurate, the primary issue is not application behavior or user experience; it is possible unauthorized disclosure of sensitive content.

### Why it cannot be dismissed as AI weirdness
Copilot responses are grounded in tenant data and retrieval paths. Even if the output appears unexpected, the correct first question is whether Copilot retrieved content the user could actually access through existing permissions, search exposure, or connected integrations.

### Why authorization and access boundaries must be investigated first
The highest-risk possibility is that the user was shown content from a site, file, matter workspace, or indexed source that fell outside intended authorization. Before any usability or product explanation is considered, investigators must determine whether the user had effective access, whether inherited or group-based permissions exposed the content, and whether the surfaced content came from an approved data source.

### What business risks exist if the report is accurate
- Exposure of confidential legal matter information
- Potential breach of ethical walls or matter segregation requirements
- Client confidentiality risk and loss of trust
- Regulatory, contractual, and professional conduct exposure
- Potential wider scope if the same access path applies to other Legal users

## SECTION 2 – WHAT I WOULD NOT DO

### Close the ticket as a Copilot hallucination
Risk:
This would dismiss a possible data exposure event without validating the retrieval source, content, or access path. If the report is accurate, early closure loses containment time and delays mandatory investigation.

### Assume user error
Risk:
The user may be mistaken about prior access, but treating the report as user error before evidence review creates bias and can cause a real access-control failure to be missed.

### Assume a permissions problem without evidence
Risk:
Permissions may be involved, but other causes remain possible, including search exposure, integration behavior, group membership changes, or misunderstanding of what content was shown. Prematurely deciding on one cause distorts evidence handling.

### Change permissions immediately
Risk:
Immediate permission changes can destroy the original access state investigators need to reconstruct effective access at the time of the event. It may also mask the real control failure before scope is understood.

### Delete logs or alter evidence
Risk:
This compromises auditability and may prevent confirmation of what content was accessed, by whom, and through which control path. It also undermines security and legal review.

### Re-test with the user's account before preserving evidence
Risk:
Re-testing can alter recent activity trails, search history, audit sequence, and session context before the original event is documented. Evidence preservation must come before reproduction attempts.

## SECTION 3 – DIFFERENTIAL ANALYSIS

Ranked from most likely to least likely for first-stage triage only. This is not root cause analysis.

### 1. SharePoint oversharing
Why it fits:
Microsoft 365 Copilot relies on existing content access. If a file, folder, or site was over-shared, Copilot could surface matter content that was technically accessible but not intended for that user.

Evidence required:
- Effective permissions on the referenced file, library, folder, and site
- Sharing links and link scope
- Whether the user had direct or indirect access at incident time

Evidence that would rule it out:
- Permission review shows the user had no effective access path to the content
- Audit records show the surfaced source was not SharePoint-backed content

### 2. Incorrect site permissions
Why it fits:
Legal matter content is often segmented at site or library level. A site-level mispermission could expose a wide set of matter documents without the user realizing access existed.

Evidence required:
- Site membership and permission levels
- Site visitors, members, owners, and unique permission settings
- Comparison of intended vs actual site access model

Evidence that would rule it out:
- The relevant site has correct restricted access and no user access path exists

### 3. Permission inheritance issues
Why it fits:
A folder, library, or matter workspace may have inherited broader permissions than intended, especially after migration or structural change.

Evidence required:
- Inheritance status at site, library, folder, and file level
- Recent inheritance changes
- Effective permission trace for the reporting user

Evidence that would rule it out:
- The object had unique, correct restrictions at every relevant level
- No inherited path granted the user access

### 4. Microsoft 365 Group membership changes
Why it fits:
Group-based access is common in Microsoft 365. A recent membership change could grant access without the user realizing it.

Evidence required:
- Current and recent group memberships for the user
- Change records for matter-related Microsoft 365 Groups, Entra groups, or SharePoint groups
- Timing correlation with the reported incident

Evidence that would rule it out:
- No relevant membership exists and no recent change granted access

### 5. Document management application integration issues
Why it fits:
A newly deployed application may integrate with SharePoint or matter repositories and could influence how content is surfaced, indexed, or linked. It is only a correlation point at this stage, not a presumed cause.

Evidence required:
- Whether the surfaced content came through a source touched by the new application
- Integration design, connectors, or permission model used by the application
- Deployment scope and any related configuration changes

Evidence that would rule it out:
- The application has no retrieval, indexing, or permission interaction with the surfaced content source
- The affected content path existed independently of the new application

### 6. Copilot retrieval behavior
Why it fits:
Copilot may summarize or retrieve content the user can technically access even when the user does not recognize the source or prior entitlement. This can make an access issue appear like an AI anomaly.

Evidence required:
- Exact prompt and response
- Source citations or referenced artifacts if available
- Confirmation of the underlying source content and access path

Evidence that would rule it out:
- The response cannot be tied to any source the user could access
- Retrieved content is shown to come from a source outside permitted scope

### 7. User misunderstanding of prior access
Why it fits:
The user may genuinely believe they never had access even if access existed through prior team membership, inherited site rights, or shared links.

Evidence required:
- Historical group and site membership
- Prior access history and sharing records
- Confirmation of what specific matter or document the user referred to

Evidence that would rule it out:
- Records show no prior or current access path existed

### 8. Search indexing exposure
Why it fits:
If content became discoverable through indexing or connected experiences in an unexpected way, Copilot might surface it. This still requires an underlying accessible source or exposure path to matter.

Evidence required:
- Search and discovery configuration relevant to the content source
- Whether the content was indexed and discoverable to the user
- Correlation between source indexing state and Copilot result

Evidence that would rule it out:
- The content was not indexed or not discoverable to the user
- Access review shows no underlying permission path

### 9. Broken sensitivity label enforcement
Why it fits:
If sensitivity labels were intended to restrict handling or access and failed to apply as expected, exposure risk increases. This is typically less likely than plain permission oversharing unless label-based controls are known to govern access in this environment.

Evidence required:
- Label applied to the document or container
- Label policy behavior and enforcement state
- Whether label-based controls should have limited access or sharing

Evidence that would rule it out:
- No relevant label governed access to the content
- Label enforcement operated as designed and access was granted elsewhere

## SECTION 4 – EVIDENCE COLLECTION PLAN

Gather evidence in the order below before changing permissions or attempting reproduction.

### User identity
Why it matters:
Confirms the exact reporting user account, which is required for permission tracing, audit review, group membership validation, and session correlation.

### Time of incident
Why it matters:
Provides the time anchor needed to correlate Copilot activity, audit events, permission changes, and group changes.

### Exact Copilot prompt
Why it matters:
Determines what the user asked, whether the prompt referenced the matter directly, and whether the response could have been shaped by wording or context.

### Exact Copilot response
Why it matters:
Shows what content was actually surfaced, whether matter names, summaries, or snippets appeared, and whether any citations or identifiable sources are present.

### SharePoint access permissions
Why it matters:
Validates effective access to the site, library, folder, or file underlying the surfaced matter content.

### Audit logs
Why it matters:
Support event reconstruction, including whether the user accessed the item directly, indirectly, or through a Microsoft 365 service path.

### Purview audit records
Why it matters:
Provide authoritative Microsoft 365 audit evidence for user, file, site, sharing, and access-related activity relevant to the alleged exposure.

### Group memberships
Why it matters:
Confirms whether the user had direct or indirect access through Microsoft 365 Groups, Entra groups, or SharePoint groups.

### Recent permission changes
Why it matters:
Identifies whether access shifted recently because of admin action, inheritance change, sharing link creation, or migration-related repermissioning.

### Sensitivity labels
Why it matters:
Shows whether the content or location carried data protection controls that should have influenced access, sharing, or handling.

### Site access history
Why it matters:
Helps determine whether the user had prior access, whether the claim of never having access is consistent with available records, and whether access history aligns with the reported event.

## SECTION 5 – INCIDENT SEVERITY

### Recommended severity
High, with immediate security review. If initial evidence confirms unauthorized matter exposure, raise to critical according to organizational security and legal incident criteria.

### Potential impact
Exposure of confidential client matter information to a user outside intended access boundaries.

### Potential scope
Currently one reported user and one reported matter, but scope is unknown until access model, source content, and sharing path are validated.

### Legal risk
High. Legal matter segregation, client confidentiality, and professional obligations may be implicated if the report is accurate.

### Regulatory impact
Potentially significant depending on matter content, client obligations, regulated data involved, and reporting requirements.

### Why the incident may need Security and Legal involvement
Security is needed to preserve evidence, validate access controls, and determine whether unauthorized disclosure occurred. Legal leadership may need to assess confidentiality exposure, matter sensitivity, client obligations, and any downstream reporting or containment requirements.

## SECTION 6 – TWO-SENTENCE ESCALATION

### Security Operations
Potential information exposure incident reported within the Legal department. A user states Microsoft Copilot surfaced matter-related information that may fall outside her authorized access; access controls, audit logs, and affected content permissions require immediate investigation to determine scope and confirm whether unauthorized disclosure occurred.

### Legal Leadership
Potential information exposure incident reported within the Legal department. A user states Microsoft Copilot surfaced matter-related information that may fall outside her authorized access; the matter source, effective permissions, and potential confidentiality impact require immediate validation.

### Microsoft 365 Administrators
Potential information exposure incident reported within the Legal department. A user states Microsoft Copilot surfaced matter-related information that may fall outside her authorized access; SharePoint permissions, group membership, audit records, and content access paths require immediate review to determine whether Copilot surfaced data from an unintended authorization path.
