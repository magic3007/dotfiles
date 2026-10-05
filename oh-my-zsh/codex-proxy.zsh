# Codex proxy wrapper.
#
# This must be sourced at the very end of ~/.zshrc. ~/.zshrc sources
# ~/.common_shell_setup.sh twice — once from 40-runtime.zsh inside the
# zshrc.d loop, once after it — and ~/.local/bin/env re-prepends ~/.local/bin
# each time. Anything inside zshrc.d therefore ends up behind ~/.local/bin, so
# an interactive shell would resolve `codex` to the real binary and skip the
# wrapper (and with it the proxy variables).
#
# Only the wrapper goes on PATH. The shell environment itself stays free of
# proxy variables, keeping the "proxy only for Codex" property.
if [[ -d "$HOME/.local/codex-proxy/bin" ]]; then
  path=("$HOME/.local/codex-proxy/bin" $path)
fi
