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

package Amanda::Script::amafs_backup;
use base qw(Amanda::Script);
use Symbol;
use IPC::Open3;
use AFS::PAG qw(hasafs setpag unlog);
use Amanda::Config qw( :getconf :init );
use Amanda::Debug qw( :logging );
use Amanda::Util qw( :constants );
use Amanda::Paths;
use Amanda::Constants;

sub new {
    my $class = shift @_;

    my ($execute_where,
        $config,
        $host,
        $disk,
        $device,
        $level,
        $index,
        $message,
        $collection,
        $record,
        $principal,
        $keytab,
        $afs_root,
        $backup_root) = @_;

    my $self = $class->SUPER::new($execute_where, $config);

    $self->{execute_where} = $execute_where;
    $self->{config}        = $config;
    $self->{host}          = $host;

    if (defined $disk) {
	$self->{disk}      = $disk;
    } else {
	$self->{disk}      = $device;
    }
    if (defined $device) {
	$self->{device}    = $device;
    } else {
	$self->{device}    = $disk;
    }

    $self->{level}         = [ @{$level} ]; # Copy the array
    $self->{index}         = $index;
    $self->{message}       = $message;
    $self->{collection}    = $collection;
    $self->{record}        = $record;

    $self->{principal}          = $principal;
    $self->{keytab}             = $keytab;

    if (defined $afs_root) {
    $self->{afs_root}      = $afs_root;
    } else {
    $self->{afs_root}      = '/afs';
    }

    if (defined $backup_root) {
	$self->{backup_root}        = $backup_root;
    } else {
	$self->{backup_root}        = '.backup/';
    }

    return $self;
}

sub command_support {
   my $self = shift;

   print "CONFIG YES\n";
   print "HOST YES\n";
   print "DISK YES\n";
   print "MESSAGE-LINE YES\n";
   print "MESSAGE-XML NO\n";
   print "EXECUTE-WHERE YES\n";
}

sub afs_begin {
    my $self = shift;

    hasafs()
        or $self->print_to_server_and_die(
            "AFS not installed on this system?",
            $Amanda::Script_App::ERROR);

    my($wtr, $rdr, $err, $pid);
    my $cmd = "kinit $self->{principal} -k -t $self->{keytab}";

    $err = Symbol::gensym;
    $pid = open3($wtr, $rdr, $err, $cmd);
    close $wtr;
    waitpid $pid, 0;
    close $rdr;
    close $err;

    $? == 0
        or $self->print_to_server_and_die(
            "Failed to kinit for principal $self->{principal}",
            $Amanda::Script_App::ERROR);

    setpag();

    $err = Symbol::gensym;
    $pid = open3($wtr, $rdr, $err, 'aklog');
    close $wtr;
    waitpid $pid, 0;
    close $rdr;
    close $err;

    $? == 0
        or $self->print_to_server_and_die(
            "Failed to acquire AFS tokes for principal, $self->{principal}.",
            $Amanda::Script_App::ERROR);
}

sub afs_end {
    unlog();
}

sub afs_mount {
    my $self = shift;

    my($wtr, $rdr, $err, $pid);

    my $cmd = "vos backup -id $self->{volume} -cell $self->{cell}";

    $err = Symbol::gensym;
    $pid = open3($wtr, $rdr, $err, $cmd);
    close $wtr;
    waitpid $pid, 0;
    close $rdr;
    close $err;

    $? == 0
        or $self->print_to_server_and_die(
            "Failed to create backup for volime $self->{volume}.",
            $Amanda::Script_App::ERROR);


    $cmd = "fs checkvolumes";

    $err = Symbol::gensym;
    $pid = open3($wtr, $rdr, $err, $cmd);
    close $wtr;
    waitpid $pid, 0;
    close $rdr;
    close $err;

    #Mount the volume in the backup area.
    my $cmd = "fs mkmount -dir " . $self->{target}
                        . " -vol " . $self->{volume} . '.backup'
                        . " -cell " . $self->{cell};

    $err = Symbol::gensym;
    $pid = open3($wtr, $rdr, $err, $cmd);
    close $wtr;
    waitpid $pid, 0;
    close $rdr;
    close $err;

    $? == 0
        or $self->print_to_server_and_die(
            "Failed to mount backup for volime $self->{volume}.",
            $Amanda::Script_App::ERROR);
}

sub afs_umount {
    my $self = shift;

    #Mount the volume in the backup area.
    my $cmd = "fs rmmount -dir " . $self->{target};

    my($wtr, $rdr, $err, $pid);
    $err = Symbol::gensym;
    $pid = open3($wtr, $rdr, $err, $cmd);
    close $wtr;
    waitpid $pid, 0;
    close $rdr;
    close $err;
}

sub amfs_setup {
    my $self = shift;

    if (defined $self->{execute_where} && $self->{execute_where} ne "client") {
	    $self->print_to_server_and_die(
            " Script must be run on the client 'execute-where client'",
            $Amanda::Script_App::ERROR);
    }

    if (!defined $self->{device}) {
        if ($self->{action} eq "check") {
            return;
        } else {
            $self->print_to_server_and_die("'--device' is not provided",
                        $Amanda::Script_App::ERROR);
        }
    }

    #Get the target from the device name cell.name/volume
    my $device = $self->{device};

    $device = $self->{target} if defined $self->{target};

    if($device =~ /(\S+)\/(\S+)$/) {
        $self->{cell} = $1;
        $self->{volume} = $2;
    } else {
        $self->print_to_server_and_die(
                    "Invalid volume specification: $device",
                    $Amanda::Script_App::ERROR);
    }

    #Build the target directory.
    $self->{target} = $self->{afs_root}
                    . '/' . $self->{cell}
                    . '/' . $self->{backup_root}
                    . '/' . $self->{volume};

}

#define a execute_on_* function for every execute_on you want the script to do
#something
sub command_pre_dle_amcheck {
    my $self = shift;

    $self->amfs_setup();

    if ($self->{error_status} == $Amanda::Script_App::GOOD) {
        $self->afs_begin();
        $self->afs_mount();
        $self->afs_end();

	    print "PROPERTY target $self->{target}\n";
    }
}

sub command_post_dle_amcheck {
    my $self = shift;

    $self->amfs_setup();

    if ($self->{error_status} == $Amanda::Script_App::GOOD) {
        $self->afs_begin();
        $self->afs_umount();
        $self->afs_end();
    }
}

sub command_pre_dle_estimate {
    my $self = shift;

    $self->amfs_setup();

    if ($self->{error_status} == $Amanda::Script_App::GOOD) {
        $self->afs_begin();
        $self->afs_mount();
        $self->afs_end();

	    print "PROPERTY target $self->{target}\n";
    }
}

sub command_post_dle_estimate {
    my $self = shift;

    $self->amfs_setup();

    if ($self->{error_status} == $Amanda::Script_App::GOOD) {
        $self->afs_begin();
        $self->afs_umount();
        $self->afs_end();
    }
}

sub command_pre_dle_backup {
    my $self = shift;

    $self->amfs_setup();

    if ($self->{error_status} == $Amanda::Script_App::GOOD) {
        $self->afs_begin();
        $self->afs_mount();
        $self->afs_end();

	    print "PROPERTY target $self->{target}\n";
    }
}

sub command_post_dle_backup {
    my $self = shift;

    $self->amfs_setup();

    if ($self->{error_status} == $Amanda::Script_App::GOOD) {
        $self->afs_begin();
        $self->afs_umount();
        $self->afs_end();
    }
}

package main;

sub usage {
    print <<EOF;
Usage: amafs <command> --config=<config> --host=<host> --disk=<disk> --device=<device> --level=<level> --index=<yes|no> --message=<text> --collection=<no> --record=<yes|no> --calcsize. --krb5principal=<afs principal> --krb5keytab=<principal keytab>
EOF
    exit(1);
}

my $opt_version;
my $opt_execute_where;
my $opt_config;
my $opt_host;
my $opt_disk;
my $opt_device;
my @opt_level;
my $opt_index;
my $opt_message;
my $opt_collection;
my $opt_record;

my $opt_krb5princ;
my $opt_krb5keytab;
my $opt_afs_root = '/afs';
my $opt_backup_root = '.backup';

my @orig_argv = @ARGV;

Getopt::Long::Configure(qw{bundling});
GetOptions(
    'version'            => \$opt_version,
    'execute-where=s'    => \$opt_execute_where,
    'config=s'           => \$opt_config,
    'host=s'             => \$opt_host,
    'disk=s'             => \$opt_disk,
    'device=s'           => \$opt_device,
    'level=s'            => \@opt_level,
    'index=s'            => \$opt_index,
    'message=s'          => \$opt_message,
    'collection=s'       => \$opt_collection,
    'record'             => \$opt_record,
    'krb5principal=s'	 => \$opt_krb5princ,
    'krb5keytab=s'	     => \$opt_krb5keytab,
    'afs-root=s'         => \$opt_afs_root,
    'backup-root=s'      => \$opt_backup_root,
) or usage();

if (defined $opt_version) {
    print "amafs-backup-" . $Amanda::Constants::VERSION , "\n";
    exit(0);
}

my $script = Amanda::Script::amafs_backup->new(
        $opt_execute_where,
        $opt_config,
        $opt_host,
        $opt_disk,
        $opt_device,
        \@opt_level,
        $opt_index,
        $opt_message,
        $opt_collection,
        $opt_record,
        $opt_krb5princ,
        $opt_krb5keytab,
        $opt_afs_root,
        $opt_backup_root);

Amanda::Debug::debug("Arguments: " . join(' ', @orig_argv));

$script->do($ARGV[0]);