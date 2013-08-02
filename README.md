dracut-crypt-sshd
--------------------

[Dracut initramfs](https://dracut.wiki.kernel.org/index.php/Main_Page) module
to start [Dropbear sshd](https://matt.ucc.asn.au/dropbear/dropbear.html)
on early boot to enter encryption passphrase from across the internets or just
connect and debug whatever stuff there.

Idea is to use the thing on remote VDS servers, where full-disk encryption is
still desirable (if only to avoid data leaks when disks will be decomissioned
and sold by VDS vendor) but rather problematic due to lack of KVM or whatever
direct console access.

Authenticates users strictly by provided authorized_keys (`dropbear_acl` option) file.
See dropbear(8) manpage for full list of supported restrictions there
(which are fairly similar to openssh).


### Usage

- Copy or symlink `60dropbear-sshd` into `/usr/lib/dracut/modules.d/`.

- Add `dracutmodules+="dropbear-sshd"` to dracut.conf
  (will pull in "network" module as dependency).

- Check out supported dracut.conf options below.
  With no extra options, ad-hoc server rsa key will be generated (and its
  fingerprint/bbcode will be printed to dracut log),
  `/root/.ssh/authorized_keys` will be used for ACL.

- See dracut.cmdline(7) manpage for info on how to setup "network" module
  (otherwise sshd is kinda useless).
  Simpliest way might be just passing `ip=dhcp` on cmdline.

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


Once inside:

```console

% cat /dev/vcs1   # to see what's on the console
% console_auth    # queries passphrase and sends it to console
Passphrase:
%
```

Boot should continue after last command, which should send entered passphrase to
cryptsetup, waiting for it in the console, assuming it is correct.

sshd might keep running, unless killed by networking changes or agressive init
system cleanup.
I should probably add some killing pre-pivot hook so it won't be the case.


### dracut.conf parameters

- dropbear_port

- dropbear_rsa_key

- dropbear_acl

See above.


### Based on code, examples and ideas from

- https://bugzilla.redhat.com/show_bug.cgi?id=524727
- http://roosbertl.blogspot.de/2012/12/centos6-disk-encryption-with-remote.html
- https://bitbucket.org/bmearns/dracut-crypt-wait


### Bad things

- Uses plenty of insecure tempfiles on initramfs build, should probably use
  tempdir with all these safely inside.

- Does `gcc -std=gnu99 -O2 -Wall "$moddir"/auth.c -o "${tmp_file}"` for that
  `console_auth` binary on dracut run, that should probably be done when
  installed into dracut's modules.d or maybe there is good packaged substitute
  for that ad-hoc binary.

- Only tested with customized source-based distro
  ([Exherbo](http://exherbo.org/)), no idea how easy it is to use with generic
  debian or ubuntu.

- check() in module_setup.sh should probably not be empty no-op.

- Should probably have `set -e` or something alike (dracut-specific?) in install().

- No idea how to sanely run `ssh-keygen` (openssh) from a script, maybe it
  shouldn't be?

- Some notes on threat model where such thing might be useful would be nice.
