#!/usr/bin/env bash
# setup-worker.sh — create and manage headless Claude Code "workers" backed by
# any Anthropic-compatible API (z.ai GLM, Kimi, DeepSeek, MiniMax, LiteLLM
# proxies, ...). Each worker is a fully isolated Claude Code identity under
# ~/.claude-workers/<name>/ with its own settings, auth, and history.
#
# Usage:
#   setup-worker.sh create <name> --base-url <url> [--sonnet <model>] [--opus <model>] [--haiku <model>]
#   setup-worker.sh set-key <name>        # reads API key from stdin (never a CLI arg)
#   setup-worker.sh finalize <name>       # seed onboarding + run smoke test
#   setup-worker.sh list
#   setup-worker.sh remove <name>
#
# Security: API keys are never accepted as command-line arguments (they would
# leak into shell history and process lists). Add the key by editing the
# worker's settings.json, or pipe it to `set-key` (e.g. from a password manager:
#   op read op://vault/zai/apikey | setup-worker.sh set-key glm ).
set -euo pipefail

WORKERS_ROOT="${CLAUDE_WORKERS_ROOT:-$HOME/.claude-workers}"
PLACEHOLDER="PASTE_YOUR_API_KEY_HERE"

die() { echo "error: $*" >&2; exit 1; }

worker_dir() { echo "$WORKERS_ROOT/$1"; }

require_worker() {
  [ -n "${1:-}" ] || die "worker name required"
  [ -d "$(worker_dir "$1")" ] || die "worker '$1' not found (run: setup-worker.sh create $1 --base-url ...)"
}

json_get() { # json_get <file> <dot.path>
  python3 - "$1" "$2" <<'PY'
import json, sys
obj = json.load(open(sys.argv[1]))
for k in sys.argv[2].split('.'):
    obj = obj[k]
print(obj)
PY
}

cmd_create() {
  local name="" base_url="" sonnet="" opus="" haiku=""
  name="${1:-}"; shift || true
  [ -n "$name" ] || die "usage: setup-worker.sh create <name> --base-url <url> [--sonnet m] [--opus m] [--haiku m]"
  echo "$name" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || die "worker name must be lowercase letters, digits, hyphens"
  while [ $# -gt 0 ]; do
    case "$1" in
      --base-url) base_url="$2"; shift 2 ;;
      --sonnet)   sonnet="$2";   shift 2 ;;
      --opus)     opus="$2";     shift 2 ;;
      --haiku)    haiku="$2";    shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  [ -n "$base_url" ] || die "--base-url is required (the provider's Anthropic-compatible endpoint)"

  local dir; dir="$(worker_dir "$name")"
  [ -e "$dir" ] && die "worker '$name' already exists at $dir"
  mkdir -p "$dir"

  # settings.json — model-mapping vars are only written if provided, so a
  # worker can also be a plain passthrough to the provider's defaults.
  python3 - "$dir/settings.json" "$base_url" "$sonnet" "$opus" "$haiku" <<'PY'
import json, sys
path, base_url, sonnet, opus, haiku = sys.argv[1:6]
env = {
    "ANTHROPIC_AUTH_TOKEN": "PASTE_YOUR_API_KEY_HERE",
    "ANTHROPIC_BASE_URL": base_url,
    "API_TIMEOUT_MS": "3000000",
}
if sonnet: env["ANTHROPIC_DEFAULT_SONNET_MODEL"] = sonnet
if opus:   env["ANTHROPIC_DEFAULT_OPUS_MODEL"] = opus
if haiku:  env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = haiku
with open(path, "w") as f:
    json.dump({"env": env}, f, indent=2)
    f.write("\n")
PY
  chmod 600 "$dir/settings.json"

  # Wrapper: exports everything from settings.json env as real environment
  # variables. This is NOT redundant — a worker spawned from inside another
  # Claude Code session inherits that session's ANTHROPIC_BASE_URL etc., and
  # environment variables take precedence over settings.json. Without these
  # explicit exports the worker sends this provider's key to the wrong API
  # and fails with 401.
  cat > "$dir/run" <<WRAPPER
#!/usr/bin/env bash
set -euo pipefail
export CLAUDE_CONFIG_DIR="$dir"
eval "\$(python3 - <<'PY'
import json, shlex
env = json.load(open("$dir/settings.json"))["env"]
for k, v in env.items():
    print(f"export {k}={shlex.quote(str(v))}")
PY
)"
unset ANTHROPIC_API_KEY CLAUDECODE CLAUDE_CODE_SESSION_ID CLAUDE_CODE_CHILD_SESSION 2>/dev/null || true
exec claude "\$@"
WRAPPER
  chmod 755 "$dir/run"

  cat <<EOF
Worker '$name' created at $dir

NEXT STEPS (an API key is required before the worker can run):
  1. Add your API key — either:
       - edit $dir/settings.json and replace $PLACEHOLDER, or
       - pipe it in:  printf '%s' 'your-key' | setup-worker.sh set-key $name
  2. Finalize and smoke-test:  setup-worker.sh finalize $name

The key stays in $dir/settings.json (chmod 600), read only by this worker.
EOF
}

cmd_set_key() {
  require_worker "${1:-}"
  local dir key; dir="$(worker_dir "$1")"
  if [ -t 0 ]; then
    printf 'Paste API key for worker %s (input hidden): ' "$1" >&2
    read -rs key; echo >&2
  else
    key="$(cat)"
  fi
  key="$(printf '%s' "$key" | tr -d '[:space:]')"
  [ -n "$key" ] || die "empty key"
  python3 - "$dir/settings.json" "$key" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
cfg = json.load(open(path))
cfg["env"]["ANTHROPIC_AUTH_TOKEN"] = key
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
  chmod 600 "$dir/settings.json"
  echo "Key stored for '$1'. Now run: setup-worker.sh finalize $1"
}

cmd_finalize() {
  require_worker "${1:-}"
  local name="$1" dir key; dir="$(worker_dir "$1")"
  key="$(json_get "$dir/settings.json" env.ANTHROPIC_AUTH_TOKEN)"
  [ "$key" != "$PLACEHOLDER" ] || die "API key not set yet — see 'create' output for how to add it"

  # Seed first-run state. Headless (-p) runs cannot answer the interactive
  # "use this API key?" onboarding prompt; without this seed they fail with
  # "Not logged in - Please run /login".
  python3 - "$dir/.claude.json" "$key" <<'PY'
import json, sys, os
path, key = sys.argv[1], sys.argv[2]
state = json.load(open(path)) if os.path.exists(path) else {}
state["hasCompletedOnboarding"] = True
approved = state.setdefault("customApiKeyResponses", {}).setdefault("approved", [])
suffix = key[-20:]
if suffix not in approved:
    approved.append(suffix)
with open(path, "w") as f:
    json.dump(state, f, indent=2)
PY

  echo "Running smoke test (headless round-trip through the provider)..."
  local out
  out="$("$dir/run" -p "Reply with exactly this string and nothing else: WORKER_ONLINE" --model sonnet 2>&1)" || true
  if printf '%s' "$out" | grep -q "WORKER_ONLINE"; then
    cat <<EOF
✅ Worker '$name' is online.

Invoke it:
  headless task:      $dir/run -p "<task>" [--permission-mode acceptEdits]
  interactive shell:  $dir/run
  handy alias:        alias $name='$dir/run'   (add to your shell rc)
EOF
  else
    echo "❌ Smoke test failed. Provider response:" >&2
    printf '%s\n' "$out" | tail -5 >&2
    echo "Check the API key, base URL, and model names in $dir/settings.json" >&2
    exit 1
  fi
}

cmd_list() {
  [ -d "$WORKERS_ROOT" ] || { echo "no workers"; return; }
  local d name url
  for d in "$WORKERS_ROOT"/*/; do
    [ -f "$d/settings.json" ] || continue
    name="$(basename "$d")"
    url="$(json_get "$d/settings.json" env.ANTHROPIC_BASE_URL 2>/dev/null || echo '?')"
    key="$(json_get "$d/settings.json" env.ANTHROPIC_AUTH_TOKEN 2>/dev/null || echo '')"
    if [ "$key" = "$PLACEHOLDER" ]; then status="needs key"; else status="configured"; fi
    printf '%-16s %-12s %s\n' "$name" "$status" "$url"
  done
}

cmd_remove() {
  require_worker "${1:-}"
  rm -rf "$(worker_dir "$1")"
  echo "Worker '$1' removed."
}

case "${1:-}" in
  create)   shift; cmd_create "$@" ;;
  set-key)  shift; cmd_set_key "$@" ;;
  finalize) shift; cmd_finalize "$@" ;;
  list)     shift; cmd_list "$@" ;;
  remove)   shift; cmd_remove "$@" ;;
  *) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
