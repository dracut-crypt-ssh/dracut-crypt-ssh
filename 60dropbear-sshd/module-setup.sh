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
	local tmp_file

	dracut_install /lib/libnss_files.so.2
	inst $(which dropbear) /sbin/dropbear

	# Don't bother with DSA, as it's either much more fragile or broken anyway
	tmp_file=
	[[ -z "$dropbear_rsa_key" ]] && {
		# I assume ssh-keygen must be better at producing good rsa keys than
		#  dropbearkey, so use that one. It's interactive-only, hence some hacks.
		dropbear_rsa_key=$(mktemp)
		tmp_file=$(mktemp)
		rm -f ${dropbear_rsa_key}
		ssh-keygen -q -t rsa -b 2048 -f "${dropbear_rsa_key}" </dev/null >${tmp_file} 2>&1
		[[ ! -f "${dropbear_rsa_key}" || ! -f "${dropbear_rsa_key}".pub ]] && {
			dfatal "Failed to generate ad-hoc ssh key, see: ${tmp_file}"
			rm -f "${dropbear_rsa_key}"{,.pub}
			return 255
		}

		dinfo "Generated ad-hoc ssh key"
		dinfo "  fingerprint: $(ssh-keygen -l -f "${dropbear_rsa_key}".pub)"
		dinfo "  bubblebabble: $(ssh-keygen -B -f "${dropbear_rsa_key}".pub)"
		rm -f "${dropbear_rsa_key}".pub
		tmp_file=${dropbear_rsa_key}

		# Might benefit from *securely* creating such tempfiles.
		mv "${dropbear_rsa_key}"{,.tmp}
		# Oh, wow, another tool that doesn't have "batch mode" in the same script.
		# It's deeply concerning that security people don't seem to grasp such basic concepts.
		dropbearconvert openssh dropbear "${dropbear_rsa_key}"{.tmp,} >/dev/null 2>&1\
			|| { dfatal "dropbearconvert failed"; rm -f "${dropbear_rsa_key}"{,.tmp}; return 255; }
		rm -f "${dropbear_rsa_key}".tmp
	}
	inst "${dropbear_rsa_key}" /etc/dropbear/host_key
	[[ -n "${tmp_file}" ]] && rm -f "${tmp_file}"

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
	echo >>"${tmp_file}" "exec /sbin/dropbear"\
		"-E -m -s -j -k -p ${dropbear_port} -r /etc/dropbear/host_key"
	chmod +x "${tmp_file}"
	inst_hook initqueue 20 "${tmp_file}"
	rm -f "${tmp_file}"

	return 0
}
