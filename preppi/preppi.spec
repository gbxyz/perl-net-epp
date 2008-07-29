# $Id: preppi.spec,v 1.13 2008/01/02 18:06:49 gavin Exp $
Summary:	A graphical EPP client.
Name:		preppi
Version:	0.06
Release:	1
Epoch:		0
Group:		Applications/Network
License:	GPL
URL:		http://labs.centralnc.com/preppi.php
Packager:	Gavin Brown <epp@centralnic.com>
Source:		http://labs.centralnic.com/%{name}/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/root-%{name}-%{version}
Prefix:		%{_prefix}
AutoReq:	no
BuildArch:	noarch
BuildRequires:	perl
Requires:	perl >= 5.8.6, perl(Gtk2), perl(Gtk2::GladeXML::Simple), perl(Locale::gettext), perl(Gnome2::VFS), perl(Gtk2::SourceView), perl(HTML::Entities), perl(Time::HiRes), gnome-icon-theme, perl(Net::EPP:Client), perl(Net::EPP::Frame) >= 0.11

%description
Preppi is a simple graphical EPP client for Unix and Linux systems. It
is written in Perl and makes use of the GTK+ and GNOME bindings for
Perl, and the EPP libraries for Perl.

%prep
%setup
./configure --prefix=%{_prefix}

%build
make

%install
rm -rf %{buildroot}
%makeinstall prefix=%{buildroot}%{_prefix}

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,0755)
%doc COPYING
%{_bindir}/*
%{_datadir}/*

%changelog
*Mon Jul 24 2006 Gavin Brown <epp@centralnic.com> - 0.02-1
- automatically validate user input
- user-defined templates
- more templates (available from Net::EPP::Frame)
- templates organised in a tree
- configurable text wrapping and line numbers on input/output view
- can view the server <greeting> now
- better error handling

*Thu Jul 06 2006 Gavin Brown <epp@centralnic.com> - 0.01-1
- Initial package.
