#!/usr/bin/perl

use strict;
use warnings;

&main;

sub main
{
    my $prune_level = 0;
    for (my $i = 5; $i <= 8; $i++)
    {
        my $split_level = $i;
        my $out_dir = "../output/full_graph/splited_by_depth/$split_level";
        system "./create_easy_graph.pl -map ../input/android_modules.map -dep ../output/android_modules.dg -color ../input/color.txt -out_dir $out_dir -split-level=$split_level -prune-level=$prune_level";
    }
}
