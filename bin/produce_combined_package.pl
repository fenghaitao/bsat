#!/usr/bin/perl

use strict;
use warnings;

&main;

sub main
{
    system "./combine_packages.pl -map ../input/android_modules.map -dep ../output/android_packaging.dg -color ../input/color.txt -pout ../output/combine_packaging/packages.txt -gout ../output/combine_packaging/graph.txt";
}
