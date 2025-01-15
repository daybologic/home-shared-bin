#!/bin/bash

# Define the target directory (default is current directory if not specified)
TARGET_DIR=${1:-$(pwd)}

# Maximum filename length for Joliet (64 characters)
MAX_FILENAME_LENGTH=64

# Function to sanitize filenames
sanitize_filename() {
    local original_name="$1"
    
    # Extract the base name and extension
    local base_name="${original_name%.*}" # Filename without extension
    local extension="${original_name##*.}" # Extension (including hidden files)
    
    # If there's no extension, treat the whole name as base_name
    if [ "$base_name" = "$original_name" ]; then
        base_name="$original_name"
        extension=""
    else
        extension=".$extension"
    fi

    # Convert base name to lowercase and replace invalid characters with underscores
    base_name=$(echo "$base_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]//g')
    
    # Truncate the base name to fit within the total length limit (64 - length of extension)
    local truncated_length=$((MAX_FILENAME_LENGTH - ${#extension}))
    base_name="${base_name:0:$truncated_length}"
    
    # Combine the sanitized base name and the extension
    echo "$base_name$extension"
}

# Process each file in the target directory
cd "$TARGET_DIR" || { echo "Directory not found: $TARGET_DIR"; exit 1; }

for file in *; do
    # Skip directories
    if [ -d "$file" ]; then
        continue
    fi

    original_name="$file"
    sanitized_name=$(sanitize_filename "$original_name")

    # If the sanitized name is different, rename the file
    if [ "$original_name" != "$sanitized_name" ]; then
        # Ensure no overwriting: append a numeric suffix if the filename exists
        counter=1
        base_name="${sanitized_name%.*}"
        extension="${sanitized_name##*.}"
        [ "$base_name" = "$sanitized_name" ] && extension="" # Handle files without extension
        extension=".$extension"

        while [ -e "$sanitized_name" ]; do
            sanitized_name="${base_name}_$counter$extension"
            counter=$((counter + 1))
        done

        echo "Renaming: '$original_name' -> '$sanitized_name'"
        mv -i "$original_name" "$sanitized_name"
    fi
done

echo "File renaming completed for Joliet/Rockridge compatibility."
