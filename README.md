# model-orchestration

**Manager/worker orchestration for Claude Code.** Keep your smartest model as
the manager — planning, judging, reviewing — and delegate implementation and
token-hungry work to isolated, headless Claude Code **workers** backed by any
Anthropic-compatible API: z.ai GLM, Kimi, DeepSeek, MiniMax, LiteLLM/other
proxies, or anything else that speaks the Anthropic Messages API.

Why: flat-rate coding plans (like z.ai's GLM Coding Plan) make near-frontier
implementation effectively free, while your premium subscription is reserved
for the judgment work that actually needs it. Every worker is a separate
Claude Code identity (`~/.claude-workers/<name>/`) — your main Anthropic login,
settings, and history are never touched.

## Install

```
/plugin marketplace add divyamrastogi/model-orchestration
/plugin install model-orchestration@model-orchestration
```

## Quick start

```
/model-orchestration:setup-worker glm z.ai
```

Claude creates the worker and tells you where to put your API key (you add it
yourself — keys are never passed on the command line or requested in chat),
then verifies the worker with a live smoke test.

Then delegate:

```
/model-orchestration:delegate glm implement the pagination fix described in docs/plan.md
```

The manager writes the spec, dispatches the worker, **audits the result**
against the acceptance criteria, sends it back with revision notes if it
misses, and only escalates after a second miss. *Judge the output, not the
price tag.*

## What's inside

| Piece | Purpose |
|---|---|
| `skills/orchestrating-model-workers/` | The knowledge: setup workflow, dispatch patterns, revision gate, and the non-obvious traps (env-var inheritance breaking auth, headless onboarding) |
| `scripts/setup-worker.sh` | Generic worker manager: `create` / `set-key` / `finalize` / `list` / `remove` |
| `commands/setup-worker.md` | `/model-orchestration:setup-worker` — guided setup |
| `commands/delegate.md` | `/model-orchestration:delegate` — dispatch + audit loop |
| `skills/.../templates/delegation-rules.md` | Drop-in CLAUDE.md section to make delegation a standing behavior |

## Requirements

- Claude Code ≥ 2.x with your normal Anthropic login (the manager)
- An API key for a provider exposing an Anthropic-compatible endpoint
- `python3` on PATH (used for safe JSON editing)
- macOS or Linux

## Security notes

- API keys live only in `~/.claude-workers/<name>/settings.json` (chmod 600).
- The setup script refuses keys as CLI arguments (shell-history leak); add
  them by editing the file or piping via stdin from a secret manager.
- Workers run with whatever `--permission-mode` you dispatch them with;
  default is Claude Code's normal prompting.

## License

MIT
