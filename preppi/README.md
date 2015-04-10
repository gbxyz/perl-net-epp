# Preppi

Preppi is a simple graphical EPP client for Unix and Linux systems. It is written in Perl and makes use of the [GTK+ and GNOME bindings for Perl](http://gtk2-perl.sourceforge.net/), and [our own EPP libraries](http://code.google.com/p/perl-net-epp).

### Dependencies

*   GTK+ version 2.8.0 or later and the [Gtk2](http://search.cpan.org/dist/Gtk2) Perl module
*   GnomeVFS and the [Gnome2::VFS](http://search.cpan.org/dist/Gnome2-VFS) Perl module (you don't need the full GNOME stack)
*   gtksourceview and the [Gtk2::SourceView](http://search.cpan.org/dist/Gtk2-SourceView) Perl module
*   the [Net::EPP](/registry/labs/perl) Perl module

Preppi also uses a number of other Perl modules, that will either be part of your standard Perl build, or will be available from your operating system distributor.

### Downloads

The current version is **0.05**, which was released on **December 8, 2007.**

*   [Source Tarball](http://packages.centralnicregistry.com/6/src/preppi-0.05.tar.gz)
*   [Source RPM](http://packages.centralnicregistry.com/6/SRPMS/preppi-0.05-1.src.rpm)
*   [RPM](http://packages.centralnicregistry.com/6/noarch/preppi-0.05-1.noarch.rpm) - good for Red Hat, Fedora, CentOS, etc

### License

Preppi is licensed under the [GNU General Public License](http://www.gnu.org/licenses/gpl.html).

## How to Install Preppi on a RHEL/CentOS/Fedora System (and others)

Preppi has a number of dependencies that must be satisifed before it can be run. If you try to run Preppi without these dependencies being satisified, you'll get errors like this:

    [user@host ~]$ preppi
    Can't locate Foo/Bar.pm in @INC (@INC contains: [list of directories]
    BEGIN failed--compilation aborted at /usr/bin/preppi line 1.

The Foo/Bar.pm file corresponds to the Foo::Bar Perl module - to get Preppi to run, you need to chase down and install this module.

**Installing Perl Modules**

There are several ways to install Perl modules on a RHEL/CentOS/Fedora System:

1.  as RPM packages using Yum. This is the best way to do it as yum will automatically download all the dependencies and your system will keep them updated
2.  as RPM packages you build yourself using [cpan2rpm](http://perl.arix.com/cpan2rpm/)
3.  using the cpan command

It is possible to install Preppi using only the first two options.

**Installing Preppi's Dependencies**

First off, you should install all the Gtk2 and Gnome2 modules and the other modules that Preppi and Net::EPP require:

    [user@host ~]$ sudo yum -y install perl-Gtk2* perl-Gnome2* perl-XML-LibXML perl-IO-Socket-SSL perl-Digest-SHA1 perl-gettext perl-HTML-Parser perl-URI

Next, go to the [cpan2rpm website](http://perl.arix.com/cpan2rpm/) and download the noarch RPM, and install it:

    [user@host ~]$ sudo yum -y localinstall cpan2rpm-2.028-1.noarch.rpm

Next, use yum to install the gtksourceview-devel package, as we will be compiling our own copy of Gtk2::SourceView:

    [user@host ~]$ sudo yum -y install gtksourceview-devel

If you don't have a .rpmmacros file in your home directory, create one that looks like this:

    %_topdir /home/user/rpmbuild
    %_gpg_name YOUR_GPG_ID

Now, use cpan2rpm to build the remaining dependencies:

    [user@host ~]$ cpan2rpm Gtk2::Ex::Simple::Tree
    [user@host ~]$ cpan2rpm Gtk2::SourceView
    [user@host ~]$ cpan2rpm Gtk2::GladeXML::Simple
    [user@host ~]$ cpan2rpm Net::EPP

Then install each RPM using rpm (cpan2rpm will give you the file names that you need).

**Important note:** the perl-Gtk2-GladeXML-Simple package will have dependencies on Gtk2::Html2 and WWW::Search: you can either satisfy them by building and installing packages using cpan2rpm, or you can use the --nodeps argument to rpm to force it to be installed.

### Installing Preppi

Now that the above has been done, it is trivial to install Preppi:

    [user@host ~]$ sudo yum -y localinstall preppi-0.05-1.noarch.rpm