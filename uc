#!/usr/bin/env perl
use strict;
use warnings;
use POSIX qw(EXIT_SUCCESS);

for (my $i = 0; $i < scalar(@ARGV); $i++) {
	print(uc($ARGV[$i]));
	if ($i < scalar(@ARGV) - 1) {
		print(' ');
	}
}
print("\n");

exit(EXIT_SUCCESS);
