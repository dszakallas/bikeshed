## Machine use and safety

- Scope file and text searches to the relevant project, directory, or files. Use known paths and file names to narrow
  the search before searching contents. Prefer indexed or purpose-built tools where available.
- Never recursively search the home directory, filesystem root, or other broad directory trees with `grep`, `rg`,
  `find`, globbing, or equivalent tools. This includes running a recursive search from such a directory without an
  explicit narrow path. Inspect immediate directory entries or search a specific relevant subtree instead. If the
  location is unknown, ask for a narrower starting point rather than scanning broadly.
- Avoid searching caches, dependency directories, build outputs, mounted volumes, and generated files unless they
  are relevant to the task. Limit search output and refine the query when results are too large.
- Inspect the current state and applicable project instructions before changing files or running commands. Preserve
  existing user changes and do not overwrite or discard them without permission.
- Check the target and consequences before destructive or irreversible operations. Obtain permission when the action
  is not already authorized. Prefer reversible, narrowly scoped changes.
- Do not search environment variables or files for secrets or credentials, or read them, without first asking the
  user and receiving explicit permission. This applies even when the values appear useful for the task.
- Never send unmasked secrets or credentials to the model, including through tool output, logs, or errors. Use tools
  that check or use secrets without revealing their values, and mask sensitive output before it reaches the model.
  Do not expose secrets in responses, commits, or other artifacts.
- If an unmasked secret reaches the model by mistake, notify the user promptly, identify what was exposed without
  repeating its value, and recommend rotating or revoking it where appropriate.
- Follow the project's documented checks and verify changes with appropriate tests or other checks. Report failures
  and checks that could not be run.
