#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin

[ -f /tmp/dropbear.pid ] || exit 0
read main_pid </tmp/dropbear.pid ;
kill -STOP ${main_pid} >/dev/null 2>&1
pkill -P ${main_pid} >/dev/null 2>&1
kill ${main_pid} >/dev/null 2>&1
kill -CONT ${main_pid} >/dev/null 2>&1

[ -f /tmp/dropbear.pid ] || exit 0
pkill -9 -P ${main_pid} >/dev/null 2>&1
kill -9 ${main_pid} >/dev/null 2>&1

[ -f /tmp/dropbear.pid ] || exit 0
rm -f /tmp/dropbear.pid
