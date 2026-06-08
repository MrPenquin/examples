#!/usr/bin/env bash
# Acme guardrail: deny edits to files that store secrets.
# Reads the PreToolUse hook payload on stdin and inspects the target path.
# Exit 0 = allow. Emitting a JSON "deny" decision blocks the tool call.
set -euo pipefail

payload="$(cat)"

# Pull the target path out of the tool input without requiring jq:
# Write/Edit use .tool_input.file_path; NotebookEdit uses .tool_input.notebook_path.
# Use grep -E (portable across BSD/GNU; BSD sed lacks \| alternation).
path="$(printf '%s' "$payload" \
  | grep -Eo '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -n1 \
  | grep -Eo ': *"[^"]*"$' \
  | sed -E 's/^: *"//; s/"$//')"

# Patterns Acme never allows an agent to write to.
case "$path" in
  *.env|*.env.*|*/.env|*.pem|*.p12|*.pfx|*/secrets/*|*/id_rsa|*/id_ed25519|*credentials*)
    cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Acme policy: agents may not write to secrets files ($path). Store secrets in Acme Vault and reference them at runtime. See acme-security-review plugin."
  }
}
JSON
    exit 0
    ;;
esac

# Allow everything else.
exit 0
