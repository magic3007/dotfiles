#!/usr/bin/env bash
# Credit to https://github.com/wongsingfo/dotfiles/blob/master/chatgpt.sh

set -e
set -o pipefail

# API_HOST=api.openai.com
# API_HOST=api.anthropic.com
# API_HOST=api.deepseek.com
# API_HOST=api.gptsapi.net
API_HOST=api.xiaoai.plus
# API_KEY=$(cat $HOME/.config/DEEPSEEK_KEY)
# API_KEY=$(cat $HOME/.config/WILDCARD_KEY)
API_KEY=$(cat $HOME/.config/XIAOAI_KEY)
TMP_FILE=/tmp/chatgpt-input.txt

PROMPT_SYSTEM="You are a large language model. Answer as concisely as possible."
PROMPT_COMMAND_GENERATION="You are a Command Line Interface expert and your
task is to provide functioning shell commands. Return a CLI command and nothing
else - do not send it in a code block, quotes, or anything else, just the pure
text CONTAINING ONLY THE COMMAND. If possible, return a one-line bash
command or chain many commands together. Return ONLY the command ready
to run in the terminal. The command should do the following:"
PROMPT_CHAT_INIT="You are a Large Language Model. You will be answering
questions from users. You answer as concisely as possible for each response
(e.g. don’t be verbose). If you are generating a list, do not have too many
items. Keep the number of items short. Before each user prompt you will be
given the chat history in Q&A form. Output your answer directly, with no labels
in front. Do not start your answers with A or Anwser."
PROMPT_WRITING="You are a professor specializing in computer networking. Please
act as the user's writing mentor to refine the upcoming paragraphs for
submission to a top-tier computer science conference. Make the content
accessible to most people, use plain word and make it easy to understand. Try
to avoid using fancy words. Strengthen the logic and ensure it aligns with
academic standards."
# MODEL="deepseek-coder"
MODEL="gpt-4o-mini"

function print_help() {
	cat <<EOF
Usage:
	$0 [command] [options] prompt_text

Commands:
	--help
	--list-model

Options:
	--model <model>   Default: ${MODEL}
	--cli             Generate a bash command
	--attach <file>   Add an attachment
	--stdin           Equivalent to --attach /dev/stdin
	--verbose

Prompt override:
	--writing         Writing assitant
EOF
	exit 1
}

function list_models() {
	curl https://${API_HOST}/v1/models \
		--fail -sS -H "Authorization: Bearer $API_KEY" |
		jq -r '.data[].id'
}

if [ $# -eq 0 ]; then
	print_help
fi

attachment=""
cli_mode=""
verbose_mode=""

while [ "$1" != "" ]; do
	case $1 in
	--attach)
		shift
		attachment=$1
		;;
	--stdin)
		attachment=/dev/stdin
		;;
	--cli)
		cli_mode=1
		;;
	--model)
		shift
		MODEL=$1
		;;
	--help)
		print_help
		;;
	--list-model)
		list_models
		exit
		;;
	--writing)
		PROMPT_SYSTEM=PROMPT_WRITING
		;;
	--verbose)
		set -x
		verbose_mode=1
		;;
	-*)
		echo "unknwon options $1"
		exit 1
		;;
	*)
		prompt=$1
		;;
	esac
	shift
done

function make_input_cli() {
	local content="$1"
	cat >$TMP_FILE <<EOF
{
"model": "$MODEL",
"stream": true,
"messages": [
{
	"role": "system",
	"content": "$PROMPT_COMMAND_GENERATION"
},
{
	"role": "user",
	"content": $(jq --raw-input --slurp <<<"$content")
}
]
}
EOF
}

function make_input_once() {
	local content="$1"
	cat >$TMP_FILE <<EOF
{
"model": "$MODEL",
"stream": true,
"messages": [
{
	"role": "system",
	"content": "$PROMPT_SYSTEM"
},
{
	"role": "user",
	"content": $(jq --raw-input --slurp <<<"$content")
}
]
}
EOF
}

function make_input_with_attachment() {
	local content="$1"
	local attachment="$2"
	cat >$TMP_FILE <<EOF
{
"model": "$MODEL",
"stream": true,
"messages": [
{
	"role": "system",
	"content": $(jq --raw-input --slurp <<<"$content")
},
{
	"role": "user",
	"content":
EOF
	jq --raw-input --slurp <"$attachment" >>$TMP_FILE
	cat >>$TMP_FILE <<"EOF"
}
]
}
EOF
}

function make_request() {
	curl --fail --header "Authorization: Bearer $API_KEY" \
		--header 'Content-Type: application/json' \
		--data "@$TMP_FILE" -N -s "https://${API_HOST}/v1/chat/completions" |
		awk -F 'data: ' '{print $2; fflush()}' |
		jq --unbuffered -R -j 'fromjson? | (.choices[].delta.content)? | select(. != null)'
	# Add a newline at the end
	echo
}

if [ -n "$cli_mode" ]; then
	make_input_cli "$prompt"
	cmd=$(make_request)
	echo "$cmd"
	read -p "Do you want to continue? (y/N): " response
	response=${response:-N}
	if [[ "$response" =~ ^[Yy]$ ]]; then
		eval "$cmd"
	else
		echo "Abort"
	fi
	exit
fi

if [ -z "$attachment" ]; then
	make_input_once "$prompt"
else
	make_input_with_attachment "$prompt" "$attachment"
fi
if [ -n "$verbose_mode" ]; then
	cat $TMP_FILE
fi
make_request
