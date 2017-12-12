#!/usr/bin/env perl
#===============================================================================
#
#         FILE: userarchiver.pl
#
#        USAGE: ./userarchiver.pl  
#
#  DESCRIPTION: Archive user accounts
#
#      OPTIONS: 
# REQUIREMENTS:
#				- Getopt::Long
#				- Pod::Usage
#
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Ryan Quinn rq@oii.org
# ORGANIZATION: OII
#      VERSION: 0.1
#      CREATED: 12/08/2017 02:18:07 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

use Getopt::Long qw(:config ignore_case);
use Pod::Usage;

use Data::Dumper qw(Dumper);

my $verbose = '';
my $yes = '';
my $days = 90;
my $noop = '';
my $help = '';
my $man = '';
my $process_argv = '';

GetOptions ('verbose!' => \$verbose,
			'yes' => \$yes,
			'days=i' => \$days,
			'noop|dry-run' => \$noop,
			'help' => \$help,
			'man' => \$man)
	or
		pod2usage(2);

pod2usage(-exitval => 0, -verbose => 0) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

print "verbose: $verbose\n";
print "yes: $yes\n";
print "days: $days\n";
print "noop: $noop\n";
print "\n";

print Dumper \@ARGV;

print "\n";

# Checking to see if any accounts were passed via the command line.
if (@ARGV != 0) {
	if ($verbose) {
		print "Processing passed accounts...\n";
		foreach (@ARGV) {
			print "- $_\n";
		}
	}
	$process_argv = 1;
}



__END__

=head1 NAME

userarchiver -	Finds and archives inactive user accounts.

=head1 SYNOPSIS

  sample [options] [arguments]

  Arguments:
	user user user ...		Space separated list of users to archive

  Options:
	--help				Brief help message
	--man				Full documentation
	--verbose			More feedback from the program
	--yes				Yes, do whatever without user confirmation
	--days N			Number of days the account should be inactive
	--noop | --dry-run		No op, don't do anything just list the actions 
	--dest /dest/path		Destination for the archive files (Not operational)
	--config /conf/file		Location of the config file (Not operational)
	--encrypt			Enable encryption of the archive (Not operational)
	--compress			Enable compression of the archive (Not operational)
	--compress-method <method>	Select compression method (Not operational)
	--server ldap(s)://<server>:<port>	LDAP server to query, specify multiple times for multiple servers (Not operational)

=head1 ARGUMENTS

The script takes a space separated list of accounts to archive. The LDAP server
will queried, and if the account has been inactive for fewer then the number of
specified days, the user will be asked for confirmation.

Without any arguments, the script will search for any accounts which have been 
inactive outside the provided time window. The search is an exclusive operation.
An account will need to be inactive for N+1 days to be considered for archiving.

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Prints the manual page and exit.

=item B<--verbose>

Print what the script is doing.

=item B<--yes>

Torpedos away! The scripts executes without asking for confirmation from the 
user.

=item B<--days> N

The number of days an account needs to be inactive before action is taken. The
default number of days is 90.

=item B<--noop>

No op, or dry run. The script doesn't do anything when this option enabled, it 
just reports what it would do.

=item B<--server> ldap(s)://<server>:<port>

Specify the ldap server to query. Multiple LDAP servers can be specified by 
adding a second instance, but this is only for redundancy purposes. The script
won't query both servers. It will just step through the list until it gets a
response.

The default is to try and read the URI(s) from "/etc/openldap/ldap.conf".
Needless to say, the script is going to fail if it doesn't have a LDAP server
to query.

=back

=head1 DESCRIPTION

B<This program> will search for inactive users and archive their home 
directories.

=cut

