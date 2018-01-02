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
#				- Term::ReadPassword::Win32
#				- Net::LDAP
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
use 5.010;

use Getopt::Long qw(:config ignore_case);
use Pod::Usage;
use Term::ReadPassword::Win32 qw(read_password);
use Net::LDAP;
use Math::Round;

use Data::Dumper qw(Dumper);

# Variables to hold options.
my $help = '';
my $man = '';
my $verbose = 1;
my $yes = '';
my $days = 90;
my $noop = '';
my $base_dn = '';
my $bind_account = '';
my $bind_ask_pass = '';
my $bind_pass = '';
my @ldap_servers;
my @exclusions;

# Variables to hold data internal to the script.
my @accounts;
my $epoch_date;
my $ldap_obj;
my $ldap_filter = '';
my $ldap_attrs = [
	'uid',
	'shadowExpire',
	'shadowLastChange',
];
my $seconds_in_day = 86400;

GetOptions (
	'verbose!' => \$verbose,
	'yes' => \$yes,
	'days=i' => \$days,
	'noop|dry-run' => \$noop,
	'help' => \$help,
	'man' => \$man,
	'server=s' => \@ldap_servers,
	'base-dn=s' => \$base_dn,
	'bind-account=s' => \$bind_account,
	'bind-ask-pass' => \$bind_ask_pass,
	'bind-pw=s' => \$bind_pass,
	'exclude=s' => \@exclusions,
)
	or pod2usage(2);

pod2usage(-exitval => 0, -verbose => 0) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

if ($verbose) {
	print "Runtime options...\n";
	print "- verbose: $verbose\n";
	print "- yes: $yes\n";
	print "- days: $days\n";
	print "- noop: $noop\n";
	print "- ldap servers: " . join(", ", @ldap_servers) . "\n";
	print "- base_dn: $base_dn\n";
	print "- bind user: $bind_account\n";
	print "- bind pass: $bind_pass\n";
	print "- ARGV accounts: " . join(", ", @ARGV) . "\n";
}

# Get the Epoch date in days.
# $days + 1 because LDAP filters only allow '<='.
$epoch_date = round((time() / $seconds_in_day)) - ($days + 1);
if ($verbose) {
	print "Cut off days, date: $epoch_date, " . localtime($epoch_date * $seconds_in_day) . "\n";
}

# Finding the LDAP server and base DN.
if (@ldap_servers == 0) {
	if ($verbose) {
		print "Using /etc/openldap/ldap.conf to find ldap server(s).\n";
	}
	#TODO: Make this more flexible, and don't rely on a fixed location.
	open(LDAPCONF, "/etc/openldap/ldap.conf") 
		or die "ERROR: /etc/openldap.ldap.conf not found.";
	while (<LDAPCONF>) {
		chomp; 
		if ($_ =~ m/(^URI)/) {
			push @ldap_servers, (split / /, $_)[1];
		} elsif ($_ =~ m/(^BASE)/ && !$base_dn) {
			$base_dn = (split " ", $_)[1];
		}
	}
} elsif ($verbose) {
	print "Using provided ldap server(s): ";
}

if ($verbose) {
	print "- ldap servers: " . join(",", @ldap_servers) . "\n";
	print "- base dn: $base_dn\n";
}

if (!$bind_account) {
	$bind_account = getpwuid($<);
	if (!$bind_account) {
		die "ERROR: Account is blank.\n";
	}
} 

# Building DN for the bind user
$bind_account = "cn=${bind_account},${base_dn}";
if ($verbose) {
	print "- bind account: $bind_account\n";
}

if ($bind_ask_pass && !$bind_pass) {
	$bind_pass = read_password("Bind account password: ");
	if (!$bind_pass) {
		die "ERROR: Password is blank.\n";
	}
} elsif ($verbose && !$bind_pass) {
	print "Attempting anonymous bind...\n";
}

# Checking to see if any accounts were passed via the command line.
if (@ARGV != 0) {
	if ($verbose) {
		print "Using accounts passed via command line...\n";
	}
	foreach (@ARGV) {
		if ($verbose) {
			print "- $_\n";
		}
		push @accounts, $_;
	}
} else {
	if ($verbose) {
		print "Finding accounts in LDAP directory...\n";
	}
}

#TODO: Check to make sure sever is reachable.
#TODO: Enable STARTTLS or SSL/TLS option.
# Server failover by passing in an array.
$ldap_obj = Net::LDAP->new(@ldap_servers, timeout=>30) or die $@;
my $ldap_mesg = $ldap_obj->bind;
if (@accounts != 0) {
	# Constructing an LDAP filter for accounts passed on the command line
	# rather then serching for them.
	$ldap_filter = "(&(objectClass=inetOrgPerson)(shadowExpire<=$epoch_date)(|";
	foreach (@accounts) {
		$ldap_filter = $ldap_filter . "(cn=$_)";
	}
	$ldap_filter = $ldap_filter . "))";
	if ($verbose) {
		print "Constructed ldap filter: $ldap_filter\n";
	}
} else {
	$ldap_filter = "(&(objectclass=inetOrgPerson)(shadowExpire>=1)(shadowExpire<=$epoch_date))";
	if ($verbose) {
		print "Constructed ldap filter: $ldap_filter\n";
	}
}

$ldap_mesg = $ldap_obj->search(
	base => $base_dn,
	filter => $ldap_filter,
	attrs => $ldap_attrs,
);

if ($ldap_mesg->code) {
	die $ldap_mesg->error;
}

print "Accounts to process...\n";
foreach my $entry ($ldap_mesg->entries) {
	if (!grep { $_ eq $entry->get_value("uid") } @exclusions) {
		print "- ".
			$entry->get_value("uid").
			":\t".
			$entry->get_value("shadowExpire").
			",\t".
			localtime($entry->get_value("shadowExpire") * $seconds_in_day).
			"\n";
		if (@accounts == 0) {
			push @accounts, $entry->get_value("uid");
		}
	}
}

# Closing the LDAP connection because we have a list of accounts.
$ldap_mesg = $ldap_obj->unbind;

if (!$yes) {
	print "Archive accounts? [Y/N]: ";
	chomp(my $input = <STDIN>);
	if ($input =~ /^[Y|y|yes]$/) {
		print "Continuing...\n";
	} else {
		exit(0)
	}
}

# Do stuff.

__END__

=head1 NAME

userarchiver -	Finds and archives inactive user accounts.

=head1 SYNOPSIS

  sample [options] [arguments]

  Arguments:
	/archive/destination user user user ...		
		Destination for the archives.
		Space separated list of users to archive.

  Options:
	--help				Brief help message.
	--man				Full documentation.
	--verbose			More feedback from the program.
	--yes				Yes, do whatever without user confirmation.
	--days N			Number of days the account should be inactive.
	--noop | --dry-run		No op, don't do anything just list the actions.
	--server ldap(s)://<server>:<port>	LDAP server to query, specify multiple times for multiple servers.
	--base-dn			Base Distinguished Name to query on the LDAP server.
	--bind-account		Acount used to bind to the LDAP server.
	--bind-pw-ask		Ask for the bind account password.
	--bind-pw			Password for the bind account. Overrides asking for password.
	--exclude <account>		Do not process specified accounts.
	--config /conf/file		Location of the config file. (Not operational)
	--encrypt			Enable encryption of the archive. (Not operational)
	--compress			Enable compression of the archive. (Not operational)
	--compress-method <method>	Select compression method. (Not operational)
	--server-file /ldap/file	Location of an ldap.conf file. (Not operational)

=head1 ARGUMENTS

The script takes a location for the archives and a space separated list of 
accounts to archive. The LDAP server will queried, and if the account has been 
inactive for more then the number of specified days, the user will be asked for 
confirmation.

The destination for the archives is needed at a minimum, and without an account 
list, the script will search for any accounts which have been inactive outside 
the provided time window. The search is an exclusive operation. An account will 
need to be inactive for N+1 days to be considered for archiving.

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

