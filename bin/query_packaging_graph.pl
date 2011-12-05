#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
our $module_names = "";
our $module_dirs  = "";
&GetOptions("m|module_names=s" =>\$module_names,
            "d|module_dirs=s" =>\$module_dirs,
);
{
    if ($module_names eq "" && $module_dirs eq "")
    {
        print "-m module_names || -d module_dirs should be specified.\n";
        exit(1);
    }
}

&main;

sub main
{
    my $out_dir = "../output/querying_results/packaging";
    system "./create_easy_graph.pl -map ../input/android_modules.map -dep ../output/android_packaging.dg -color ../input/color.txt -out_dir \"$out_dir\" -module_names \"$module_names\" -module_dirs \"$module_dirs\" -split-level=0";
}
