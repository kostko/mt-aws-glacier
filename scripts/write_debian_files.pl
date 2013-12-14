#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use File::Copy;
use File::Path;

my $BASEDIR = $ARGV[0]||confess;
our $DISTRO_TYPE = $ARGV[1]||confess;
my $distro = $ARGV[2]||confess;


our $OUTDIR = "$BASEDIR/$distro/debian";
our $COMMONDIR = "$BASEDIR/common_debian";
our $CHANGELOG = "$OUTDIR/changelog";
our $CONTROL= "$OUTDIR/control";

our $PACKAGE = 'libapp-mtaws-perl';
our $CPANDIST = 'App-MtAws';
our $MAINTAINER = 'Victor Efimov <victor@vsespb.ru>';

confess unless $DISTRO_TYPE =~ /^(ubuntu|debian)$/;

mkpath $OUTDIR;
mkpath "$OUTDIR/source";

our $_changelog;
sub write_changelog($&)
{
	my ($distro, $cb) = @_;
	local $_changelog = [];
	$cb->();
	open my $f, ">", $CHANGELOG or confess;
	for (@{$_changelog}) {
		next if $_->{re} && $distro !~ $_->{re};
		my $version;
		if ($DISTRO_TYPE eq 'ubuntu') {
		    $version = "$_->{upstream_version}-0ubuntu$_->{package_version}~${distro}1~ppa1";
		} elsif ($DISTRO_TYPE eq 'debian') {
			my $v = do {
				if ($distro eq 'jessie') {
					8
				} elsif ($distro eq 'wheezy') {
					7
				} elsif ($distro eq 'squeeze') {
					6
				} else {
					confess "unknown $distro for debian";
				}
			};
		    $version = "$_->{upstream_version}-0vdebian$_->{package_version}~v$v~mt1";
		} else {
		    confess;
		}
		print $f "$PACKAGE ($version) $distro; urgency=low\n\n";
		print $f $_->{text};
		print $f "\n";
		print $f " -- $MAINTAINER  $_->{date}\n\n";
	}
	close $f or confess;
}

sub entry(@)
{
	my ($upstream_version, $package_version, $date, $text, $re) = (shift, shift, shift, shift, pop, shift);
	push @{$_changelog}, {
		upstream_version => $upstream_version,
		package_version => $package_version,
		date => $date,
		re => $re,
		text => $text
	};
}

sub write_control
{
	my ($distro) = @_;

	my @build_deps = qw/libtest-deep-perl libtest-mockmodule-perl libdatetime-perl libmodule-build-perl/;

	my $is_lucid = $distro =~ /(lucid|squeeze)/i;

	push @build_deps, 'libtest-spec-perl ', 'libhttp-daemon-perl' unless $is_lucid;

	my @deps = qw/libwww-perl libjson-xs-perl/;
	my @recommends = $is_lucid ?  () : qw/liblwp-protocol-https-perl/;
	my $build_deps = join(", ", @deps, @build_deps);
	my $deps = join(", ", @deps);
	my $recommends= join(", ", @recommends);
	my $recommends_line = @recommends ? "Recommends: $recommends\n" : "";
	open my $f, ">", $CONTROL or confess;

	print $f <<"END";
Source: $PACKAGE
Section: perl
Priority: optional
Maintainer: $MAINTAINER
Build-Depends: debhelper (>= 8), perl, $build_deps
Standards-Version: 3.9.2
Homepage: http://search.cpan.org/dist/$CPANDIST/

Package: $PACKAGE
Architecture: all
Depends: \${misc:Depends}, \${perl:Depends}, perl, $deps
${recommends_line}Description: mt-aws/glacier - Perl Multithreaded Multipart sync to Amazon Glacier
END

	close $f or confess
}

sub copy_files
{
	my ($distro) = @_;
	for (qw!compat copyright libapp-mtaws-perl.docs watch rules source/format!) {
		system("cp", "$COMMONDIR/$_", "$OUTDIR/$_") and confess "copy $COMMONDIR/$_ $OUTDIR/$_ $!";
	}
}

sub copy_files_to_debian
{
	my ($distro) = @_;
	for (qw!changelog control compat copyright libapp-mtaws-perl.docs watch rules source/format!) {
		system("cp", "$OUTDIR/$_", "./debian/$_") and confess "copy $OUTDIR/$_, ./debian/$_ $!";
	}
}

write_changelog $distro, sub {

	entry '1.103', 1, 'Sat, 14 Dec 2013 15:10:00 +0400', <<'END';
  * Fixed: issue #48 download-inventory was crashing if there was a request for inventory retrieval in CSV format
  issued by 3rd party application. mt-aws-glacier was not supporting CSV and thus crashing.
  It's hard to determine inventory format until you download it, so mt-aws-glacier now supports CSV parsing.

  * Fixed: download-inventory command now fetches latest inventory, not oldest

  * Added --request-inventory-format option for retrieve-inventory commands

  * Documentation: updated docs for retrieve-inventory and retrieve-inventory and download-inventory commands
END

	entry '1.102', 1, 'Tue, 10 Dec 2013 19:38:00 +0400', <<'END';
  * Fixed: memory/reasource leak, introduced in v1.100. Usually resulting in crash after uploading ~ 1000 files ( too
  many open files error)

  * Minor improvements to process termination code
END

	entry '1.101', 1, 'Sun, 8 Dec 2013 12:50:00 +0400', <<'END';
  * Fixed: CPAN install was failing for non-English locales due to brittle test related to new FSM introduced in 1.100
  Also error message when reading from file failed in the middle of transfer was wrong for non-English locales.

  * Added validation - max allowed by Amazon --partsize is 4096 Mb

  * Fixed: --check-max-file-size option validation upper limit was wrong. Was: 40 000 000 Mb; Fixed: 4 096 0000 Mb
END

	entry '1.100', 1, 'Sat, 7 Dec 2013 15:30:00 +0400', <<'END';
  * Nothing new for end users (I hope so ). Huge internal refactoring of FSM (task queue engine) + unit
  tests for all new FSM + integration testing for all mtglacier commands.
END
	entry '1.059', 1, 'Sat, 30 Nov 2013 13:54:00 +0400', <<"END";
  * Fixed: Dry-run with restore completed was crashing.
  Fixed a bug introduced in v0.971
  dry-run and restore-completed used archive_id instead of relative filename and thus was crashing with message:
  UNEXPECTED ERROR: SOMEARCHIVEID not found in journal at ... /lib/App/MtAws/Journal.pm line 247.
END

	entry '1.058', 1, 'Fri, 8 Nov 2013 21:50:00 +0400', << "END";
  * Fixed - when downloading inventory there could be Perl warning message ("use initialized ..") in case when some
  specific metadata (x-amz-archive-description) strings (like empty strings) met. Such metadata can appear if
  archives were uploaded by 3rd party apps.

  * Fixed possible deadlock before process termination (after success run or after Ctrl-C), related to issue
  https://rt.perl.org/Ticket/Display.html?id=93428 - select() is not always interruptable. Issue seen
  under heavy load, under perl 5.14, with concurrency=1 (unlikely affects concurrency modes > 1 )

  * Fixed - when deprecated option for command (say, --vault for check-local-hash) was found in config, there was a
  warning that option deprecated, however that should not happen, because everything that is in config should be
  read only when such option required (you should be able to put any unneeded option into config)
END

	entry '1.056', 2, 'Thu, 17 Oct 2013 16:40:30 +0400', << "END";
  * Initial release for Debian 7
END

	entry '1.056', 1, 'Tue, 15 Oct 2013 16:20:30 +0400', << "END";
  * Initial release for launchpad PPA
END

};

write_control $distro;

copy_files $distro;
copy_files_to_debian $distro;
