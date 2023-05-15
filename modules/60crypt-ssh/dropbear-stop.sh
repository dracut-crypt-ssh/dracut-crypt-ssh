#!/bin/sh

if [ -r /tmp/legacy_tiocsti.default ] && [ -w /proc/sys/dev/tty/legacy_tiocsti ]; then
  cat /tmp/legacy_tiocsti.default > /proc/sys/dev/tty/legacy_tiocsti
fi

[ -f /tmp/dropbear.pid ] || exit 0
read main_pid < /tmp/dropbear.pid
kill -STOP ${main_pid} 2>/dev/null
pkill -P ${main_pid}
kill ${main_pid} 2>/dev/null
kill -CONT ${main_pid} 2>/dev/null
