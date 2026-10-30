#!/bin/bash
# Update ClamAV signatures, then scan the whole filesystem recursively
# and move anything ClamAV detects into a ./virus quarantine folder.
#
# I wrote this as a thin wrapper around ClamAV, not as an antivirus
# of my own. Every real decision, what counts as infected, lives in
# ClamAV and its signatures. This file only sets the order of the
# three commands and the place detections end up.
#
# I have no error handling here, and that shapes what a run means.
# If a step fails, the next step still runs, and the exit code the
# script returns is the exit code of the clamscan line at the end.
# An early failure can sit behind a normal looking finish.

# I update first, on purpose. A scan that started before this
# finished would judge files with the signatures I already had.
# If the update fails, the scan below still runs with those older
# signatures, and only the freshclam output on screen says so.
sudo freshclam

# The quarantine folder has to exist before the scan starts,
# because clamscan moves files into it during the scan, not after.
# I use -p so a second run in the same folder is not an error.
# virus is a relative path. The folder lands in whatever directory
# I ran the script from, owned by root because of sudo, and not
# next to the script itself.
sudo mkdir -p virus

# I pass one plain / as the target. An earlier version of this line
# used a pattern the shell expanded into the top level folders
# before clamscan saw it, which split one root scan into a list.
# --move is the part I stay careful with. A flagged system file
# moves like any other file, with no prompt, and I pass no log
# option here, so the terminal output is my only record of what
# moved. clamscan returns 1 when it finds something, so a caller
# that treats any non zero exit as failure reads a scan that
# worked and found a problem as a failed run.
sudo clamscan -r --move=./virus /
