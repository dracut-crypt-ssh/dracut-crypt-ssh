#!/bin/bash

#
# Based on code, examples and ideas from:
#  https://bugzilla.redhat.com/show_bug.cgi?id=524727
#  http://roosbertl.blogspot.de/2012/12/centos6-disk-encryption-with-remote.html
#  https://bitbucket.org/bmearns/dracut-crypt-wait
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
#
# In dropbear shell:
#  # See what's on the console ("cat /dev/vcs1" should work too)
#  console_peek
#  # Read and send password to console
#  console_auth
#

check() {
	return 0
}

depends() {
	echo network
	return 0
}

install() {
	local tmp=$(mktemp -d --tmpdir dracut-crypt-sshd.XXXX)

	dracut_install pkill setterm /lib/libnss_files.so.2
	inst $(which dropbear) /sbin/dropbear
	inst "$moddir"/console_peek.sh /bin/console_peek

	# Don't bother with DSA, as it's either much more fragile or broken anyway
	[[ -z "${dropbear_rsa_key}" ]] && {
		# I assume ssh-keygen must be better at producing good rsa keys than
		#  dropbearkey, so use that one. It's interactive-only, hence some hacks.
		dropbear_rsa_key="$tmp"/key
		rm -f "${dropbear_rsa_key}"
		mkfifo "$tmp"/keygen.fifo
		script -q -c "ssh-keygen -q -t rsa -f '${dropbear_rsa_key}'; echo >'${tmp}/keygen.fifo'"\
			/dev/null </dev/null >"$tmp"/keygen.log 2>&1
		: <"$tmp"/keygen.fifo
		[[ -f "${dropbear_rsa_key}" && -f "${dropbear_rsa_key}".pub ]] || {
			dfatal "Failed to generate ad-hoc rsa key, see: ${tmp}/keygen.log"
			return 255
		}
		dinfo "Generated ad-hoc rsa key for dropbear sshd in initramfs"

		# Oh, wow, another tool that doesn't have "batch mode" in the same script.
		# It's deeply concerning that security people don't seem to grasp such basic concepts.
		mv "${dropbear_rsa_key}"{,.tmp}
		dropbearconvert openssh dropbear "${dropbear_rsa_key}"{.tmp,} >/dev/null 2>&1\
			|| { dfatal "dropbearconvert failed"; rm -rf "$tmp"; return 255; }
	}

	local key_fp=$(ssh-keygen -l -f "${dropbear_rsa_key}".pub)
	local key_bb=$(ssh-keygen -B -f "${dropbear_rsa_key}".pub)
	dinfo "Boot SSH key parameters:"
	dinfo "  fingerprint: ${key_fp}"
	dinfo "  bubblebabble: ${key_bb}"
	inst "${dropbear_rsa_key}" /etc/dropbear/host_key

	[[ -z "${dropbear_acl}" ]] && dropbear_acl=/root/.ssh/authorized_keys
	inst "${dropbear_acl}" /root/.ssh/authorized_keys

	# glibc needs only /etc/passwd with "root" entry (no group or shadow), which
	#  should be provided by 99base; /bin/sh will be run regardless of /etc/shells presence.
	# It can do without nsswitch.conf, resolv.conf or whatever other stuff it usually has.

	# Helper to safely send password to cryptsetup on /dev/console without echoing it.
	# Yeah, dracut modules shouldn't compile stuff, but I'm not packaging that separately.
	gcc -std=gnu99 -O2 -Wall "$moddir"/auth.c -o "$tmp"/auth
	inst "$tmp"/auth /bin/console_auth

	# Generate hooks right here, with parameters baked-in
	[[ -z "${dropbear_port}" ]] && dropbear_port=2222
	cat >"$tmp"/sshd_run.sh <<EOF
#!/bin/sh
[ -f /tmp/dropbear.pid ]\
		&& kill -0 \$(cat /tmp/dropbear.pid) 2>/dev/null || {
	info 'sshd port: ${dropbear_port}'
	info 'sshd key fingerprint: ${key_fp}'
	info 'sshd key bubblebabble: ${key_bb}'
	/sbin/dropbear -E -m -s -j -k -p ${dropbear_port}\
		-r /etc/dropbear/host_key -d - -P /tmp/dropbear.pid
	[ \$? -gt 0 ] && info 'Dropbear sshd failed to start'
}
EOF
	cat >"$tmp"/sshd_kill.sh <<EOF
#!/bin/sh
[ -f /tmp/dropbear.pid ] || exit 0
read main_pid </tmp/dropbear.pid
kill -STOP \${main_pid} 2>/dev/null
pkill -P \${main_pid}
kill \${main_pid} 2>/dev/null
kill -CONT \${main_pid} 2>/dev/null
EOF
	chmod +x "$tmp"/sshd_{run,kill}.sh
	inst_hook initqueue 20 "$tmp"/sshd_run.sh
	inst_hook cleanup 05 "$tmp"/sshd_kill.sh

	rm -rf "$tmp"
	return 0
}
