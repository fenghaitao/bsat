#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use File::Path;
use Preprocessor;
use GraphBuilder;
use EasyGraph;

our $map_file = "";
our $dep_file = "";
our $color_file = "";
our $pout_file = "";
our $gout_file = "";
#Do not prune anything by default
our $prune_level = 0;
&GetOptions("map|map_file=s" =>\$map_file,
            "dep|dep_file=s" =>\$dep_file,
            "color|color_file=s" =>\$color_file,
            "pout|pout_file=s" =>\$pout_file,
            "gout|gout_file=s" =>\$gout_file,
            "prune-level=s" =>\$prune_level,
);
{
    if ($map_file eq "" || $dep_file eq "" || $color_file eq "" || $pout_file eq "" || $gout_file eq "")
    {
        print "-map map_file && -dep dep_file && -color color_file && -pout package_out_file && -gout easy_graph_out_file should be specified\n";
        exit(1);
    }
}

&main;

sub main
{
    preprocess($map_file);
    build_dependence_graph($dep_file);
    compute_node_depths();
    read_color_map($color_file);

    my $p_dir = dirname($pout_file);
    mkpath($p_dir);
    my $pout;
    open($pout, ">", $pout_file) or die "The out file $pout_file could not be opened\n";

    print $pout "Total Modules: $dg_n_nodes\n";

    for (my $i = 0; $i < $dg_max_depth; $i++)
    {
        my $round = $i + 1;
        print $pout "Round $round\n";
        my @fields = split(/\ /, $dg_depth_nodes[$i]);
        for (my $j = 0; $j <= $#fields; $j++)
        {
            my $dg_node = $fields[$j];
            my $object  = $dg_build_objects[$dg_node];
            my $dir = "";
            if (exists($nodes{$object}))
            {
                my $index  = $nodes{$object};
                $dir = $build_dirs[$index];
            }
            print $pout "    $object: $dir\n";
        }
    }

    close($pout);    

    my $g_dir = dirname($gout_file);
    mkpath($g_dir);
    my $gout;
    open($gout, ">", $gout_file) or die "The out file $gout_file could not be opened\n";
    ## prune nodes less than prune_level 
    prune_node_with_small_depth($prune_level);

    for (my $i = 0; $i < $dg_max_depth; $i++)
    {
        my $depth = $i;
        my @fields = split(/\ /, $dg_depth_nodes[$i]);
        for (my $j = 0; $j <= $#fields; $j++)
        {
            my $dg_node = $fields[$j];
            for (my $k = 0; $k < $dg_n_preds[$dg_node]; $k++)
            {
                my $pred = $dg_preds[$dg_node][$k];
                if ($dg_node_depth[$pred] == $depth - 1)
                {
                    my $ge_edge = "$dg_node -> $pred";
                    my $obj1 = $dg_build_objects[$dg_node];  
                    my $obj2 = $dg_build_objects[$pred];  
                    $ge_edges{$ge_edge} = "$obj1 -> $obj2";
                } 
            }
        }
    }

    dump_header($gout);
    dump_color_section($gout);
    dump_node_section($gout);
    dump_edge_section($gout);
    close($gout);

    system "graph-easy $gout_file --as png";
}
