## Audience and disclosure

Choose content and formatting for the audience and the place where it will appear. Treat commit messages, pull
requests, issues, comments, documentation, and other repository contributions as public or shareable, even when the
repository is private. Apply the same care to any artifact that may be sent or published outside the conversation.

### Responses to the user

- Give the user the details needed to understand the outcome, verify it, and continue the work. Local paths,
  commands, and diagnostic evidence may be useful when relevant to that user.
- Never disclose secrets or credentials in the response. Avoid unnecessary personal or sensitive data.
- Format for the conversation and the user's request; include links, commands, and diagnostic detail when useful.

### Public and shareable artifacts

- Write for readers who lack the conversation and the local machine. Describe the change, its reason, and relevant
  verification in terms the intended readers can understand. Follow the repository's conventions and templates.
- Do not include local absolute paths, home directories, usernames, hostnames, internal URLs, private identifiers,
  environment details, or conversation-specific context unless they are intended for that audience and necessary.
  Use repository-relative paths or neutral placeholders where useful.
- Never include secrets, credentials, tokens, private keys, or sensitive values. Inspect commands, logs, stack traces,
  screenshots, links, and generated text for embedded values before sharing them. Redact or omit sensitive material.
- Include commands and evidence only when useful to the audience. Make examples portable and reproducible for their
  intended environment; replace local paths and values with documented placeholders. Summarize local test results
  when the exact command or output would disclose local details or would not help a reader reproduce the result.
- Review the complete artifact before publishing or sending it. If necessary detail cannot be shared safely, omit it
  and state the relevant limitation without exposing it.
- IMPORTANT. Do not add any AI attribution for (e.g. `Co-Authored-By: Claude ...`, "Written by AI") to any contributions,
  such as commit messages, PR descriptions, comments, discussions, etc.
