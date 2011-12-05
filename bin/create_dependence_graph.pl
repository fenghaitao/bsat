#!/usr/bin/perl -I../lib

use strict;
use warnings;
use GraphCreator;
use File::Path;
use File::Basename;

use Getopt::Long;

our $map_file = "";
our $log_file = "";
our $out_file = "";
&GetOptions("map|map_file=s" =>\$map_file,
            "log|log_file=s" =>\$log_file,
            "out|out_file=s" =>\$out_file,
);
{
    if ($map_file eq "" || $log_file eq "" || $out_file eq "")
    {
        print "-map map_file && -log log_file && -out out_file should be specified\n";
        exit(1);
    }
}

&main;

sub main
{
    create_dependence_graph($map_file, $log_file);

    my $dir = dirname($out_file);
    mkpath($dir);
    my $out;
    open($out, ">", $out_file) or die "The out file could not be opened\n";

    foreach my $key (keys %edges)
    {
        my $value = $edges{$key};
        print $out "$value\n";
    }

    close($out);
}
