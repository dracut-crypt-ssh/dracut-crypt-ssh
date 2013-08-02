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
#  # See what's on the console
#  cat /dev/vcs1
#  # Read and send password to console
#  auth
#

check() {
	return 0
}

depends() {
	echo network
	return 0
}

install() {
	local tmp_file tmp_fifo

	dracut_install /lib/libnss_files.so.2
	inst $(which dropbear) /sbin/dropbear

	# Don't bother with DSA, as it's either much more fragile or broken anyway
	tmp_file=
	[[ -z "${dropbear_rsa_key}" ]] && {
		# I assume ssh-keygen must be better at producing good rsa keys than
		#  dropbearkey, so use that one. It's interactive-only, hence some hacks.
		dropbear_rsa_key=$(mktemp)
		tmp_file=$(mktemp)
		rm -f "${dropbear_rsa_key}"
		tmp_fifo=$(mktemp) && rm -f "${tmp_fifo}" && mkfifo -m0600 "${tmp_fifo}"
		script -q -c "ssh-keygen -q -t rsa -b 2048 -f '${dropbear_rsa_key}'; echo >'${tmp_fifo}'"\
			</dev/null >"${tmp_file}" 2>&1
		: <"${tmp_fifo}"; rm -f "${tmp_fifo}"
		[[ -f "${dropbear_rsa_key}" && -f "${dropbear_rsa_key}".pub ]] || {
			dfatal "Failed to generate ad-hoc ssh key, see: ${tmp_file}"
			rm -f "${dropbear_rsa_key}"{,.pub}
			return 255
		}

		dinfo "Generated ad-hoc ssh key for dropbear on boot"
		rm -f "${tmp_file}"
		tmp_file=${dropbear_rsa_key}

		# Might benefit from *securely* creating such tempfiles.
		mv "${dropbear_rsa_key}"{,.tmp}
		# Oh, wow, another tool that doesn't have "batch mode" in the same script.
		# It's deeply concerning that security people don't seem to grasp such basic concepts.
		dropbearconvert openssh dropbear "${dropbear_rsa_key}"{.tmp,} >/dev/null 2>&1\
			|| { dfatal "dropbearconvert failed"; rm -f "${dropbear_rsa_key}"{,.tmp}; return 255; }
		rm -f "${dropbear_rsa_key}".tmp
	}
	local key_fp=$(ssh-keygen -l -f "${dropbear_rsa_key}".pub)
	local key_bb=$(ssh-keygen -B -f "${dropbear_rsa_key}".pub)
	dinfo "Boot SSH key parameters:"
	dinfo "  fingerprint: ${key_fp}"
	dinfo "  bubblebabble: ${key_bb}"
	inst "${dropbear_rsa_key}" /etc/dropbear/host_key
	[[ -n "${tmp_file}" ]] && rm -f "${tmp_file}"{,.pub}

	[[ -z "${dropbear_acl}" ]] && dropbear_acl=/root/.ssh/authorized_keys
	inst "${dropbear_acl}" /root/.ssh/authorized_keys

	# glibc needs only /etc/passwd with "root" entry (no group or shadow), which
	#  should be provided by 99base; /bin/sh will be run regardless of /etc/shells presence.
	# It can do without nsswitch.conf, resolv.conf or whatever other stuff it usually has.

	# Helper to safely send password to cryptsetup on /dev/console without echoing it.
	# Yeah, dracut modules shouldn't compile stuff, but I'm not packaging that separately.
	tmp_file=$(mktemp)
	gcc -std=gnu99 -O2 -Wall "$moddir"/auth.c -o "${tmp_file}"
	inst "${tmp_file}" /bin/console_auth
	rm -f "${tmp_file}"

	[[ -z "${dropbear_port}" ]] && dropbear_port=2222
	tmp_file=$(mktemp)
	echo >"${tmp_file}" "#!/bin/sh"
	echo >>"${tmp_file}" "info \"Starting Dropbear SSH\""
	echo >>"${tmp_file}" "info \"  sshd key fingerprint: ${key_fp}\""
	echo >>"${tmp_file}" "info \"  sshd key bubblebabble: ${key_bb}\""
	echo >>"${tmp_file}" "/sbin/dropbear"\
		"-E -m -s -j -k -p ${dropbear_port} -r /etc/dropbear/host_key"
	echo >>"${tmp_file}" 'info "Dropbear sshd died (exit code: $?)"'
	chmod +x "${tmp_file}"

	# Dracut only runs *.sh files in initqueue dir
	mv "${tmp_file}"{,.sh}
	inst_hook initqueue 20 "${tmp_file}".sh
	rm -f "${tmp_file}".sh

	return 0
}
