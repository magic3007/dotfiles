# PATH shared by bash and zsh — each tool directory appears once.
export PATH="$HOME/.local/bin:$PATH"            # uv and hand-installed tools
[[ -d "$HOME/.fzf/bin" ]] && PATH="$HOME/.fzf/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"         # opencode
export PATH="$HOME/.kimi-code/bin:$PATH"        # Kimi Code CLI
export PATH="$HOME/.minimax-code/bin:$PATH"     # MiniMax Code CLI (mcode)
export PATH="$HOME/.minimax/bin:$PATH"          # MiniMax CLI
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[[ -f "$HOME/.antigravity/antigravity/bin/antigravity" ]] &&
  PATH="$HOME/.antigravity/antigravity/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
# google-cloud-sdk (brew cask gcloud-cli): binaries installed via
# `gcloud components install` land here, not /opt/homebrew/bin
[[ -d /opt/homebrew/share/google-cloud-sdk/bin ]] &&
  PATH="/opt/homebrew/share/google-cloud-sdk/bin:$PATH"

# uv's env file adds ~/.local/bin when uv created one
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"

# clashctl proxy helpers; no-op when the checkout is not installed
export CLASHCTL_HOME="$HOME/clashctl"
[[ -f "$CLASHCTL_HOME/scripts/cmd/clashctl.sh" ]] && source "$CLASHCTL_HOME/scripts/cmd/clashctl.sh"
