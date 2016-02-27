#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

#
# Based on code, examples and ideas from:
#  https://bugzilla.redhat.com/show_bug.cgi?id=524727
#  http://roosbertl.blogspot.de/2012/12/centos6-disk-encryption-with-remote.html
#  https://bitbucket.org/bmearns/dracut-crypt-wait
#  http://forum.ubuntuusers.de/topic/script-verschluesseltes-system-via-ssh-freisch/
#  debian initramfs-tools scripts and dracut scripts
#
#
# Start dropbear sshd to be able to send password to waiting cryptsetup
#  (from "crypt" module) remotely, or for any other kind of net-debug of dracut.
#
# Boot sshd will be started with:
#  port: ${dropbear_port} (dracut.conf) or 2222
#  user: root
#  host key: ${dropbear_rsa_key} (dracut.conf) or generated (fingerprint echoed)
#  client key(s): ${dropbear_acl} (dracut.conf) or /root/.ssh/authorized_keys
#  no password auth, no port forwarding

## For an explanation of dracut modules and their format please see:
##      https://www.kernel.org/pub/linux/utils/boot/dracut/dracut.html

# This module directory 60dropbear should be placed in /usr/lib/dracut/modules.d
# it will be picked up by dracut if package dropbear is installed
# for centos dropbear is in epel
# to activate network in initrd add boot parameter like 
# rd.neednet=1 ip=dhcp
# to /etc/default/grub


check() {
        type -P dropbear >/dev/null || return 1
        return 0
}

depends() {
        echo network
        return 0
}

install() {

        dracut_dropbear_config_file="/etc/dracut.conf.d/dropbear.conf"
        . ${dracut_dropbear_config_file}

        ## Check for dracut.conf parameters
        if [ -z "${dropbear_port}" ]
        then
          dropbear_port=2222
          dinfo "dropbear_port not set in ${dracut_dropbear_config_file}, using default (${dropbear_port})"
cat >> ${dracut_dropbear_config_file} <<EOF
#droppear sshd listen port
dropbear_port=${dropbear_port}

EOF

        fi

        if [ -z "${dropbear_rsa_key}" ]
        then 
          ## 
          dropbear_rsa_key="/etc/dropbear/dropbear_rsa_host_key"
          dinfo "dropbear_rsa_key not set in ${dracut_dropbear_config_file}, using default (${dropbear_rsa_key})"
cat >> ${dracut_dropbear_config_file} <<EOF
#droppear sshd rsa host key file (will be generated if file does not exist)
dropbear_rsa_key=${dropbear_rsa_key}

EOF
        fi

        if [ -z "${dropbear_acl}" ]
        then
          dropbear_acl="/root/.ssh/authorized_keys"
          dinfo "dropbear_acl not set in ${dracut_dropbear_config_file}, using default location (${dropbear_acl})"
cat >> ${dracut_dropbear_config_file} <<EOF
#droppear sshd authorized puplic key file for login (no password logins are allowed, use ssh-copy-id to deploy key before)
dropbear_acl=${dropbear_acl}

EOF
        fi

        if [ ! -f ${dropbear_rsa_key} ]
        then
          #$moddir/keygen.sh ${dropbear_rsa_key}
          dropbearkey -t rsa -f "${dropbear_rsa_key}"
        fi


        dracut_install dropbear
        dracut_install pkill
        dracut_install /lib64/libnss_files.so.2
        inst ${dracut_dropbear_config_file} /etc/dropbear/dropbear.conf
        inst ${dropbear_acl} /root/.ssh/authorized_keys
        inst ${dropbear_rsa_key} ${dropbear_rsa_key}
        inst_hook initqueue/online 50 "$moddir/dropbear-start.sh"
        inst_hook cleanup 01 "$moddir/dropbear-stop.sh"

        inst_script "$moddir/unlock.sh" /bin/unlock           

}
