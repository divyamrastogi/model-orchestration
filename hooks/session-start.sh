#!/usr/bin/env bash
# SessionStart hook: makes manager/worker delegation the default behavior by
# injecting the orchestration rules + configured-worker inventory as context.
# Silent (single nudge line) when no workers are configured, to avoid noise.
set -uo pipefail

WORKERS_ROOT="${CLAUDE_WORKERS_ROOT:-$HOME/.claude-workers}"

inventory=""
if [ -d "$WORKERS_ROOT" ]; then
  for d in "$WORKERS_ROOT"/*/; do
    [ -f "$d/settings.json" ] || continue
    grep -q "PASTE_YOUR_API_KEY_HERE" "$d/settings.json" && continue
    name="$(basename "$d")"
    line="$(python3 - "$d/settings.json" "$name" "${d}run" 2>/dev/null <<'PY'
import json, sys
env = json.load(open(sys.argv[1]))["env"]
tiers = []
for flag, var in (("sonnet","ANTHROPIC_DEFAULT_SONNET_MODEL"),
                  ("opus","ANTHROPIC_DEFAULT_OPUS_MODEL"),
                  ("haiku","ANTHROPIC_DEFAULT_HAIKU_MODEL")):
    if var in env:
        tiers.append(f"--model {flag} -> {env[var]}")
tier_s = "; ".join(tiers) if tiers else "provider defaults"
print(f"- {sys.argv[2]}: `{sys.argv[3]} -p \"<task>\"` ({tier_s})")
PY
)"
    [ -n "$line" ] && inventory="${inventory}${line}
"
  done
fi

if [ -z "$inventory" ]; then
  echo "model-orchestration plugin: no model workers configured yet. If the user wants cheap-model delegation, suggest /model-orchestration:setup-worker."
  exit 0
fi

cat <<EOF
<model-orchestration-defaults>
Delegation is ON by default in this environment. You (the smartest model) act
as MANAGER: do the planning, judgment, and review yourself, and DELEGATE these
to a worker below via Bash instead of doing them in your own context:
- implementation tasks that have a clear, complete spec
- token-hungry work: reading large documents, log digging, research sweeps,
  bulk/mechanical edits

Configured workers (headless Claude Code instances on other providers):
${inventory}
Dispatch: append --permission-mode acceptEdits for tasks that edit files.
Give a self-contained spec (paths, acceptance criteria) and require a short
summary with pointers, never raw dumps. Revision gate: audit every result
against the criteria before using it; on a miss, re-dispatch the SAME worker
with specific fixes; escalate (do it yourself) only after a second miss.
Judge the output, not the price tag.
Skip delegation when: the task needs your judgment/taste, it is small enough
that dispatch overhead exceeds the savings, or the user asks you to do it
directly. The orchestrating-model-workers skill has details and traps.
</model-orchestration-defaults>
EOF
