# Personal AI Usage Charter (DWP Desktop/Endpoint Engineer)

## Purpose
I use public AI assistants to improve speed and quality for low-risk engineering work while protecting DWP users, systems, and data. This charter defines what I will and will not use public AI for, and how I verify all AI-generated output before any endpoint change.

## Scope
Applies to my daily desktop/endpoint tasks across Windows estates, including troubleshooting, scripting, packaging, policy interpretation, and documentation.

## 1) Appropriate DWP Tasks for Public LLM Help
I may use public AI for work that contains no sensitive operational detail and no personal data. Typical examples:

- Drafting PowerShell or batch script skeletons for common admin actions (for example: service checks, event log filtering, basic file operations).
- Refactoring existing non-sensitive scripts for readability, comments, error handling, and logging structure.
- Producing test ideas and validation checklists for endpoint changes.
- Explaining Microsoft/Windows concepts in plain language (GPO behavior, Intune policy effect, DNS basics, certificate concepts).
- Drafting runbooks, incident timelines, post-incident summaries, and knowledge articles using sanitized inputs.
- Generating command comparisons, troubleshooting decision trees, and rollback plans at a generic level.
- Reviewing non-sensitive code for obvious bugs, edge cases, or maintainability issues.

Rule of thumb: if the prompt can be safely shown on a public forum without risk to DWP users or systems, it is likely suitable.

## 2) Tasks Not Appropriate for Public AI
I will not use public AI for anything that exposes sensitive information or materially increases operational risk. Prohibited uses include:

- Sharing incident data with identifiable users, devices, or locations.
- Sharing endpoint inventory exports, CMDB extracts, ticket dumps, event logs, memory dumps, or screenshots containing internal details.
- Sharing hostnames, internal IP ranges, AD structure, OU paths, domain trust details, VPN/network topology, or security tooling configurations.
- Requesting advice that includes bypassing controls, weakening security baselines, or disabling protective tooling.
- Uploading proprietary DWP documentation, internal playbooks, architecture diagrams, or unpublished policies.
- Using AI outputs directly in production without technical and change-control verification.

If unsure, treat it as not suitable for public AI and use internal approved channels.

## 3) Data Handling Rule (PII and Credentials)
I will never place end-user PII, credentials, secrets, or authentication material into public AI tools.

This includes, at minimum:

- Names, email addresses, phone numbers, NI numbers, payroll identifiers, home addresses, or case details.
- Usernames with context, password strings, MFA codes, recovery codes, API keys, tokens, cookies, certificate private keys, connection strings, and secret files.
- Any log or script snippet containing the above.

Mandatory handling standard:

- Redact before prompting: replace sensitive values with placeholders such as <USER_ID>, <HOST>, <TOKEN>.
- Minimize prompt data: share only the smallest generic snippet required.
- Re-check prompt text before submit ("two-pass check").
- If redaction changes meaning, stop and move to an internal approved AI or manual analysis path.

## 4) Personal Generate-Then-Verify Rule (Scripts and System Changes)
AI can generate; I remain accountable. I will not run or deploy AI-generated changes until verification is complete.

Verification workflow:

- Define intent first: expected outcome, impacted scope, and rollback method.
- Review code line-by-line: commands, parameters, error paths, assumptions, privilege level, and side effects.
- Validate safety: idempotency, logging, timeout behavior, and explicit failure handling.
- Test in safe order: local lab -> pilot group -> controlled production rollout.
- Confirm with evidence: before/after state, exit codes, logs, and user impact checks.
- Keep human approvals: follow DWP change process and peer review where required.
- Document what ran: script version, target group, execution window, and rollback status.

Personal commitment: No copy-paste execution from AI into production endpoints.

## Working Commitment
I use public AI as a drafting and reasoning aid, not as an authority. I protect DWP data, verify every technical output, and maintain auditable engineering judgment for all endpoint changes.
