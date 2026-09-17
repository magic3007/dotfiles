function transfer --description "Upload files to transfer.sh"
    if test (count $argv) -eq 0; or test "$argv[1]" = "--help"; or test "$argv[1]" = "-h"
        echo "transfer - Upload arbitrary files to \"transfer.sh\"."
        echo ""
        echo "Usage: transfer [<file>]..."
        echo ""
        echo "EXAMPLES:"
        echo "  transfer image.img"
        echo "  transfer image.img image2.img"
        return 0
    end

    for file in $argv
        if not test -f "$file"
            echo -e "\e[01;31m'$file' could not be found or is not a file.\e[0m" >&2
            return 1
        end
    end

    du -c -k -L $argv >&2
    read -P (echo -e "\e[01;31mDo you really want to upload "(count $argv)" file(s) to \"transfer.sh\"? (Y/n): \e[0m") upload_files

    switch (string lower -- "$upload_files")
        case '' y
            for file in $argv
                set -l curl_output (curl --request PUT --progress-bar --dump-header - --upload-file "$file" "https://transfer.sh/")
                echo $curl_output | awk '
                    gsub("\r", "", $0) && tolower($1) ~ /x-url-delete/ {
                        delete_link=$2;
                        print "Delete command: curl --request DELETE " "\""delete_link"\"";
                        gsub(".*/", "", delete_link);
                        print "Delete token: " delete_link;
                    }
                    END { print "Download link: " $0; }
                '
                echo ""
                if test (count $argv) -gt 4
                    sleep 5
                end
            end
        case n
            return 1
        case '*'
            echo -e "\e[01;31mWrong input: '$upload_files'.\e[0m" >&2
            return 1
    end
end
