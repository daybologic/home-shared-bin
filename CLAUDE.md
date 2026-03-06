# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal collection of standalone utility scripts across multiple languages (bash, Perl, Python, Ruby, PHP). Scripts are placed directly in the repo root and are intended to live on `$PATH`. There is no build system or package manager.

## Running Tests

Perl tests live in `t/` and use the standard Perl TAP harness:

```sh
# Run a specific test suite
perl -Ilib t/TestSuiteName.t

# Run a specific test method within a suite
perl -Ilib t/TestSuiteName.t testMethodName

# Hunt for intermittent failures (loops until failure, supports TEST_UNIQUE env var for random seeds)
perl-intermittent-test TestSuiteName testMethodName
```

The `perl-intermittent-test` script randomises a `TEST_UNIQUE` environment variable on each iteration and runs with `TEST_VERBOSE=1`.

## Code Conventions

**Bash scripts** use `set -xeuo pipefail` (or a subset). New bash scripts should follow this pattern.

**par2 workflow** (`par2-write`, `par2-verify`, `par2-delete`): The standard integrity chain is GPG signature → SHA512 checksum → PAR2 verification. `par2-write` generates parity files and checksums in parallel using `&`/`wait`, then calls `sign-chksum` to sign. `par2-verify` (Perl) verifies in that same order: signature, checksum, then par2. The `-t` flag on `par2-verify` copies to a temp dir first (`indirect()`) before verifying.

**Battery guard**: Scripts that do heavy encoding (`wav-to-mp3`, `downsample-4k-1080p`, `twitch-speed-fix-mp3`, etc.) check `termux-battery-low` before starting work, exiting early if battery is insufficient.

**Parallelism**: Long-running per-file operations are commonly backgrounded with `&` and collected with `wait`.

## Key Scripts by Category

- **Audio/video conversion**: `wav-to-mp3`, `mp3-to-wav`, `mkv-to-mp3`, `webm-to-mp3`, `wmv-to-mp3`, `wav-to-ogg`, `raw-audio-to-wav`, `mp3-trim-lead`, `twitch-speed-fix-mp3`, `twitch-speed-unfix-mp3`, `downsample-4k-1080p`, `handbrake-run`, `handbrake-alternative`, `youtube-download`
- **PAR2/integrity**: `par2-write` (all files), `par2-write-vol` (single `volume.tar`), `par2-verify`, `par2-delete`
- **GPG**: `gpg-load-sig` (warms up GPG agent), `commitsigs.py` (Mercurial extension for signing commits)
- **Mercurial**: `hgdiff`, `hgexport`, `hgfindcommit`, `hgoutall`, `hgmybranches`, `hg-short-changeset`
- **Git**: `git-gc` (aggressive GC), `git-mirror-remotes` (checkout all remote tracking branches)
- **Text utilities**: `lc` / `uc` (Perl, lowercase/uppercase CLI args), `splitpatch.rb`
- **Termux**: `termux-battery-low` (exit code signals battery state), `termux-url-opener`

## External Dependencies

Scripts assume the following tools are available on `$PATH` as needed: `par2`, `gpg`, `sha512sum` (and other shaXXXsum variants), `sox`, `lame`, `ffmpeg`, `yt-dlp`, `HandBrakeCLI`, `wodim`, `beep`, `uuid`.

Perl scripts may require CPAN modules; `par2-verify` uses `File::Copy::Recursive` and `File::Temp`.
