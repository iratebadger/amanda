#!@PERL@
# Copyright (c) 2020 Union Dynamic, Inc.  All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#
# Contact information: Union Dynamic, Inc., 601 N. Eutaw St. Suite 709
# Baltimore, MD 21201, USA, or: http://www.uniondynamic.com

use lib '@amperldir@';
use strict;
use warnings;
use Getopt::Long;
use Symbol;
use IPC::Open3;

use Amanda::Debug qw( :logging );

use AFS::PAG qw(hasafs setpag unlog);

package main;

sub usage {
    print <<EOF;
Usage: amafs-wrap --krb5principal=<afs principal> --krb5keytab=<principal keytab> --application=app [arguments...]
EOF
    exit(1);
}

sub print_and_die {
    my $msg = shift;
    die("ERROR $msg\n")
}

my $krb5princ;
my $krb5keytab;
my $application;

my @orig_argv = @ARGV;

Getopt::Long::Configure(qw{bundling pass_through});
GetOptions(
    'krb5principal=s'	 => \$krb5princ,
    'krb5keytab=s'	     => \$krb5keytab,
    'application=s'	     => \$application,
) or usage();

Amanda::Debug::debug("Arguments: " . join(' ', @orig_argv));

#Log in to amanda and call the target app with the rest of the arguments.
hasafs()
    or print_and_die(
        "AFS not installed on this system?");

my($wtr, $rdr, $err, $pid);
my $cmd = "kinit $krb5princ -k -t $krb5keytab";

$err = Symbol::gensym;
$pid = open3($wtr, $rdr, $err, $cmd);
close $wtr;
waitpid $pid, 0;
close $rdr;
close $err;

$? == 0
    or print_and_die(
        "Failed to kinit for principal $krb5princ");

setpag();

$err = Symbol::gensym;
$pid = open3($wtr, $rdr, $err, 'aklog');
close $wtr;
waitpid $pid, 0;
close $rdr;
close $err;

$? == 0
    or print_and_die(
        "Failed to acquire AFS tokes for principal, $krb5princ.");

my @app_cmd = ($application);
push(@app_cmd, @ARGV);

system(@app_cmd);
my $exit = $?;

unlog();

exit $exit;