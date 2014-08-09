%define olddracut 0

%if 0%{?rhel} && 0%{?rhel} <= 6
%define olddracut 1
%endif

Summary: A dracut module that adds ssh to the boot image (also known as earlyssh)
Name: dracut-earlyssh
Version: 1.0.2
Release: 1
License: GPL
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

Please read the README and configuration parameters in /etc/dracut.conf.d/earlyssh.conf
before use.

%prep
%setup

%build
make LIBDIR=/lib64 ROOTHOME=/ OLDDRACUT=%{olddracut} 

%install
make install OLDDRACUT=%{olddracut} DESTDIR=$RPM_BUILD_ROOT
cp README.md README

%files
%defattr(-,root,root,0755)
%doc README COPYING
%config(noreplace) %{_sysconfdir}/dracut.conf.d/earlyssh.conf
%{_libexecdir}/dracut-earlyssh
%{_datadir}/dracut/modules.d/60earlyssh
%if %{olddracut}
%{_datadir}/dracut/modules.d/91cryptsettle-patch
%endif



