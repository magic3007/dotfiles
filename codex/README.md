# OpenAI Codex Configuration

This directory contains configuration files for OpenAI Codex CLI tool.

## Files

- `config.json` - API key and organization settings
- `settings.json` - Default model and generation parameters
- `codex_env.sh` - Environment setup script (sourced by shell)

## Setup

1. Edit `config.json` and replace `your-openai-api-key-here` with your actual OpenAI API key
2. Optionally edit `settings.json` to adjust default model, temperature, etc.
3. Run `./install` from the dotfiles root directory to symlink these files to `~/.codex/`

## Usage

The `codex_env.sh` script will:
- Set `OPENAI_API_KEY` environment variable from `config.json`
- Set `OPENAI_ORGANIZATION` if specified
- Set `CODEX_DEFAULT_MODEL` and `CODEX_TEMPERATURE` from `settings.json`
- Create `cx` alias for `codex` command

The script is automatically sourced by `common_shell_setup.sh`.

## Notes

- Keep your actual API key in `config.json` (this file is symlinked to your home directory)
- For local overrides, create `~/.codex/config_local.json` and modify the sourcing logic in `codex_env.sh`
- The Codex CLI tool is installed via npm during the installation process