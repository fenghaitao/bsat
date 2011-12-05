#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Getopt::Long;
use GraphBuilder;
use Preprocessor;
use File::Path;
use EasyGraph;

our $map_file = "";
our $dep_file = "";
our $color_file = "";
our $out_dir = "";
our $module_names = "";
our %querying_modules = ();

&GetOptions("map|map_file=s" =>\$map_file,
            "dep|dep_file=s" =>\$dep_file,
            "color|color_file=s" =>\$color_file,
            "out_dir=s" =>\$out_dir,
            "module_names=s" =>\$module_names,
);
{
    if ($map_file eq "" || $dep_file eq "" || $color_file eq "" || $out_dir eq "" || "$module_names" eq "")
    {
        print "-map map_file && -dep dep_file && -color color_file && -out_dir out_dir && -module_names moudle_names should be specified\n";
        exit(1);
    }
}

&main;

sub main
{
    preprocess($map_file);
    build_dependence_graph($dep_file);
    read_color_map($color_file);

    if ($module_names ne "")
    {
        my @fields = split(/\ +/, $module_names);
        for (my $i = 0; $i <= $#fields; $i++)
        {
            my $name = $fields[$i];
            if (exists($dg_nodes{$name}))
            {
                my $key  = $dg_nodes{$name};
                $querying_modules{$key} = 1;
                my $obj = $dg_build_objects[$key];
               
                for (my $i = 0; $i < $dg_n_succs[$key]; $i++)
                {
                    my $succ = $dg_succs[$key]->[$i];
                    my $succ_obj = $dg_build_objects[$succ];
                    $querying_modules{$succ} = 1;
                    my $edge = "$succ -> $key";
                    $ge_edges{$edge} = "$succ_obj -> $obj";
                }
            }
        }
    }

    my $files_key = $dg_nodes{"files"};
    $ge_pruned_objects{$files_key} = 1;
   
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        if (! exists($querying_modules{$i}))
        {
            $ge_pruned_objects{$i} = 1;
        }
    }

    $out_dir =~ s/\ /_/g;
    mkpath($out_dir);

    my $module_filename = "$out_dir/use_graph.txt";
    my $module_file;
    open($module_file, ">", $module_filename) or die "The obj file $module_filename could not be opened\n";

    dump_header($module_file);
    dump_color_section($module_file);
    dump_node_section($module_file);
    dump_edge_section($module_file);

    close($module_file);
    system "graph-easy $module_filename --as png";
}
