---
description: Set up a new model worker (isolated Claude Code identity backed by another provider's Anthropic-compatible API)
argument-hint: "[worker-name] [provider or base URL]"
---

Set up a model worker using the orchestrating-model-workers skill (read its
SKILL.md in this plugin before starting).

Arguments given: "$ARGUMENTS"

1. Determine the worker name, provider base URL, and model mappings. If the
   user named a provider instead of a URL, look up its Anthropic-compatible
   endpoint and current model names in its documentation (web search if
   needed). If anything is ambiguous, ask.
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" create <name> --base-url <url> [--sonnet/--opus/--haiku <model>]`.
3. Show the user exactly where to put their API key (the two options the
   script printed). NEVER ask them to paste the key into chat; if they do
   anyway, use it but advise rotating it afterwards.
4. Once they confirm the key is in place, run
   `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" finalize <name>` and report
   the smoke-test result. If it fails, debug per the skill's traps table.
5. Offer to append the skill's `templates/delegation-rules.md` to their
   `~/.claude/CLAUDE.md` so delegation becomes a standing behavior.
