#!/usr/bin/env bash
# twitch-rationalize-dirs.sh
#
# Walks /mnt/totem/media/audio/music/Twitch/<letter>/<artist>/ directories,
# determines the authoritative artist name from the majority of filenames in
# each directory (files are named "ArtistName (live) ..."), and prints the
# mv command needed to rename directories whose name differs from the majority
# artist name.
#
# THIS SCRIPT IS DRY-RUN ONLY. It prints proposed renames but executes nothing.

set -euo pipefail

ROOT="/mnt/totem/media/audio/music/Twitch"

# Counters for summary
total_dirs=0
needs_rename=0
no_files=0
ambiguous=0

for letter_dir in "$ROOT"/*/; do
    # Skip non-directories and known non-letter entries
    [[ -d "$letter_dir" ]] || continue
    letter=$(basename "$letter_dir")
    [[ "$letter" == "@eaDir" ]] && continue

    for artist_dir in "$letter_dir"*/; do
        [[ -d "$artist_dir" ]] || continue
        artist_folder=$(basename "$artist_dir")
        [[ "$artist_folder" == "@eaDir" ]] && continue

        (( total_dirs++ )) || true

        # Collect artist name candidates from filenames.
        # Expected pattern: "ArtistName (live) ..." — extract everything before " (live) ".
        declare -A counts=()
        file_count=0

        while IFS= read -r -d '' filename; do
            basename_f=$(basename "$filename")
            # Extract the part before " (live) "
            if [[ "$basename_f" == *" (live) "* || "$basename_f" == *" (live)"* ]]; then
                candidate="${basename_f%% (live)*}"
                (( counts["$candidate"]++ )) || true
                (( file_count++ )) || true
            fi
        done < <(find "$artist_dir" -maxdepth 1 -type f -print0)

        if (( file_count == 0 )); then
            echo "# SKIP (no matching files): $artist_dir"
            (( no_files++ )) || true
            unset counts
            continue
        fi

        # Find the candidate with the highest count
        best_name=""
        best_count=0
        for candidate in "${!counts[@]}"; do
            if (( counts["$candidate"] > best_count )); then
                best_count=${counts["$candidate"]}
                best_name="$candidate"
            fi
        done

        # Check for ambiguity: another candidate with the same count
        is_ambiguous=0
        for candidate in "${!counts[@]}"; do
            if [[ "$candidate" != "$best_name" ]] && (( counts["$candidate"] == best_count )); then
                is_ambiguous=1
                break
            fi
        done

        if (( is_ambiguous )); then
            echo "# AMBIGUOUS (tie in name counts, folder unchanged): $artist_dir"
            for candidate in "${!counts[@]}"; do
                echo "#   '$candidate' appears ${counts[$candidate]} time(s)"
            done
            (( ambiguous++ )) || true
            unset counts
            continue
        fi

        # Compare majority name to current folder name
        if [[ "$best_name" != "$artist_folder" ]]; then
            new_path="${letter_dir}${best_name}"
            echo "mv -- $(printf '%q' "$artist_dir") $(printf '%q' "$new_path")"
            (( needs_rename++ )) || true
        fi

        unset counts
    done
done

echo ""
echo "# Summary:"
echo "#   Total artist dirs scanned : $total_dirs"
echo "#   Proposed renames          : $needs_rename"
echo "#   Skipped (no files)        : $no_files"
echo "#   Skipped (ambiguous tie)   : $ambiguous"
