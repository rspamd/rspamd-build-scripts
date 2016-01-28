# Note that this is NOT a relocatable package
%define ver      2.6.20
%define prefix   /usr
%define enable_mono 0
%define enable_gtk_doc 0

%if %{enable_mono}
%define mono_configure_flags --enable-mono
%else
%define mono_configure_flags --disable-mono
%endif

%if %{enable_gtk_doc}
%define gtkdoc_configure_flags --enable-gtk-doc
%else
%define gtkdoc_configure_flags --disable-gtk-doc
%endif

Summary: MIME library
Name: gmime
Version: %ver
Release: 1
Group: Development/Libraries
URL: http://spruce.sourceforge.net/gmime/
License: LGPL
Source: ftp://ftp.gnome.org/pub/GNOME/sources/gmime/2.4/gmime-%{version}.tar.xz
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

Requires: glib2 >= 2.12.0
BuildRequires: glib2-devel >= 2.12.0

%description
GMime is a set of utilities for parsing and creating messages using
the Multipurpose Internet Mail Extension (MIME)

%if %{enable_mono}

%package sharp
Summary: .NET bindings for GMime
Group: Development/Libraries
Requires: %{name} = %{version}-%{release}
BuildRequires: mono-core >= 2.0.0
BuildRequires: gtk-sharp >= 2.4.0
Requires: mono-core >= 2.0.0
Requires: gtk-sharp >= 2.4.0

%description sharp
.NET Bindings for GMime

%endif

%prep
%setup

%build
if [ ! -f configure ]; then
  CFLAGS="$RPM_OPT_FLAGS" ./autogen.sh $ARCHFLAG %{config_opts} %{mono_configure_flags}
fi
CFLAGS="$RPM_OPT_FLAGS" ./configure --prefix=%prefix %{mono_configure_flags} --disable-cryptography --disable-gtk-doc
make

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=${RPM_BUILD_ROOT} GACUTIL_FLAGS="/package gtk-sharp /root ${RPM_BUILD_ROOT}/usr/lib"

# rename to prevent conflict with uu* utils from sharutils

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)

%doc AUTHORS ChangeLog NEWS README COPYING TODO
%{prefix}/lib/libgmime*
%{prefix}/lib/pkgconfig/*
%{prefix}/include/gmime-2.6/gmime/*.h
%{_datadir}/gtk-doc/html/*/*

%if %{enable_mono}

%files sharp
%{prefix}/lib/mono/gmime-sharp/*
%{prefix}/lib/mono/gac/gmime-sharp/*
%{prefix}/share/gapi/gmime-api.xml

%endif

%changelog
* Mon Nov 29 2004 Ryan Skadberg <skadz@stigmata.org>
- Added in sharp package for .NET bindings

* Wed Dec  9 2002 Benjamin Lee <benjamin.lee@aspectdata.com>
- fixed sharutils conflict with uudecode and uuencode.
- removed duplicate libgmime inclusion in %files.

* Wed Dec  4 2002 Benjamin Lee <benjamin.lee@aspectdata.com>
- fixed files for gtk-doc, pkconfig, and includes.

* Sat Mar 24 2001 Leland Elie <lelie@airmail.net>
- created spec file.
