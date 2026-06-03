# transfer.sh helper
# WARNING: Files are uploaded to a PUBLIC server. Do not upload sensitive data.
transfer() {
  local file
  typeset -a file_array
  file_array=("${@}")

  if [[ "${file_array[@]}" == "" || "${1}" == "--help" || "${1}" == "-h" ]]; then
    echo "${0} - Upload arbitrary files to \"transfer.sh\"."
    echo ""
    echo "Usage: ${0} [options] [<file>]..."
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help"
    echo "      show this message"
    echo ""
    echo "EXAMPLES:"
    echo "  Upload a single file from the current working directory:"
    echo "      ${0} \"image.img\""
    echo ""
    echo "  Upload multiple files from the current working directory:"
    echo "      ${0} \"image.img\" \"image2.img\""
    echo ""
    echo "  Upload a file from a different directory:"
    echo "      ${0} \"/tmp/some_file\""
    echo ""
    echo "  Upload all files from the current working directory. Be aware of the webserver's rate limiting!:"
    echo "      ${0} *"
    echo ""
    echo "  Upload a single file from the current working directory and filter out the delete token and download link:"
    echo "      ${0} \"image.img\" | awk --field-separator=\": \" '/Delete token:/ { print \$2 } /Download link:/ { print \$2 }'"
    echo ""
    echo "  Show help text from \"transfer.sh\":"
    echo "      curl --request GET \"https://transfer.sh\""
    return 0
  fi

  for file in "${file_array[@]}"; do
    if [[ ! -f "${file}" ]]; then
      echo -e "\e[01;31m'${file}' could not be found or is not a file.\e[0m" >&2
      return 1
    fi
  done
  unset file

  local upload_files
  local curl_output
  local awk_output

  du -c -k -L "${file_array[@]}" >&2
  if [[ "${ZSH_NAME}" == "zsh" ]]; then
    read $'upload_files?\e[01;31mDo you really want to upload the above files ('"${#file_array[@]}"$') to "transfer.sh"? (Y/n): \e[0m'
  elif [[ "${BASH}" == *"bash"* ]]; then
    read -p $'\e[01;31mDo you really want to upload the above files ('"${#file_array[@]}"$') to "transfer.sh"? (Y/n): \e[0m' upload_files
  fi

  case "${upload_files:-y}" in
    "y"|"Y")
      for file in "${file_array[@]}"; do
        curl_output=$(curl --request PUT --progress-bar --dump-header - --upload-file "${file}" "https://transfer.sh/")
        awk_output=$(awk \
          'gsub("\r", "", $0) && tolower($1) ~ /x-url-delete/ \
          {
              delete_link=$2;
              print "Delete command: curl --request DELETE " "\""delete_link"\"";

              gsub(".*/", "", delete_link);
              delete_token=delete_link;
              print "Delete token: " delete_token;
          }

          END{
              print "Download link: " $0;
          }' <<< "${curl_output}")

        echo -e "${awk_output}\n"

        if (( ${#file_array[@]} > 4 )); then
          sleep 5
        fi
      done
      ;;
    "n"|"N")
      return 1
      ;;
    *)
      echo -e "\e[01;31mWrong input: '${upload_files}'.\e[0m" >&2
      return 1
      ;;
  esac
}

# Go up directory tree X number of directories
up() {
  local counter="${1:-1}"
  if ! [[ "$counter" == <-> ]]; then
    echo "usage: up [NUMBER]"
    return 1
  fi

  local new_dir="$PWD"
  while (( counter > 0 )); do
    new_dir="${new_dir:h}"
    (( counter-- ))
  done
  cd "$new_dir" || return 1
}
