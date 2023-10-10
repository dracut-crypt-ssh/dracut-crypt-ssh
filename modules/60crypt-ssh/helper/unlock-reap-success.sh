#!/bin/sh

pkill systemd-cryptsetup || pkill cryptroot-ask
# Some versions of `pkill` need -f:
# pkill: pattern that searches for process name longer than 15 characters will result in zero matches
# Try `pkill -f' option to match against the complete command line.
pkill -f systemd-cryptsetup || pkill -f cryptroot-ask

