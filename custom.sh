#!/bin/bash
# Update ClamAV signatures, then scan the whole filesystem recursively
# and move anything ClamAV detects into a ./virus quarantine folder.
#
# I wrote this as a thin wrapper around ClamAV, not as an antivirus
# of my own. Every real decision, what counts as infected, lives in
# ClamAV and its signatures. This file only sets the order of the
# three commands and the place detections end up.
#
# Usage: ./custom.sh [--help]
# Exit codes: 0 = scan ran, nothing found. 1 = scan ran, infected
# files were found and moved (that is a working scan, not a failed
# one, and the summary line says which case you are in). 2 = the scan
# itself could not run or finish: a missing tool, a failed signature
# update when no signatures exist yet, a quarantine folder that
# cannot be created, or a clamscan error.
#
# The first version had no error handling at all: a failed step was
# followed by the next step anyway, and the script returned whatever
# clamscan returned, so an early failure could sit behind a normal
# looking finish. Each step below now checks its own result.

set -u

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: ./custom.sh [--help]"
    echo "Update ClamAV signatures, scan / recursively, and move detections into ./virus."
    echo "Exit codes: 0 clean, 1 infections found and quarantined, 2 scan could not run or finish."
    exit 0
fi
if [ $# -gt 0 ]; then
    echo "Error: unknown argument: $1" >&2
    exit 2
fi

# Both tools are needed. Naming the missing one up front beats a
# freshclam failure followed by a scan that was never going to work.
for tool in freshclam clamscan; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "Error: $tool is not installed or not on PATH" >&2
        exit 2
    fi
done

# I update first, on purpose. A scan that started before this
# finished would judge files with the signatures I already had.
# If the update fails but signatures already exist on the machine, I
# say so and scan with the older ones. If no signature database
# exists at all, clamscan cannot judge anything, so I stop instead
# of printing a clean looking result from an empty database.
if ! sudo freshclam; then
    if [ -d /var/lib/clamav ] && [ -n "$(ls -A /var/lib/clamav 2>/dev/null)" ]; then
        echo "Warning: freshclam failed; scanning with the existing signatures." >&2
    else
        echo "Error: freshclam failed and no existing signature database was found." >&2
        exit 2
    fi
fi

# The quarantine folder has to exist before the scan starts,
# because clamscan moves files into it during the scan, not after.
# I use -p so a second run in the same folder is not an error.
# virus is a relative path. The folder lands in whatever directory
# I ran the script from, owned by root because of sudo, and not
# next to the script itself.
if ! sudo mkdir -p virus; then
    echo "Error: could not create the ./virus quarantine folder." >&2
    exit 2
fi

# I pass one plain / as the target. An earlier version of this line
# used a pattern the shell expanded into the top level folders
# before clamscan saw it, which split one root scan into a list.
# --move is the part I stay careful with. A flagged system file
# moves like any other file, with no prompt, so the terminal output
# is my only record of what moved.
sudo clamscan -r --move=./virus /
scan_status=$?

# clamscan exit codes: 0 means nothing found, 1 means infections
# found, 2 means an error happened during the scan. I pass 0 and 1
# through with a summary that keeps them apart, and I turn 2 (and
# anything else unexpected) into this script's own error exit.
case "$scan_status" in
    0)
        echo "Scan finished: no infected files found."
        exit 0
        ;;
    1)
        echo "Scan finished: infected files were found and moved into ./virus."
        exit 1
        ;;
    *)
        echo "Error: clamscan reported an error (exit $scan_status); the scan may be incomplete." >&2
        exit 2
        ;;
esac
