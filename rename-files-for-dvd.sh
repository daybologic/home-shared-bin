#!/bin/bash

# Define the target directory (default is current directory if not specified)
TARGET_DIR=${1:-$(pwd)}

# Maximum filename length for Joliet (64 characters)
MAX_FILENAME_LENGTH=64

# Function to sanitize filenames
sanitize_filename() {
    local original_name="$1"
    
    # Convert to lowercase
    local sanitized_name=$(echo "$original_name" | tr '[:upper:]' '[:lower:]')
    
    # Replace invalid characters with underscores
    sanitized_name=$(echo "$sanitized_name" | sed 's/[^a-z0-9.-]//g')
    
    # Truncate to Joliet's 64-character limit
    sanitized_name="${sanitized_name:0:$MAX_FILENAME_LENGTH}"
    
    # If the sanitized name is empty, assign a default name
    [ -z "$sanitized_name" ] && sanitized_name="unnamed_file"
    
    echo "$sanitized_name"
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
        [ "$base_name" = "$sanitized_name" ] && extension="" # Handle files with no extension
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
