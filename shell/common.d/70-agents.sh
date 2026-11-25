# Wrappers that pin a provider, model or permission mode for the AI harnesses.
# Credentials stay in the environment or in ~/.common_shell_setup_local.sh.

# native claude code
cc() {
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
  API_TIMEOUT_MS=600000 \
  claude --dangerously-skip-permissions "$@"
}

# cc-gateway claude code
ccg() {
  local ccg_bin
  ccg_bin=$(find "$HOME/.cc-gateway/clients" -maxdepth 1 -type f -name "cc-*" | head -n 1)
  if [[ -n "$ccg_bin" ]]; then
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
    API_TIMEOUT_MS=600000 \
    "$ccg_bin" --dangerously-skip-permissions "$@"
  else
    echo "No ccg client found in $HOME/.cc-gateway/clients/" >&2
    return 1
  fi
}

# opencode
oc() {
  opencode "$@"
}

# Codex with full-auto mode. Disable cmux's per-invocation hooks: older cmux
# wrappers run lifecycle hooks synchronously, delaying both startup and exit.
cx() {
  CMUX_CODEX_HOOKS_DISABLED=1 codex -a never -s danger-full-access --search "$@"
}

# Lightweight Codex provider/model switching. Provider definitions must exist
# in ~/.codex/config.toml; credentials stay in the environment or local Codex
# config. These overrides affect only the current Codex process.
cxp() {
  if [ "$#" -lt 2 ]; then
    echo "usage: cxp <provider> <model> [codex args...]" >&2
    return 2
  fi
  local provider="$1" model="$2"
  shift 2
  cx -c "model_provider=\"${provider}\"" -m "$model" "$@"
}

cxds()    { cxp dspix deepseek-flash "$@"; }
cxglm()   { cxp glmpix glm-5.3-flash "$@"; }

# google antigravity cli (per-account isolated --gemini_dir; default effort medium)
_agy_run() {
  local gemini_dir="$1" model="$2"
  shift 2
  agy --gemini_dir="$gemini_dir" --dangerously-skip-permissions --model "$model" "$@"
}

agyh() { _agy_run "$HOME/.gemini"   gemini-4-hydrogen-medium "$@"; }
agyc() { _agy_run "$HOME/.gemini-2" gemini-4-carbon-medium   "$@"; }

# claude code with a custom Anthropic-compatible API
# Reference: https://api-docs.deepseek.com/guides/anthropic_api
_claude_with_api() {
  local model="$1" base_url="$2" api_key="$3" binary="${4:-claude}"
  shift 4
  env -u ANTHROPIC_API_KEY \
    ANTHROPIC_BASE_URL="$base_url" \
    ANTHROPIC_AUTH_TOKEN="$api_key" \
    API_TIMEOUT_MS=600000 \
    ANTHROPIC_MODEL="$model" \
    ANTHROPIC_DEFAULT_SONNET_MODEL="$model" \
    ANTHROPIC_DEFAULT_OPUS_MODEL="$model" \
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$model" \
    ANTHROPIC_SMALL_FAST_MODEL="$model" \
    CLAUDE_CODE_SUBAGENT_MODEL="$model" \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
    "$binary" "$@" --dangerously-skip-permissions
}

dscc()    { _claude_with_api "deepseek-v4-flash[1m]" "https://ark.cn-beijing.volces.com/api/coding" "${VE_CODE_API_KEY}" claude "$@"; }
dsccpro()    { _claude_with_api "deepseek-v4-pro[1m]" "https://ark.cn-beijing.volces.com/api/coding" "${VE_CODE_API_KEY}" claude "$@"; }
dsccx()    { _claude_with_api "deepseek-flash[1m]" "https://api.deepseek.com/anthropic" "${DEEPSEEK_API_KEY}" claude "$@"; }
dsccprox() { _claude_with_api "deepseek-v4-pro[1m]" "https://api.deepseek.com/anthropic" "${DEEPSEEK_API_KEY}" claude "$@"; }

autocc()  { _claude_with_api "ark-code-latest" "https://ark.cn-beijing.volces.com/api/coding" "${VE_CODE_API_KEY}" claude "$@"; }
sdcc()    { _claude_with_api "doubao-seed-2.0-lite" "https://ark.cn-beijing.volces.com/api/coding" "${VE_CODE_API_KEY}" claude "$@"; }
sdccpro() { _claude_with_api "doubao-seed-2.0-pro" "https://ark.cn-beijing.volces.com/api/coding" "${VE_CODE_API_KEY}" claude "$@"; }

kmcc()    { _claude_with_api "kimi-k3" "https://api.kimi.com/coding/" "${KIMI_CODE_API_KEY}" claude "$@"; }
kmcc2()   { _claude_with_api "kimi-k3" "https://api.moonshot.cn/anthropic" "${KIMI_API_KEY}" claude "$@"; }

glmcc()   { _claude_with_api "glm-5.3" "https://ark.cn-beijing.volces.com/api/coding" "${VE_CODE_API_KEY}" claude "$@"; }

# pi coding-agent equivalents of the *cc aliases above.
# Providers (URLs + model ids) live in the tracked pi/models.json; only the
# API keys stay as env vars ($VE_CODE_API_KEY etc.) referenced by those providers.
# pi sends the model id verbatim — if a gateway rejects a "[1m]" suffix, drop it
# in pi/models.json.
dspi()     { pi --provider arkcoding --model 'deepseek-v4-flash[1m]' "$@"; }
dspipro()  { pi --provider arkcoding --model 'deepseek-v4-pro[1m]' "$@"; }
dspix()    { pi --provider dspro-responses --model 'deepseek-flash' "$@"; }
dspiprox() { pi --provider dspro     --model 'deepseek-v4-pro[1m]' "$@"; }

autopi()   { pi --provider arkcoding --model 'ark-code-latest' "$@"; }
sdpi()     { pi --provider arkcoding --model 'doubao-seed-2.0-lite' "$@"; }
sdpipro()  { pi --provider arkcoding --model 'doubao-seed-2.0-pro' "$@"; }

kmpi()     { pi --provider kimicode  --model 'kimi-k3' "$@"; }
kmpi2()    { pi --provider moonshot  --model 'kimi-k3' "$@"; }

glmpi()    { pi --provider arkcoding-responses --model 'glm-5.3' "$@"; }
glmpix()   { pi --provider zai-responses --model 'glm-5.3-flash' "$@"; }

f5pi()   { pi --provider openz --model 'claude-fable-5' "$@"; }
o5pi()   { pi --provider openz --model 'claude-opus-5' "$@"; }

okpi()   { pi --provider kafara --model 'devin/claude-opus-5-5' "$@"; }
fkpi()   { pi --provider kafara --model 'devin/claude-fable-5-1' "$@"; }

# omp (oh-my-pi / @oh-my-pi/pi-coding-agent) model shortcuts, mirroring the *pi
# group above. Named after the *roles* in omp/config.yml (modelRoles), so
# provider, model id, base URL and thinking level stay in one place; omp's
# built-in providers (deepseek, devin, …) need no entry in omp/models.yml, only
# DEEPSEEK_API_KEY etc. in the environment. Tool calls are already pre-approved
# (tools.approvalMode = yolo), so no extra flags here. Anything else:
# `omp --model <role>` or `omp --model <provider>/<model-id>`.
dvomp()   { omp --model devin-opus       "$@"; }  # claude-opus-5-5 via devin
kvomp()   { omp --model kafara-opus       "$@"; }  # claude-opus-5-5 via kafara
dsomp()   { omp --model deepseek-flash   "$@"; }  # DeepSeek V4.1 Flash (1M ctx, images)
glmomp()  { omp --model zai-flash        "$@"; }  # GLM-5.3-Flash via zai (role zai-flash = zai/glm-5.3-flash:max)
gvomp()   { omp --model kafara/gemini-4-argon-high "$@"; }  # Gemini 4 Argon (high) via kafara, no modelRoles entry
gkomp()   { omp --model kafara/devin/grok-4-7 "$@"; }  # Grok 4.7 via kafara (no per-token cost); devin/grok-4-7 also works but bills

# dsh (DeepSeek Harness): the launcher refuses to start without a profile name
# (`error: --profile <name> is required`); there is no default-profile env var.
# Bare `dsh` therefore boots the web profile, the only interactive one shipped
# (others: headless, sdk, sdk-minimal, acp). Everything else passes through, so
# `dsh headless "..."`, `dsh --version`, `dsh plugin ...` behave as documented.
#
# The web profile also binds this machine's LAN IPv4 instead of loopback, so
# another host can open the printed URL. dsh refuses wildcard binds (--host takes
# one concrete interface literal), so the address is resolved per call, skipping
# docker0. Auth is unchanged: the URL carries a token, other requests get 401.
# An explicit `--host` in the arguments wins; other profiles are never touched.
_dsh_lan_ip() {
  ip -4 -o addr show scope global 2>/dev/null |
    awk '$2 != "docker0" { split($4, a, "/"); print a[1]; exit }'
}

dsh() {
  local arg ip has_host=0
  for arg in "$@"; do
    [ "$arg" = "--host" ] && has_host=1
  done
  ip=$(_dsh_lan_ip)
  if [ "$#" -eq 0 ]; then
    set -- web
    [ -n "$ip" ] && set -- web --host "$ip"
  elif [ "$has_host" -eq 0 ] && [ -n "$ip" ] &&
       { [ "$1" = web ] || { [ "$1" = --profile ] && [ "${2-}" = web ]; }; }; then
    set -- "$@" --host "$ip"
  fi
  command dsh "$@"
}
