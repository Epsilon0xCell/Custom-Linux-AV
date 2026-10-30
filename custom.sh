#!/bin/bash
# Update ClamAV signatures, then scan the whole filesystem recursively
# and move anything ClamAV detects into a ./virus quarantine folder.
sudo freshclam
sudo mkdir -p virus
sudo clamscan -r --move=./virus /
