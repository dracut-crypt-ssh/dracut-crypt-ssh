dracut-earlyssh
---------------

[Dracut initramfs](https://dracut.wiki.kernel.org/index.php/Main_Page) module
to start [Dropbear sshd](https://matt.ucc.asn.au/dropbear/dropbear.html)
on early boot to enter encryption passphrase remotely or just
connect and debug.

There are a number of reasons why you would want to do this:
 1. It provides a way of entering the encryption keys for a number of servers without
    console switching
 2. It allows remote booting of (externally-hosted) encrypted servers

This is based heavily on the work of others, in particular mk-fg.  The major changes between
this version are: adaption for RHEL 6 and the old version of dracut installed there;
additional options for replicated the system host key or a user provided one (see the
"dropbear_rsa_key" option, documented in earlyssh.conf); an additional utility (unlock)
for automating the unlock process.  Finally, there is a RPM spec file which should make
it very easy to deploy (and doesn't introduce a runtime dependency on a compiler).

Users are strictly authenticated by provided SSH public keys. These can be either:
root's ~/.ssh/authorized_keys or a custom file ("dropbear_acl" option).  Depending
on your environment, it may make sense to make the preboot authorized_keys file
quite different to the normal one.

See dropbear(8) manpage for full list of supported restrictions there (which are
fairly similar to openssh).  If using in combination with the unlock utility (see below), a useful restriction may be to make /bin/unlock a 'forced command' in SSH.


### Obligatory warning

Please think about your
[threat model](https://en.wikipedia.org/wiki/Threat_model) first,
and security/usability trade-off second.

This module is very unlikely to help at all against malicious hosting provider
or whatever three-letter-agency that will coerce it into cooperation, should it
take interest in your poor machine - they can just extract keys from RAM image
(especially if it's a virtualized container), backdoor kernel/initramfs and
force a reboot, or do whatever else to get encryption keys via hardware/backdoor.

It can help, as mentioned, against attacks on the data after you're done with it
completely (i.e. shut the machine/container in question down for good), or
against rather clumsy and incompetent "power off first and think second"
attacks.

If this benefit is worth the hassle of this extra ssh'ing, some maintenance
overhead and the possibility of loosing the LUKS key/header (and all access to
data with it), only then (I think) this module might be useful to you.


### Usage

First of all, you must have dropbear. CentOS/RHEL users can get this from EPEL.  

You will need gcc and libblkid(-devel) installed to build console_auth and the unlock tools.

- You should be able to build everything by running configure, make, make install as usual.
  The configure script should detect and compensate for the various differences in dracut versions.

- The provided RPM spec file should take care of these things for RHEL6/7

- Add `dracutmodules+="dropbear-sshd"` to dracut.conf
  (will pull in "network" module as dependency).

- Check out supported dracut.conf options below.
  With no extra options, ad-hoc server rsa key will be generated (and its
  fingerprint/bbcode will be printed to dracut log),
  `/root/.ssh/authorized_keys` will be used for ACL.

- See dracut.cmdline(7) manpage for info on how to setup "network" module
  (otherwise sshd is kinda useless).

  Simplest way might be just passing `ip=dhcp rd.neednet=1` on cmdline, if dhcp
  can assign predictable ip and pass proper routes.

  On older Dracut versions (e.g. 004 in RHEL6), networking is only configured
  if you have configured a network root.  In order to work around this, dracut-earlyssh
  system will install a dummyroot script (if it detects dracut v004 at build-time).
  The cmdline for these versions should be `ip=dhcp netroot=dummy`. 

- Run dracut to build initramfs with the thing.


On boot, sshd will be started with:

- Port: ${dropbear_port} (dracut.conf) or 2222 (default).

- User (to allow login as-): root

- Host key: ${dropbear_rsa_key} (dracut.conf) or generated
  (fingerprint echoed during generation and to console on sshd start).
  DSA keys are not supported (and shouldn't generally be used with ssh).

- Client key(s): ${dropbear_acl} (dracut.conf) or `/root/.ssh/authorized_keys`

- Password auth and port forwarding explicitly disabled.

Dropbear should echo a few info messages on start (unless rd.quiet or similar
options are used) and print host ssh key fingerprint to console, as well as any
logging (e.g. errors, if any) messages.

Do check the fingerprints either by writing them down on key generation, console
or through network perspectives at least.


To login:

    % ssh -p2222 root@some.remote.host.tld

Shell is /bin/sh, which should be
[dash](http://gondor.apana.org.au/~herbert/dash/) in most dracut builds, but can
probably be replaced with ash (busybox) or bash (heavy) using appropriate modules.


After the system starts booting, sshd should be killed during dracut "cleanup" phase, once 
main os init is about to run.  Connection won't be closed, but nothing should work there, 
as initramfs gets destroyed.

### Remote unlock via console manipulation:

```console

% console_peek   # to see what's on the console (e.g. which dev prompt is for)
...
% console_auth    # queries passphrase and sends it to console
Passphrase:
%
```

Boot should continue after last command, which should send entered passphrase to
cryptsetup, waiting for it on the console, assuming its correctness.

### Remote unlock using the 'unlock' binary
The `unlock` binary takes a passphrase in stdin, reads `/etc/crypttab` and attempts to
call `cryptsetup luksOpen` on all luks-encrypted drives that don't have a keyfile,
passing the passphrase that unlock got in stdin to luksOpen.

What this means in practice is you can do:
```console
% ssh root@remote.server -p 2222 unlock < passwordFile
```
or:
```console
% gpg -d password.gpg | ssh root@remote.server -p 2222 unlock
```

If you want to only unlock specific drives / LUKS volumes, you can provide wildcards on the 
command line, eg
```console
% ssh root@remote.server -p 2222 unlock luks-3467c luks-34c13
```
`unlock` will search the crypttab for mapper names (first column in /etc/crypttab) that
start with the listed names.  Volumes that match via this method may have a keyfile listed
in /etc/crypttab, it will be assumed that you want to unlock the volume/s with an alternative key.
Note that the names provided are really wildcards, and by convention/default all mappers start with luks-,
so you can force `unlock` to try all drives simply by doing something like `unlock luks-`.

In all cases, `unlock` will only consider the process a success IFF all eligible volumes are unlocked
successfully.  This means:
  1. All the associated devices must be available at boot / unlock time
  2. The passphrase must be accepted for all eligible volumes
  3. cryptsetup luksOpen should not exit for any other reason.

In short, if you have more than one volume in /etc/crypttab, you will need to be careful
about how use this tool.

If the process is successful, `unlock` will launch the script `/sbin/unlock-reap-success`.
This can be found in the modules.d/earlyssh folder.  This will attempt to kill systemd-cryptsetup,
and failing that, attempt to kill cryptroot-ask. On RHEL6 & 7, this aborts the builtin decrypt
password request processes and allows the boot process to proceed. 
Note that the plymouth splash screen on RHEL6 (if you happen to be watching the console...) will still appear to ask for your password, but this is an artificat.  Disable plymouth (rhgb command line) if this annoys you.

### dracut.conf parameters

- dropbear_port

- dropbear_rsa_key

- dropbear_acl

See above.


### Common issues and non-issues

- `Dropbear sshd failed to start`

Only means what it says, see output of dropbear *before* it died - it should
print some specific errors which led to it exiting like that.

- `Failed reading '-', disabling DSS`

Will *always* be printed and should be ignored - DSA keys are not generated/used
in these scripts, and probably shouldn't be.

- Host hangs in initramfs, but can't be pinged (e.g. `ping my.host.tld`) from outside.

Either no network configuration parameters were passed to dracut, or it failed
to configure at least one IP address.

Don't forget `rd.neednet=1` on cmdline, as dracut will ignore specified network
settings without nfs (or whatever net-) root otherwise.

Read up dracut.cmdline(7), "Network" section and/or see why/if dracut failed to
configure net as requested with `rd.debug`.
See also "Debugging tips" section below.

- Host pings, but ssh can't connect.

Try `nc -v <host> <port>`, or "ncat" instead of "nc" there.
"ncat" can be found in "nmap" package, "nc" usually comes pre-installed.

If it hangs without printing "Connected to ..." line - can be some firewall
before host or dropbear failed to start/listen.

If there's no "SSH-2.0-dropbear_..." after "Connected to ..." line - some issue
with dropbear.

- `lastlog_perform_login: Couldn't stat /var/log/lastlog: No such file or directory`

Pops up when logging in, can be safely ignored.


### Debugging tips

If (or rather "when") something goes wrong and you can't access just-booted
machine over network and can't get to console (hence sshd in initramfs), don't
panic - it's fixable if machine can be rebooted into some rescue system
remotely.

Usually it's some dhcp+tftp netboot thing from co-located machine (good idea to
setup/test in advance) plus whoever is there occasionally pushing the power
button, or maybe some fancy hw/interface for that (e.g. hetzner "rescue" interface).

To see what was going on during initramfs, open
"modules.d/99base/rdsosreport.sh" in dracut, append this (to the end):

	set -x
	netstat -lnp
	netstat -np
	netstat -s
	netstat -i
	ip addr
	ip ro
	set +x

	exec >/dev/null 2>&1
	mkdir /tmp/myboot
	mount /dev/sda2 /tmp/myboot
	cp /run/initramfs/rdsosreport.txt /tmp/myboot/
	umount /tmp/myboot
	rmdir /tmp/myboot

Be sure to replace `/dev/sda2` with whatever device is used for /boot, rebuild
dracut and add `rd.debug` to cmdline (e.g. in grub.cfg's "linux" line).

Upon next reboot, *wait* for at least a minute, since dracut should give up on
trying to boot the system first, then it will store full log of all the stuff
modules run ("set -x") and their output in "/boot/rdsosreport.txt".

Naturally, to access that, +1 reboot into some "rescue" system might be needed.

In case of network-related issues - e.g. if "rdsosreport.txt" file gets created
with "rd.debug", but host can't be pinged/connected-to for whatever reason -
either enable "debug" dracut module or add `dracut_install netstat ip` line to
`install()` section of "modules.d/60dropbear-sshd/module-setup.sh" and check
"rdsosreport.txt" or console output for whatever netstat + ip commands above
(for "rdsosreport.sh") show - there can be no default route, whatever interface
naming mixup, no traffic (e.g. unrelated connection issue), etc.


### TODO

- Limited testing.  Original (before fork) only tested with customized source-based distro
  ([Exherbo](http://exherbo.org/)), current version only tested with CentOS 6.5 and CentOS 7.0.
  However, the configure script should allow it to be fairly adaptable to a range of distro's.

- Need to document & form recommendations on how to unlock multiple systems using the unlock script.
  Something with gpg-agent seems like it may work well.

- `check()` in module_setup.sh should probably not be empty no-op.

- Should probably have `set -e` or something alike (dracut-specific?) in install().

- No idea how to sanely run `ssh-keygen` (openssh) from a script, maybe use
  openssl instead?

- Remote initramfs hash verification, etc.  See above point, a determined attacker could potentially
  circumvent or fake the outputs of various commands in order to pretend that the verification had succeeded.
  One possibility would be to dynamically upload a special hashing binary that has a compiled-in nonce.  This
  would be hard to fake, I think.  However, it would require a compiler for each supported architecture on the
  verification machine.


### Based on code, examples and ideas from

- https://bugzilla.redhat.com/show_bug.cgi?id=524727
- http://roosbertl.blogspot.de/2012/12/centos6-disk-encryption-with-remote.html
- https://bitbucket.org/bmearns/dracut-crypt-wait
