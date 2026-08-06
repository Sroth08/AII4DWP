## Rewrite the prompts

1- Broken Prompt

“write something for the user about their email”

Correct Prompt:

You are a DWP service-desk analyst. A user has reported that Outlook on their managed Windows 11 device is displaying repeated password prompts when accessing their corporate email. Draft a user-facing update explaining the current status, what has been checked so far, and the next steps being taken. Use plain language suitable for a non-technical user. Keep the message professional, concise, and reassuring. Do not invent troubleshooting results. Return only the user communication.

2- Broken Prompt

“you are a helpful assistant who always gives detailed, accurate, professional, well-structured, clear and concise answers. Tell me about Intune.”

Correct Prompt:

You are a DWP service-desk analyst preparing onboarding material for new support agents. Provide a concise overview of Microsoft Intune in a corporate endpoint-management environment. Include the following sections: Purpose; Device Management; Application Management; Compliance Policies; Typical Service Desk Use Cases. Limit the response to 250 words and focus on practical support relevance. Return only the overview.

3- Broken Prompt

“A user says their laptop is slow. What is the problem and fix it.”

Correct Prompt:

You are a DWP service-desk analyst. A user reports that their managed Windows 11 laptop has become noticeably slower over the past three days. Produce a structured triage summary with these sections: Summary; Impact; Known Facts; Additional Information Required; Five Most Likely Causes (ranked by probability); First Diagnostic Step for Each Cause. Do not assume the root cause or provide a guaranteed fix. Mark unknown information as “to confirm”. Return only the triage summary.

4- Broken Prompt

“List every possible reason a Windows 11 device might have any kind of issue connecting to any kind of network resource.”

Correct Prompt:

You are a DWP service-desk analyst. Categorize the most common causes of network-resource connectivity issues on managed Windows 11 devices. Group the causes under these headings: Device Configuration; Network Connectivity; DNS; VPN; Authentication and Access; Firewall and Security Controls; Application-Specific Issues; Infrastructure Issues. For each cause provide a brief description and a single recommended first check. Focus on realistic enterprise support scenarios and avoid exhaustive theoretical possibilities. Return only the categorized list.

5- Broken Prompt

“Rewrite this so it sounds better: ‘Device non-compliant due to BitLocker not enabled. Remediation applied. Compliance restored.’”

Correct Prompt:

You are a DWP service-desk analyst preparing a ticket update. Rewrite the following technical note so it is clear, professional, and suitable for inclusion in a service-management record:

“Device non-compliant due to BitLocker not enabled. Remediation applied. Compliance restored.”

Preserve the original meaning. Return only the rewritten text.

6- Broken Prompt

“You are a senior DWP engineer with 20 years experience. A user cannot log in. Solve this completely and give me the guaranteed fix.”

Correct Prompt:

You are a DWP service-desk analyst. A user reports that they are unable to sign in to their corporate account on a managed Windows 11 device. Produce a structured triage summary with these sections: Summary; User Impact; Known Facts; Missing Information to Gather; Most Likely Cause Categories; Immediate Checks; Escalation Criteria. Do not assume the root cause, do not claim a guaranteed fix, and do not invent facts. Mark any uncertainty as “to confirm”. Return only the triage summary.