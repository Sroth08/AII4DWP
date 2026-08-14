# Copilot Incident Short Summary

## Known facts
A Legal department paralegal reported that Microsoft 365 Copilot surfaced a client matter she says she has never had access to. The environment uses Microsoft 365 Copilot with SharePoint Online and OneDrive, and recent changes include a Windows 11 and Intune migration plus a new document management application deployment on Friday. At this stage, the report is a potential information exposure signal and must be handled as such.

## Assumptions
It is not yet confirmed that unauthorized access occurred, that Copilot retrieved the content from SharePoint or OneDrive, or that the Friday deployment is related. It is also not yet confirmed whether the user truly lacked prior access, whether access was indirectly granted through groups or inheritance, or whether the surfaced result can be tied to a specific underlying source.

## Risks
If the report is accurate, there is potential exposure of confidential legal matter information, possible breach of authorization boundaries, client confidentiality risk, and wider scope if the same access path applies to other users. Premature retesting, permission changes, or log alteration could destroy the evidence needed to determine whether unauthorized disclosure actually occurred.

## Immediate next actions
Preserve evidence first. Capture the reporting user identity, incident time, exact prompt, exact Copilot response, and any screenshot or citation detail; then validate the underlying content source, effective permissions, group memberships, recent permission changes, and Microsoft 365/Purview audit records to determine whether Copilot surfaced content from an unintended authorization path.
