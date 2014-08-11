#!/bin/sh
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin

info "start-dropbear was called with parameter: $@"
#above could be helpful to bind to one specific interface
#with ip kernel parameter we can set the interface name
#rd.neednet=1 ip=192.168.1.110::192.168.1.254:255.255.255.0:localhost:enp0s3:none 
#this script gets called with parameter enp0s3 then

[ -f /tmp/dropbear.pid ] && {
info "dropbear already running, calling kill-dropbear.sh first"
/usr/lib/dracut/hooks/cleanup/01-kill-dropbear.sh ; }

[ -f /etc/dropbear/dropbear.conf ] && . /etc/dropbear/dropbear.conf

[ -z "${dropbear_port}" ] && dropbear_port=2222
[ -z "${dropbear_rsa_key}" ] && dropbear_rsa_key=/etc/dropbear/dropbear_rsa_host_key

[ ! -f ${dropbear_rsa_key} ] && { \
info "dropbear sshd: host key file ${dropbear_rsa_key} not found in initrd, fatal exiting."; exit 0; }

info "Starting dropbear sshd on port: ${dropbear_port}"
dropbear -E -m -s -j -k -p ${dropbear_port}\
                -r "${dropbear_rsa_key}" -P /tmp/dropbear.pid

[ $? -gt 0 ] && info 'Dropbear sshd failed to start'

#debug
#emergency_shell -n start-dropbear "Break from 50-start-dropbear.sh in initqueue/online"
#info "continue 50-start-dropbear.sh"

exit 0
