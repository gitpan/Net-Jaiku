use Test::More tests => 2;
use Net::Jaiku;

SKIP: {
	skip "Please set environment variables JAIKU_USER and JAIKU_KEY to run these tests", 2
		unless $ENV{JAIKU_USER} && $ENV{JAIKU_KEY};

	$jaiku = Net::Jaiku->new(
		username => $ENV{JAIKU_USER},
		userkey  => $ENV{JAIKU_KEY}
	);

	my $test_line = 'Testing Net::Jaiku';
	ok( $jaiku->setPresence(message => $test_line) );

	my $rv = $jaiku->getMyPresence;
	ok( $rv->line eq $test_line );

}
