#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Getopt::Long;
use Preprocessor;
use GraphCreator;
use GraphBuilder;

our $map_file = "";
our $dep_file = "";
our $out_file = "";
&GetOptions("map|map_file=s" =>\$map_file,
            "dep|dep_file=s" =>\$dep_file,
            "out|out_file=s" =>\$out_file,
);
{
    if ($map_file eq "" || $dep_file eq "" || $out_file eq "")
    {
        print "-map map_file && -dep dep_file && -out out_file should be specified\n";
        exit(1);
    }
}

&main;

sub main
{
    preprocess($map_file);
    build_dependence_graph($dep_file);
    my $keys = keys(%dg_edges);
    prune_forward_edges();
    $keys = keys(%dg_edges);

    my $out;
    open($out, ">", $out_file) or die "The out file could not be opened\n";

    foreach my $key (keys %dg_edges)
    {
        my $value = $dg_edges{$key};
        my @fields = split(/\ ->\ /, $value);
        my $obj1 = $fields[0];
        my $obj2 = $fields[1];
        print $out "$value\n";
    }

    close($out);
}
