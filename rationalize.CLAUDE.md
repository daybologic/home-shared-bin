# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Two bash scripts for maintaining a large Twitch live-recording music archive at `/mnt/totem/media/audio/music/Twitch/`. The archive is structured as `<root>/<letter>/<artist>/` (e.g. `.../Twitch/a/AlanFullmerMusic/`). Files within each artist directory follow the naming convention:

```
ArtistName (live) YYYY-MM-DD HH_MM-ID[-suffix].ext
```

where `.ext` is `.mp3` or `.mkv`. The two scripts are intended to be run in sequence after new content is added.

## Scripts

### `twitch-rationalize-dirs.sh`

Dry-run only. Scans every artist directory, tallies the artist name prefix (everything before ` (live)`) across all files, and **prints `mv` commands** to stdout for any directory whose name differs from the majority file prefix. Ambiguous ties are flagged as comments rather than silently picked.

```bash
# Review proposals
bash twitch-rationalize-dirs.sh

# Execute proposals
bash twitch-rationalize-dirs.sh | grep '^mv' | bash
```

### `twitch-rationalize-filenames.sh`

Dry-run only. Scans every file in every artist directory and writes `mv` commands to `propose-renames.sh` (in the current working directory) for any file whose artist name prefix doesn't match the containing folder name. Run this **after** rationalizing directories.

```bash
# Generate proposals
bash twitch-rationalize-filenames.sh

# Review, then execute
bash propose-renames.sh
```

`propose-renames.sh` is written with `set -euo pipefail` and will halt on the first error.

## Key Implementation Details

- Both scripts skip `@eaDir` entries (Synology NAS metadata directories).
- Artist name extraction uses bash parameter expansion on the ` (live)` delimiter — no external tools.
- Files without ` (live)` in their name are skipped and counted separately.
- All paths passed to `mv` are shell-quoted via `printf '%q'` to handle spaces and special characters safely.
- Arithmetic uses `(( ... )) || true` to avoid `set -e` tripping on a zero result.
