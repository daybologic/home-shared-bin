#!/usr/bin/perl -w

use strict;
use File::Copy;

my $ret = 1;
if ( opendir(D, '.') ) {
  my $cuml = 0;
  while ( my $f = readdir(D) ) {
    if ( $f =~ m/^hda2_(\d{1,3})\.tar$/ ) {
      if ( $1 > $cuml ) {
        $cuml = $1;
      }
    }
  }
  move('hda2.tar', 'hda2_' . ($cuml+1) . '.tar') || die $!;
  closedir(D);
  $ret = 0;
}

exit $ret;
