#!/usr/bin/bash

file_not_found_msg () {
    printf "%s not found. Please generate the VSCode build files via UE and then run this script from the project root directory." "$1"
}

if [ ! -d "${PWD}/.vscode" ]; then
    file_not_found_msg "${PWD}/.vscode"
    exit 1
fi

# Must be run from the project root directory.
PROJECT=${PWD##*/}

BASE_COMMANDS_DIR="${PWD}/.vscode/compileCommands_${PROJECT}"
if [ ! -d "$BASE_COMMANDS_DIR" ]; then
    file_not_found_msg "$BASE_COMMANDS_DIR"
    exit 1
fi

BASE_COMMANDS="${BASE_COMMANDS_DIR}.json"
if [ ! -f "$BASE_COMMANDS" ]; then
    file_not_found_msg "$BASE_COMMANDS"
    exit 1
fi

WSL_COMMANDS="${PWD}/compile_commands.json"

if [ -e "$WSL_COMMANDS" ]; then
    printf "Removing existing %s\n" "$WSL_COMMANDS"
    rm -rf "$WSL_COMMANDS"
fi

WSL_COMMANDS_DIR="${BASE_COMMANDS_DIR}_WSL"

if [ -e "$WSL_COMMANDS_DIR" ]; then
    printf "Removing existing %s\n" "$WSL_COMMANDS_DIR"
    rm -rf "$WSL_COMMANDS_DIR"
fi

printf "Generating %s..." "$WSL_COMMANDS"

cp "$BASE_COMMANDS" "$WSL_COMMANDS"

sed -i -e 's/\r//g' -e 's/C:/\/mnt\/c/g' -e 's/\\\\/\//g' "$WSL_COMMANDS"

update_wsl_commands () {
    FILE=""
    IN_ARGS=false
    while IFS="" read -r p || [ -n "$p" ]; do
        KEY=$(printf "%s" "$p" | awk -F ': ' '{print $1}' | xargs | sed 's/,*$//g' )
        if [ "$KEY" = "file" ]; then
            FILE=$(printf "%s" "$p" | awk -F ': ' '{ print $2 }' | xargs | sed 's/,*$//g')
        elif [ "$KEY" = "]" ] && [ "$IN_ARGS" = true ]; then
            IN_ARGS=false
        elif [ "$IN_ARGS" = true ] && [[ "$KEY" == "@"* ]]; then
            printf "\"clang++\", \"-std=c++20\", \"-ferror-limit=0\", \"-Wall\", \"-Wextra\", \"-Wpedantic\", \"-Wshadow-all\", \"-Wno-unused-parameter\", \"$FILE\", \"$KEY\"\n"
            continue
        elif [ "$IN_ARGS" = true ]; then
            continue
        elif [ "$KEY" = "arguments" ]; then
            IN_ARGS=true
        fi
        printf "%s\n" "$p"
    done < "$WSL_COMMANDS"
}

UPDATED_WSL_COMMANDS_CONTENT=$(update_wsl_commands)
printf "%s\n" "$UPDATED_WSL_COMMANDS_CONTENT" > "$WSL_COMMANDS"
sed -i -e "s|$(basename "$BASE_COMMANDS_DIR")|$(basename "$WSL_COMMANDS_DIR")|g" "$WSL_COMMANDS"

printf "done\n"
printf "Generating %s..." "$WSL_COMMANDS_DIR"

mkdir "$WSL_COMMANDS_DIR"

gen_wsl_commands_dir () {
    FILENAME=$(basename "$1")
    sed -e 's/\/FI/-I/g' \
        -e 's/\/I/-I/g' \
        -e 's/C:/\/mnt\/c/g' \
        -e 's/\\/\//g' "$1" > "${WSL_COMMANDS_DIR}/${FILENAME}"
}

find "$BASE_COMMANDS_DIR" -type f | while read file; do gen_wsl_commands_dir "$file"; done

printf "done\n"
exit 0
