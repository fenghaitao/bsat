#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
our $module_names = "";
&GetOptions("m|module_names=s" =>\$module_names,
);
{
    if ($module_names eq "")
    {
        print "-m module_names should be specified.\n";
        exit(1);
    }
}

&main;

sub main
{
    my $out_dir = "../output/querying_results/using/";
    system "./create_use_graph.pl -map ../input/android_modules.map -dep ../output/android_modules.dg -color ../input/color.txt -out_dir \"$out_dir\" -module_names \"$module_names\"";
}
