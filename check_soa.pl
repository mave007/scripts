#!/usr/bin/perl -w

use strict;

use Net::DNS;

$|=1;

my $dom = $ARGV[0];

my $res = Net::DNS::Resolver->new(
	defnames    => 0
);

my $query=$res->query($dom,'NS');
my %servers;
if($query)
{
	foreach my $rr (grep { $_->type eq 'NS' } $query->answer)
	{
		@{$servers{lc $rr->nsdname}}=();
	};
}
else
{
	print "Unknown domain: $dom\n";
	exit 1;
};;

foreach my $server (keys %servers)
{
	$query=$res->query($server,'A');
	if($query)
	{
		foreach my $rr (grep { $_->type eq 'A' } $query->answer)
		{
			push @{$servers{$server}},$rr->address;
		};
	};
	
	$query=$res->query($server,'AAAA');
	if($query)
	{
		foreach my $rr (grep { $_->type eq 'AAAA' } $query->answer)
		{
			push @{$servers{$server}},$rr->address;
		};
	};

	if(scalar @{$servers{$server}} ==0)
	{
		print "There is no address for $server\n";
	}
	else
	{
		foreach my $ip (@{$servers{$server}})
		{
			my $auth=Net::DNS::Resolver->new(
				nameservers	=> [$ip],
				recurse		=> 0,
				defnames	=> 0,
				tcp_timeout	=> 30,
				udp_timeout	=> 10,
				retry		=> 2,
			);
			$query=$auth->query($dom,'SOA');
			if ($query)
			{
				foreach my $rr (grep { $_->type eq 'SOA' } $query->answer)
				{
					print "$server ($ip) has serial number ".$rr->serial;
				};
			}
			else
			{
				print "There was no response from $server ($ip)";
			};
			print "\n";
		};
	};
};

