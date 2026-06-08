---
description: Run Acme's mandatory security review on the current branch diff
argument-hint: "[base-branch]  (defaults to origin/main)"
allowed-tools: Bash, Read, Grep, Glob, Task
---

Run a security review of the changes on this branch.

1. Compute the diff against `${1:-origin/main}`:
   `git diff --merge-base ${1:-origin/main}`
2. If the diff is empty, say so and stop.
3. Delegate the review to the `security-reviewer` subagent, passing it the diff
   and the list of changed files.
4. Relay the subagent's findings verbatim, then restate the final `VERDICT:` line
   on its own at the very end so it is unmissable.

This command is provided by the `acme-security-review` org plugin and is required
by Acme engineering policy before any production merge.
