#!/usr/bin/env perl
use strict;
use Net::DNS::Packet;
use MIME::Base64;
use LWP::Protocol::https;
use LWP::UserAgent;
#
my $server = 'https://cloudflare-dns.com/dns-query';
our @ARGV;
# Usage: DoHclient.pl QNAME QTYPE QCLASS
my $qname = shift @ARGV;
if (!defined($qname)) { $qname = '.'; }
my $qtype = shift @ARGV;
if (!defined($qtype)) { $qtype = 'A'; }
my $qclass = shift @ARGV;
if (!defined($qclass)) { $qclass = 'IN'; }
#
my $q = new Net::DNS::Packet($qname, $qtype, $qclass);
$q->header->rd(1);
my $base64 = encode_base64($q->data);
chomp $base64;
my $url = sprintf("%s?dns=%s", $server, $base64);
my $ua = LWP::UserAgent->new();
my $r = $ua->get($url);
if ($r->is_success) {
	my $packet = new Net::DNS::Packet(\($r->decoded_content));
	$packet->print;
} else {
	die $r->status_line;
}
