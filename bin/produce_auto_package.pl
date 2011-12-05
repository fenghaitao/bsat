#!/usr/bin/perl

use strict;
use warnings;

&main;

sub main
{
    system "./build_packages.pl -map ../input/android_modules.map -dep ../output/android_packaging.dg -color ../input/color.txt -pout ../output/auto_packaging/order.txt -gout ../output/auto_packaging/graph.txt -prune-level=1";
}
