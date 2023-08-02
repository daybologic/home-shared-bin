#!/usr/bin/perl -w

use strict;

my @buffer = <STDIN>;
my $c = scalar(@buffer);
exit 1 unless ($c);

while ($c--) {
	my $line = pop @buffer;
	last unless defined $line;
	print $line;
}

exit 0;
