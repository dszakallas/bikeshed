## Coding workflow

- Read the relevant code and nearby examples before editing. Follow the project's conventions and existing patterns,
  and keep changes focused on the task.
- Check the project's dependencies and existing utilities before using a library. Do not assume a dependency is
  available or add one when an existing solution is suitable.
- When fixing a bug, investigate its cause and address it where practical. Avoid unnecessary complexity.
- Preserve changes made by the user or other agents. Do not revert, overwrite, or discard them without permission;
  work around unrelated changes and ask if a conflict prevents the requested work.
- Discover the project's test, lint, and formatting commands from its instructions or configuration. Run the checks
  appropriate to the change, and report failures or checks that could not be run.
- Review the final diff and working tree status. Remove scratch files created for the task, and check that the
  changes contain only the intended work without removing anyone else's changes.
- NEVER run blanket commands such as `git add .` or `git add -A`. Surgically add only the
  files you have intended to change. Review `git status` carefully before staging.
- Do not bypass pre-commit hooks with `git commit --no-verify` without explicitly asking. They are there to ensure
  code quality and consistency.
