# Privacy Policy — model-orchestration

Effective: July 2026

**model-orchestration collects no data.** There is no telemetry, no analytics,
no logging to any service operated by the plugin author, and no network
endpoint owned by this plugin.

## What the plugin does with your data

- **API keys** you configure are written only to
  `~/.claude-workers/<name>/settings.json` on your machine (file mode 600).
  They are sent only to the provider endpoint you yourself configured for that
  worker (e.g. api.z.ai, api.moonshot.ai, or your own localhost). The setup
  script refuses keys as command-line arguments to keep them out of shell
  history.
- **Task content** you delegate is sent directly from your machine to the
  provider you configured for that worker, using that provider's API. No
  intermediary is involved. Which data leaves your machine is determined
  entirely by which worker you dispatch to — a localhost/Ollama worker sends
  nothing to any cloud.
- **Worker inventory** (names, endpoints, model mappings — never keys) is read
  at session start and shown to Claude locally so it can route work.

## Third parties

Your relationship with each model provider (Anthropic, z.ai, Moonshot,
DeepSeek, MiniMax, or any custom endpoint) is governed by that provider's own
terms and privacy policy. This plugin only forwards the requests you initiate
to the endpoints you configured.

## Changes

Any change to this policy will appear in this file's git history in the
public repository: https://github.com/divyamrastogi/model-orchestration

## Contact

Open an issue at https://github.com/divyamrastogi/model-orchestration/issues
