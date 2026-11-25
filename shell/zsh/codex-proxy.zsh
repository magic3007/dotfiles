# Codex proxy wrapper.
#
# Sourced by zshrc.d/40-runtime.zsh after ~/.common_shell_setup.sh. The shared
# setup prepends ~/.local/bin, so the wrapper must be prepended again afterwards
# to outrank it; otherwise an interactive shell resolves `codex` to the real
# binary and skips the wrapper (and with it the proxy variables).
#
# Only the wrapper goes on PATH. The shell environment itself stays free of
# proxy variables, keeping the "proxy only for Codex" property.
if [[ -d "$HOME/.local/codex-proxy/bin" ]]; then
  path=("$HOME/.local/codex-proxy/bin" $path)
fi
