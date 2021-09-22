dracut-crypt-ssh
----------------

# 1. Introduction

The crypt-ssh dracut module allows remote unlocking of systems with
full disk encryption via ssh.

There are a number of reasons why you would want to do this:
  1. It provides a way of entering encryption keys for a number of servers without console switching
  2. It allows booting of remote or co-located encrypted servers without console access

Users are strictly authenticated using their SSH public keys. These can be either:
`/root/.ssh/authorized_keys` or a custom file (`dropbear_acl` option). Depending
on your environment, it may make sense to make the preboot authorized_keys file
different from the normal one.

Plain text password authentication and port forwarding are disabled.


# 2. Installation

We recommend installation via packages, or build manually if unavailable.
You are encouraged to get in contact with us via [GitHub issues](https://github.com/dracut-crypt-ssh/dracut-crypt-ssh/issues)
if you are able to provide packages for other distributions.

## 2.1. Installation from packages on Fedora/RHEL/CentOS

We currently provide packages for RHEL+CentOS 7 as well as Fedora 22+
via a [COPR repository](https://copr.fedorainfracloud.org/coprs/rbu/dracut-crypt-ssh/).

Installation via dnf (Fedora):

    # dnf copr enable rbu/dracut-crypt-ssh
    # dnf install dracut-crypt-ssh

Installation via yum (CentOS 7):

    # yum install epel-release
    # wget -O /etc/yum.repos.d/rbu-dracut-crypt-ssh-epel-7.repo https://copr.fedorainfracloud.org/coprs/rbu/dracut-crypt-ssh/repo/epel-7/rbu-dracut-crypt-ssh-epel-7.repo
    # yum install dracut-crypt-ssh

## 2.2. Installation from sources on Fedora/RHEL/CentOS

Install build dependencies (example commands for RPM systems). When building
on RHEL, be sure to enable EPEL (`yum install epel-release`).

    # yum install dropbear dracut dracut-network openssh
    # yum install libblkid-devel gcc

Retrieve a copy the source and build:

    $ git clone https://github.com/dracut-crypt-ssh/dracut-crypt-ssh.git
    $ cd dracut-crypt-ssh
    $ ./configure
    $ make
    $ sudo make install

## 2.3. Installation on other distributions

- Gentoo: available in Portage, just `emerge sys-kernel/dracut-crypt-ssh`.
- [Arch Linux](https://aur.archlinux.org/packages/dracut-crypt-ssh/), [Arch Linux Git](https://aur.archlinux.org/packages/dracut-crypt-ssh-git/)


# 3. Usage

## 3.1. Building the initramfs

After the first installation and every time you update the `dracut-crypt-ssh` configuration,
it is required to rebuild the initramfs:

    # dracut --force


## 3.2 Enable network access during boot

You will need to adjust your boot loader to configure network access for your
initramfs. The kernel and initramfs should be booted with the kernel
command-line arguments `rd.neednet=1` and an appropriate `ip=` argument for
your network. For DHCP configuration,

    rd.neednet=1 ip=dhcp

should be sufficient. For static configuration, use something like

    rd.neednet=1 ip=192.168.0.100::192.168.0.1:255.255.255.0::eth0:off

Refer to the [network documentation of dracut](https://www.kernel.org/pub/linux/utils/boot/dracut/dracut.html#_network)
for more options (`man dracut.cmdline`).

For GRUB users, the kernel command-line often can be set in `/etc/default/grub`
by appending the necessary arguments to the end of the `GRUB_CMDLINE_LINUX`
variable:

    /etc/default/grub:
        ...
        GRUB_CMDLINE_LINUX="... rd.neednet=1 ip=dhcp"
        ...

Afterwards, regenerate your GRUB config:

    # grub2-mkconfig --output /etc/grub2.cfg


## 3.3. Unlocking the volumes interactively

When rebooting the system, dropbear sshd is started by the initramfs. You should
be able to login and unlock the volumes:

    % ssh -p 222 root@192.168.0.100
    # console_peek   # to see what's on the console
    # console_auth   # asks you for the passphrase and sends it to console
    Passphrase:


If unlocking the device succeeded, the initramfs will clean up itself
and dropbear terminates itself and your connection.


## 3.4. Unlocking using the unlock command

The `unlock` binary reads a passphrase from stdin, parses `/etc/crypttab`
and attempts to call `cryptsetup luksOpen` on all luks-encrypted drives that
don't have a keyfile, passing the passphrase that unlock got in stdin to luksOpen.

What this means in practice is you can do:

    % ssh root@remote.server -p 222 unlock < passwordFile

or:

    % gpg -d password.gpg | ssh root@remote.server -p 222 unlock

If you want to only unlock specific drives / LUKS volumes, you can provide
wildcards on the command line, e.g.

    % ssh root@remote.server -p 222 unlock luks-3467c luks-34c13


`unlock` will search the crypttab for mapper names (first column in
`/etc/crypttab`) that start with the listed names.  Volumes that match via this
method may have a keyfile listed in `/etc/crypttab`, it will be assumed that you
want to unlock the volume/s with an alternative key.
Note that the names provided are really wildcards, and by convention/default
all mappers start with luks-, so you can force `unlock` to try all drives simply
by doing something like 'unlock luks-'.

In all cases, `unlock` will only consider the process a success only if all
eligible volumes are unlocked successfully.  This means:

  1. All the associated devices must be available at boot / unlock time
  2. The passphrase must be accepted for all eligible volumes
  3. cryptsetup luksOpen should not exit for any other reason.

In short, if you have more than one volume in `/etc/crypttab`, you will need to
be careful about how use this tool.

If the process is successful, `unlock` will launch the script
`/sbin/unlock-reap-success`. This will attempt to kill systemd-cryptsetup, and
failing that, attempt to kill cryptroot-ask. On RHEL6 & 7, this aborts the
builtin decrypt password request processes and allows the boot process to
proceed. Note that the plymouth splash screen on RHEL6 (if you happen to be
watching the console...) will still appear to ask for your password, but this
is an artifact. Disable plymouth (rhgb command line) if this annoys you.

You might want to limit access only to the unlock binary, just add
command="unlock" to your authorized_keys before the key, e.g.

    command="unlock" ssh-rsa .....

> In some cases (CentOS stream) you may wish to replace `unlock` with `systemd-tty-ask-password-agent`

# 4. Configuration

The configuration is stored in the crypt-ssh.conf, usually located in `/etc/dracut.conf.d/`.

The following options are available (see the config file for detailed description):
 - `dropbear_port` (default: `222`) - port ssh daemon should listen on
 - `dropbear_rsa_key`, `dropbear_ecdsa_key`, `dropbear_ed25519_key` (default: `GENERATE`) - Source of the keys, possible options:
   - `SYSTEM` - copy the private keys from the encrypted system (not recommended)
   - `GENERATE` - generate a new keys (during the creation of initramfs)
   - path - key file in OpenSSH format as generared by ssh-keygen (a public file with '.pub' ending must be present too)
 - `dropbear_acl` (default: `/root/.ssh/authorized_keys`) - Keys which allowed to login into initramfs

After any configuration change, you have to rebuild the initramfs as the
configuration takes effect during the building the initramfs.

## 4.1 Generating keys for dracut-crypt-ssh (recommended)

By default, dracut-crypt-ssh generates an SSH key whenever the image is built
(`GENERATE`), which either creates administrative overhead or weakens the
security of the SSH connection as keys will be regenerated transparently during
system updates. It is highly recommended to generate SSH keys specifically
for dracut-crypt-ssh and validate these keys during the initial connection.
The following steps should give you an idea how to set this up. You can change
the directory as you wish. Keep these SSH keys safe, but also keep in mind that
they will be copied to the initramfs on the unencrypted boot partition (where
they may be extracted or changed).

    # umask 0077
    # mkdir /root/dracut-crypt-ssh-keys
    # ssh-keygen -t rsa -m PEM -f /root/dracut-crypt-ssh-keys/ssh_dracut_rsa_key
    # ssh-keygen -t ecdsa -m PEM -f /root/dracut-crypt-ssh-keys/ssh_dracut_ecdsa_key
    # ssh-keygen -t ed25519 -m PEM -f /root/dracut-crypt-ssh-keys/ssh_dracut_ed25519_key

Point to these keys in the configuration `/etc/dracut.conf.d/crypt-ssh.conf`:

    dropbear_rsa_key="/root/dracut-crypt-ssh-keys/ssh_dracut_rsa_key"
    dropbear_ecdsa_key="/root/dracut-crypt-ssh-keys/ssh_dracut_ecdsa_key"
    dropbear_ed25519_key="/root/dracut-crypt-ssh-keys/ssh_dracut_ed25519_key"

Remember regenerate the initramfs after this step:

    # dracut --force

# 5. Troubleshooting and Debugging

If things don't work as expected, there are a few ways to find out what
is going, get help or report an issue.

## 5.1 Ensure disk decryption works

With or without crypt-ssh installed, dracut should always prompt for
a LUKS password and boot properly when the password is entered. If booting
with an interactive password does not work, you need to fix that first:
Ensure that the LUKS UUID configured in GRUB and the crypttab in the initramfs
are up to date and all modules needed to mount the root filesystem are present
in the initramfs. 

Refer to the [crypto LUKS documentation of dracut](https://mirrors.edge.kernel.org/pub/linux/utils/boot/dracut/dracut.html#_crypto_luks)
(`man dracut.cmdline`) and your distribution documentation or help channels.

## 5.2 Ensure networking works (if you have console access)

If you cannot reach the crypt-ssh host via SSH, but you still have
interactive console access, you can (re)boot it with a dracut breakpoint.

When GRUB presents the boot options, hit the `e` key to edit boot options
and add `rd.break=pre-mount` to the boot options. Remove `rhgb` and `quiet`
from the kernel command line, if they are present. Hit `Ctrl-x` to boot
with the manual configuration and type your LUKS passphrase via the console.

Before mounting the root filesystem, dracut will drop you into a shell.
Is your network adapter present in `ip a`? If not, does your network adapter
need a module (check `lsmod` and `dmesg | grep net`)? Do you have an IP address
configured? Can you use `dhclient` to acquire an IP address? Is `dropbear`
running (`ps aux`)?

If the network adapter (module) is missing, rebuild the initramfs (`dracut -f`).
If your network configuration is missing, it's probably a configuration
issue. Refer to the Usage section for networking parameters. If the network
comes up, but dracut does not load, that's probably a bug in dracut-crypt-ssh.
[Please report it](https://github.com/dracut-crypt-ssh/dracut-crypt-ssh/issues).

## 5.3 Debugging a remote host

If (or rather "when") something goes wrong and you can't access just-booted
machine over network and can't get to console (hence sshd in initramfs), don't
panic - it's fixable if the machine can be rebooted into some rescue system
remotely.

Usually it's some dhcp+tftp netboot thing from a co-located machine (good idea to
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

## 5.4 *dracut: dropbearconvert for ED25519 key failed*

In the case that your dropbearconvert does not support ED25519 encryption (e.g CentOS Stream), you will need to install
dropbear from source upstream of [this PR](https://github.com/mkj/dropbear/pull/91).  We will use the `DROPBEAR_2020.81` tag in the example below.

1. Clone [dropbear git repo](https://github.com/mkj/dropbear)

2. Check out the latest release tag
   ```
   git checkout DROPBEAR_2020.81
   ```

2. Install from source. 
   ```
   ./configure 
   make
   sudo make install
   ```

3. Now re-run `dracut --force`

Since the sudo user only has the following items in path `/sbin:/bin:/usr/sbin:/usr/bin` and our version of dropbear is installed in `/usr/local/bin`, we need to extend the path of the sudo user for this command to ensure the right version of dropbear is used. 

We can do this with the following command:
```
sudo PATH="/usr/local/bin:$(sudo bash -c 'echo "$PATH"')' dracut --force
```
   

## 5.5 Report a bug

If you suspect a bug in the software, please [report it via our issue 
tracker](https://github.com/dracut-crypt-ssh/dracut-crypt-ssh/issues).


# 6. Security warning

The integrity, confidentiality and authenticity of your encrypted data relies
on the physical integrity of your device. If someone else has access to the
device that you are unlocking, it is entirely possible to replace the executable
files handling your key material, or steal your initramfs's SSH private keys.
Arguably, this kind of attack is possible without the "crypt-ssh" module, but
using automated or remote access could make such an attack easier to conceal.

If this is a concern for you, consider keeping your devices offline and on
your person.

If this is not a concern for you, i.e. you place a certain amount of trust in
your hosting provider or physical integrity, this tool might still protect
against accidental data leaks (i.e. VM deprovisioning, replaced hard disks).
