function cx --description "OpenAI Codex with full auto"
    env CMUX_CODEX_HOOKS_DISABLED=1 codex -a never -s danger-full-access --search $argv
end
