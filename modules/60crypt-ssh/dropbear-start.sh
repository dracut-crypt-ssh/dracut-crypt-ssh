#!/bin/sh

. /etc/crypt-ssh.conf

if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
  ln -s /var/run/sshd.pid /tmp/dropbear.pid
  [ ! -d /var/empty/sshd ] && mkdir -p /var/empty/sshd
  grep -q ^sshd: /etc/passwd || \
      echo 'sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin' >> /etc/passwd
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

  if [[ "${crypt_ssh_use_sshd}" = "yes" ]]; then
    /sbin/sshd -p ${dropbear_port}
    [ $? -gt 0 ] && info 'sshd failed to start'
  else
    /sbin/dropbear -s -j -k -p ${dropbear_port} -P /tmp/dropbear.pid
    [ $? -gt 0 ] && info 'Dropbear sshd failed to start'
  fi
}
