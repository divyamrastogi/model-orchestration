---
name: orchestrating-model-workers
description: Use when the user wants to delegate work to cheaper or alternate models inside Claude Code — e.g. z.ai GLM, Kimi, DeepSeek, MiniMax, OpenRouter/LiteLLM proxies, or any Anthropic-compatible API — or asks about multi-model orchestration, manager/worker setups, headless worker instances, routing token-hungry work to a flat-rate coding plan, running a second provider alongside their Anthropic subscription, or when a spawned claude -p worker fails with "401 Invalid bearer token" or "Not logged in - Please run /login".
---

# Orchestrating Model Workers

Run the smartest model as a **manager** (plans, judges, reviews) and dispatch
implementation and token-hungry work to **workers** — isolated headless Claude
Code instances backed by any Anthropic-compatible API. One `claude` binary,
many identities: each worker owns a config dir under `~/.claude-workers/<name>/`
with its own settings, auth, and history, so the user's main Anthropic setup is
never touched.

## When NOT to use

- Provider has no Anthropic-compatible endpoint (GUI apps like ZCode have no
  CLI; OpenAI-format-only APIs need a translating proxy such as LiteLLM first).
- Single quick task — dispatch overhead beats the savings; just do it.

## Setting up a worker

Optional pre-flight — sanity-check the endpoint before creating anything
(expect an HTTP 4xx auth error, NOT 404 or a DNS failure):

```bash
curl -s -o /dev/null -w '%{http_code}\n' <base-url>/v1/messages -X POST
```

Run the bundled script (every command prints its next steps; `create` refuses
to overwrite an existing worker — on "already exists", use `list` to inspect
and `remove` to rebuild, don't retry blindly). Prefer a preset — run
`setup-worker.sh presets` for known providers, and when the user hasn't named
one, offer them the preset list as a choice instead of asking for URLs:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" create glm --provider zai
# or fully manual, for any Anthropic-compatible endpoint:
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" create glm \
  --base-url https://api.z.ai/api/anthropic \
  --sonnet glm-5.2 --opus glm-5.2 --haiku glm-4.7
```

Then **the user adds their API key** — never accept a key as a command-line
argument, and if the user pastes one in chat, warn them to rotate it later:

1. Edit `~/.claude-workers/glm/settings.json`, replace `PASTE_YOUR_API_KEY_HERE`
   — or pipe from a secret store: `op read ... | setup-worker.sh set-key glm`
2. `setup-worker.sh finalize glm` — seeds first-run state and smoke-tests a
   real round-trip. Do not skip: an unfinalized worker fails headless.

Model mapping flags translate Claude Code's internal tiers: `--sonnet` is what
the worker uses when invoked with `--model sonnet`, etc. Check the provider's
docs for its Anthropic endpoint URL and model names. Only invoke tiers you
mapped: an unmapped tier (e.g. `--model opus` with no `--opus` flag) passes
Anthropic's model name straight to the provider, which usually errors.

## Dispatching work

```bash
~/.claude-workers/glm/run -p "Implement X per spec in docs/plans/foo.md. \
Return a one-paragraph summary with file paths, not full diffs." \
  --permission-mode acceptEdits
```

- Give workers a **complete spec** (files, acceptance criteria, constraints);
  they run unsupervised.
- Demand **summaries with pointers**, never raw dumps into the manager context.
- **Audit every result** against the task criteria before using it (run the
  tests, read the diff). Misses go back to the *same* worker with specific
  revision notes; escalate to a smarter model only after a second miss.
  Judge the output, not the price tag.
- To install these rules permanently, append `templates/delegation-rules.md`
  (in this skill's directory) to the user's `~/.claude/CLAUDE.md`.

## Workers inside Workflows and subagents

Workflow `agent()` calls and the Agent tool only accept Claude model tiers —
they cannot route to another provider directly. Bridge with the plugin's
`worker-dispatch` agent (a thin coordinator that shells out to a worker and
relays its summary), keeping Claude for the audit stage:

```js
const results = await pipeline(tasks,
  t => agent(`Worker: glm. Task spec: ${t.spec}`,
             {agentType: 'model-orchestration:worker-dispatch', effort: 'low',
              phase: 'Implement'}),
  (r, t) => agent(`Audit this result against the criteria: ${t.criteria}\n${r}`,
                  {phase: 'Audit'})   // revision gate stays on Claude
)
```

Keep fan-out modest (~4–8 concurrent dispatches): each one is a real `claude`
process on your machine, and the provider's rate limits stack under the
workflow's own concurrency cap.

## Critical traps (verbatim failures without this setup)

| Symptom | Cause | Fix |
|---|---|---|
| `401 Invalid bearer token` from a spawned worker | Worker inherited `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY` env vars from the parent Claude session — **env vars override settings.json** — so the provider key went to the wrong API | Always invoke via the worker's `run` wrapper, never bare `CLAUDE_CONFIG_DIR=... claude`. The wrapper uses two mechanisms: it re-exports every settings.json env var (overriding inherited `ANTHROPIC_BASE_URL`), and it `unset`s `ANTHROPIC_API_KEY` (workers auth via `ANTHROPIC_AUTH_TOKEN`, so that var must not exist at all) |
| `Not logged in · Please run /login` in `-p` mode | Fresh config dir; headless runs can't answer the interactive "use this API key?" prompt | Run `setup-worker.sh finalize <name>` — it seeds `hasCompletedOnboarding` and the key approval |
| `token expired or incorrect` from provider | Truncated key (many providers use `id.secret` format — both halves needed), or key not enabled for the coding-plan endpoint | `curl` the provider endpoint directly to isolate key vs. wiring |
| Worker ignores mapped model | Wrong flag tier | Mapping vars only apply to the tier requested: `--model sonnet` reads `ANTHROPIC_DEFAULT_SONNET_MODEL` |

## Quick reference

`setup-worker.sh` below means `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh"`
— it is not on PATH.

| Action | Command |
|---|---|
| List provider presets | `setup-worker.sh presets` |
| Create worker (preset) | `setup-worker.sh create <name> --provider <id>` |
| Create worker (manual) | `setup-worker.sh create <name> --base-url <url> [--sonnet/--opus/--haiku <model>]` |
| Add key (stdin) | `printf '%s' "$KEY" \| setup-worker.sh set-key <name>` |
| Verify + activate | `setup-worker.sh finalize <name>` |
| List / remove | `setup-worker.sh list` / `setup-worker.sh remove <name>` |
| Dispatch task | `~/.claude-workers/<name>/run -p "<task>" --permission-mode acceptEdits` |
| Interactive session | `~/.claude-workers/<name>/run` |
