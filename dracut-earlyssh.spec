Summary: A dracut module that adds ssh to the boot image (also known as earlyssh)
Name: dracut-earlyssh
Version: 1.0.2
Release: 4
License: GPLv2+
Source: dracut-earlyssh-%{version}.tgz
Packager: Michael Curtis <michael@moltenmercury.org>
BuildRequires: dracut
BuildRequires: libblkid-devel
BuildRequires: gcc

Requires: dropbear
Requires: dracut
Requires: dracut-network
Requires: openssh

%description
A dracut module that includes dropbear in the boot image, along with some
helper utilities for unlocking encrypted drives over a remote connection.

Please read the README and configuration parameters in 
/etc/dracut.conf.d/earlyssh.conf before use.

%prep
%setup
./configure

%build
make

%install
make install DESTDIR=$RPM_BUILD_ROOT
cp README.md README

%files
%defattr(-,root,root,0755)
%doc README COPYING
%config(noreplace) %{_sysconfdir}/dracut.conf.d/earlyssh.conf
%{_libexecdir}/dracut-earlyssh
%{_prefix}/*/dracut/modules.d/*



