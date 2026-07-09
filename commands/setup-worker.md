---
description: Set up a model worker — pick a provider from presets or supply any Anthropic-compatible API
argument-hint: "[worker-name] [provider or base URL] (no args = interactive picker)"
---

Set up one or more model workers using the orchestrating-model-workers skill
(read its SKILL.md in this plugin before starting).

Arguments given: "$ARGUMENTS"

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" presets` to load the
   known providers.
2. **If no provider was specified in the arguments:** ask the user which
   provider(s) to configure using the AskUserQuestion tool — one option per
   preset (label + note as description, multiSelect: true) — rather than
   making them type URLs. If they pick "Other", ask for the provider name and
   look up its Anthropic-compatible endpoint and model names in its docs (web
   search if needed).
3. For each chosen provider, run:
   `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" create <name> --provider <id>`
   Default the worker name to the preset id unless the user gave one.
4. Show the user where to get the key (the preset's key_url) and exactly how
   to add it (the two options the script printed). NEVER ask them to paste the
   key into chat; if they do anyway, use it but advise rotating it afterwards.
5. Once they confirm the key is in place, run
   `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" finalize <name>` and report
   the smoke-test result. If it fails, debug per the skill's traps table
   (stale preset model names → check the provider docs).
6. Offer to append the skill's `templates/delegation-rules.md` to their
   `~/.claude/CLAUDE.md` so delegation becomes a standing behavior.
