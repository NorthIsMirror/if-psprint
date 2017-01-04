#!/usr/local/bin/perl
#
# $NetBSD: if-psprint.pl,v 1.5 2001/06/26 10:41:25 abs Exp $
#
#	Copyright (c) 2000 David Brownlee <abs@netbsd.org>. All rights
#	reserved. Provided as-is without express or implied warranties.
#
#	Redistribution and use in source and binary forms, with or without
#	modification, are permitted provided the above copyright and this
#	notice is retained.
#

=head1 NAME

if-psprint - send text, postscript, or native printer language to
arbitrary printer.

=head1 SYNOPSIS

Designed as a quick fix for the random printers that get hooked up to
the NetBSD server and random Windows boxes around the office. Uses enscript
to convert text to postscript, and ghostcript to convert to native printer
language as required.

=head1 DESCRIPTION

=over 4

=item *

Overloads 'af' entry to contain printer type, and optional location.
in the form 'type[.model][/smb/smb_dest]'. Use type 'ps' for no gs filter.

=item *

Reads first 1k and calls 'file' to determine filetype.

=item *

Builds a spool command based on filetype:

=over 4

=item *

If text and not postscript, use enscript text->postscript

=item *

If enscripted or postscript, use gs postscript->printer_format

=item *

Otherwise assumed to be native printer language (its your rope)

=back

=item *

Open pipe to spool command, send first 1k, then rest of data

=item *

requires ghostscript, enscript, and samba if printing to smb hosts

=back

=head1 EXAMPLE PRINTCAP ENTRIES

(Remember to create spool dir [sd])

=over 4

=item *

HP deskjet named 'leaves' connected to smb host 'tea'.
(using ghostscript 'hpdj' driver model 'unspec')

  leaves:\	
    :if=/usr/local/libexec/if-psprint:lf=/var/log/lpd-errs:\
    :sh:mx=0:lp=/dev/null:sd=/var/spool/lpd/leaves:\
    :af=hpdj.unspec/smb/tea/leaves:

=item *

Canon bubblejet connected to /dev/lpa0 (using gs 'bjc800' driver)

  bubbly:\	
    :if=/usr/local/libexec/if-psprint:lf=/var/log/lpd-errs:\
    :sh:mx=0:lp=/dev/lpa0:sd=/var/spool/lpd/bubbly:\
    :af=bjc800:

=back

=cut

use strict;
use warnings;
use Getopt::Std;
use IPC::Open3;
use Sys::Syslog;

$ENV{PATH} = "/usr/local/bin:/usr/bin:/bin";

my ( $user, $dest, $spoolhost, $device, $model, $version, %opt, );

$version = '1.10';

# Parse options (ignore most)
#

getopts( 'cvw:l:i:j:n:h:V', \%opt );
if ( $opt{V} ) { print "$version\n"; exit; }
$user = $opt{n};
$user ||= $ENV{USER};
$spoolhost = $opt{h};
if ( !$spoolhost ) { chomp( $spoolhost = `hostname` ); }

if ( @ARGV != 1 || $ARGV[0] !~ m#(\w+)(\.(\w+)|)(/smb/.*/.*|)# ) {
    usage_and_exit();
}
$device = $1;
$model  = $3;
$dest   = $4;
if ($dest) { $dest =~ s#/smb/#smb:/#; }

# Determine filetype. We ignore -c as it is quote possible for a remote host
# to have formatted everything perfectly for postscript, but we still want to
# convert to native printer format. (MacOS X client).

my ( $data, $filetype, $spool );

$spool = '';

if ( !read( STDIN, $data, 1024 ) )    # initial filetype check data
{
    fail("No data to print");
}
$filetype = filetype($data);

# Generate spool command
#
if ( $filetype =~ /^PostScript/ || $filetype =~ /text/ ) {
    if ( $filetype !~ /^PostScript/ ) { $spool .= '|' . filter_enscript(); }
    if ( $model || $device ne 'ps' ) {
        $spool .= '|' . filter_gs( $device, $model );
    }
}

if ($dest) { $spool .= "|smbspool smb://$dest 1 $user $spoolhost 1 -"; }

if ( $spool eq '' ) { $spool = '>&STDOUT'; }

record_log($spool);

# Spool output
#
if ( !open( OUTPUT, $spool ) ) { fail("Unable to run '$spool': $!"); }
print OUTPUT $data;    # print initial filetype check data
while ( read( STDIN, $data, 16 * 1024 ) ) { print OUTPUT $data; }
close(STDIN);
close(OUTPUT);
exit;

sub fail {
    record_log(@_);
    exit 1;
}

sub filetype {
    my ($data) = @_;
    my ( $pid, $filetype );

    unless ( $pid = open3( 'WTRFH', 'RDRFH', 'ERRFH', 'file -b -' ) ) {
        fail("Unable to run 'file': $!");
    }
    print WTRFH $data;
    close(WTRFH);
    close(ERRFH);
    0 && close(ERRFH);    # Pacify perl's -w
    chop( $filetype = <RDRFH> );
    close(RDRFH);
    wait;
    $filetype;
}

sub filter_enscript {
    my ($filter);

    $filter = "enscript -q -B -p -";
}

sub filter_gs {
    my ( $device, $model ) = @_;
    my ($filter);
    $filter = "gs -q -dBATCH -sDEVICE=$device";
    if ( defined $model ) { $filter .= " -sModel=$model"; }
    $filter .= " -SOutputFile=- -";
}

sub record_log {
    if ( $opt{v} ) { print STDERR "if-psprint: @_\n"; }
    openlog( 'if-psprint', 'pid', 'lpr' );
    syslog( 'info', @_ );
    closelog();
}

sub usage_and_exit {
    print "Usage: if-psprint [opts] gs_device[.gs_model]/smbdestination
[opts]
	-c	  Pass control characters literally
	-v	  Verbose
	-w width  Width
	-l lines  Lines
	-i indent Indent
	-n user	  User
	-h host   Host
	-V	  Print version and exit

if-psprint is intended to be used from within printcap. See the
manpage for more details.
";
    exit 1;
}
