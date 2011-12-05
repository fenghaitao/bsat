#!/usr/bin/perl

use strict;
use warnings;

&main;

sub main
{
    system "./create_dependence_graph.pl -map ../input/android_modules.map -log ../input/android_make.log -out ../output/android_all.dg";
    system "./prune_pseduo_objects.pl -map ../input/android_modules.map -dep ../output/android_all.dg -out ../output/android_modules.dg";
    system "./prune_forward_edges.pl -map ../input/android_modules.map -dep ../output/android_modules.dg -out ../output/android_packaging.dg";
}
