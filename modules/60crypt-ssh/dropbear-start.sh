#!/bin/sh

. /etc/crypt-ssh.conf

# Linux >= 6.2 allows the TIOCSTI ioctl to be disabled by default;
# console_auth requires it, so re-enable using the provided sysctl
if [ -w /proc/sys/dev/tty/legacy_tiocsti ]; then
  cp /proc/sys/dev/tty/legacy_tiocsti /tmp/legacy_tiocsti.default >/dev/null 2>&1
  echo 1 > /proc/sys/dev/tty/legacy_tiocsti
fi

[ -f /tmp/dropbear.pid ] && kill -0 $(cat /tmp/dropbear.pid) 2>/dev/null || {
  info "sshd port: ${dropbear_port}"
  for keyType in $keyTypes; do
    eval fingerprint=\$dropbear_${keyType}_fingerprint
    eval bubble=\$dropbear_${keyType}_bubble
    info "Boot SSH ${keyType} key parameters: "
    info "  fingerprint: ${fingerprint}"
    info "  bubblebabble: ${bubble}"
  done

  /sbin/dropbear -s -j -k -p ${dropbear_port} -P /tmp/dropbear.pid
  [ $? -gt 0 ] && info 'Dropbear sshd failed to start'
}
