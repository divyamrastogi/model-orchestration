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
/model-orchestration:setup-worker
```

That's the whole command: Claude shows you a picker of known providers —
z.ai GLM, Moonshot Kimi, MiniMax, DeepSeek, or any custom Anthropic-compatible
endpoint — and configures the ones you select (endpoints and model mappings
come from bundled presets). The only thing you supply is your API key: Claude
tells you where to get it and which file to put it in (keys are never passed
on the command line or requested in chat). A live smoke test confirms each
worker before it's used.

**That's it — delegation is now the default.** A SessionStart hook injects the
orchestration rules and your worker inventory into every session, so Claude
automatically routes well-specced implementation and token-hungry work to your
workers and keeps judgment work on your premium model. (With no workers
configured, the hook stays out of the way.)

You can also delegate explicitly:

```
/model-orchestration:delegate glm implement the pagination fix described in docs/plan.md
```

Either way, the manager writes the spec, dispatches the worker, **audits the result**
against the acceptance criteria, sends it back with revision notes if it
misses, and only escalates after a second miss. *Judge the output, not the
price tag.*

## What's inside

| Piece | Purpose |
|---|---|
| `skills/orchestrating-model-workers/` | The knowledge: setup workflow, dispatch patterns, revision gate, and the non-obvious traps (env-var inheritance breaking auth, headless onboarding) |
| `scripts/setup-worker.sh` | Generic worker manager: `create` / `set-key` / `finalize` / `list` / `remove` |
| `commands/setup-worker.md` | `/model-orchestration:setup-worker` — guided setup |
| `commands/delegate.md` | `/model-orchestration:delegate` — explicit dispatch + audit loop |
| `hooks/session-start.sh` | Makes delegation the default: injects rules + worker inventory each session |
| `agents/worker-dispatch.md` | Bridge agent so Workflow scripts and the Agent tool can fan tasks out to workers (`agentType: 'model-orchestration:worker-dispatch'`) |
| `skills/.../templates/delegation-rules.md` | Drop-in CLAUDE.md section to make delegation a standing behavior |

## Local models

Ollama (≥ v0.14.0) exposes a native Anthropic-compatible endpoint, so fully
local workers work too: `ollama` is a built-in preset, and the setup command
offers your locally pulled models as tier mappings (API key is the literal
string `ollama`). llama.cpp's `llama-server`, LM Studio, and LiteLLM/Olla
proxies plug in the same way via `--base-url`. See the skill's local-models
section for verified caveats (MLX variants, older-Ollama `count_tokens` hangs)
and realistic expectations — local workers suit privacy/offline and simple
bulk tasks rather than primary implementation.

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
