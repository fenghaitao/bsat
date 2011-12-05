#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Getopt::Long;
use GraphBuilder;
use Preprocessor;
use File::Path;
use PathParser;
use EasyGraph;

our $map_file = "";
our $dep_file = "";
our $color_file = "";
our $out_dir = "";
##Print the whole image by Default
our $prune_level = 0;
our $prune_nodes = "";
our $split_level = 0;
our $module_names = "";
our $module_dirs = "";

our @querying_modules = ();
our %module_nodes = ();
our %module_edges = ();
our %reaching = ();

&GetOptions("map|map_file=s" =>\$map_file,
            "dep|dep_file=s" =>\$dep_file,
            "color|color_file=s" =>\$color_file,
            "out_dir=s" =>\$out_dir,
            "prune-level=s" =>\$prune_level,
            "prune-nodes=s" =>\$prune_nodes,
            "split-level=s" =>\$split_level,
            "module_names=s" =>\$module_names,
            "module_dirs=s" =>\$module_dirs,
);
{
    if ($map_file eq "" || $dep_file eq "" || $color_file eq "" || $out_dir eq "")
    {
        print "-map map_file && -dep dep_file && -color color_file && -out_dir package_out_dir should be specified\n";
        exit(1);
    }
}

our @color = ();
our @enter_time = ();
our @leave_time = ();
our $time = 0;
our @dfs_stack = ();

&main;

sub dfs
{
    my ($node) = @_;
    $module_nodes{$node} = 1;
    push(@dfs_stack, $node);
    $enter_time[$node] = $time;
    $time++;
    $color[$node] = "Gray";
    for (my $i = 0; $i < $dg_n_preds[$node]; $i++)
    { 
        my $pred = $dg_preds[$node][$i]; 
        if ($color[$pred] eq "White")
        {
            my $edge = "$node -> $pred";
            my $obj1 = $dg_build_objects[$node];
            my $obj2 = $dg_build_objects[$pred];
            $module_edges{$edge} = "$obj1 -> $obj2";
            dfs($pred);
        }elsif ($color[$pred] eq "Gray")
        {
            die "Fatal error: SCC exists in the dependence graph\n";
        }elsif ($color[$pred] eq "Black")
        {
            if ($enter_time[$node] > $enter_time[$pred])
            {
                #print "Cross edge found\n";
                my $edge = "$node -> $pred";
                if (! exists($reaching{$edge}))
                {
                    my $obj1 = $dg_build_objects[$node];
                    my $obj2 = $dg_build_objects[$pred];
                    $module_edges{$edge} = "$obj1 -> $obj2";
                }

                for (my $i = $#dfs_stack - 1; $i >= 0; $i--)
                {
                    my $dfs_node = $dfs_stack[$i];
                    my $forward_edge = "$dfs_node -> $pred";
                    $reaching{$forward_edge} = 1;
                    if (exists($module_edges{$forward_edge}))
                    {
                        delete($module_edges{$forward_edge});
                    }
                }
           }
       }
    }
    $color[$node] = "Black";
    pop(@dfs_stack);
}

sub produce_module_graph 
{
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        $color[$i] = "White";
    }

    for (my $i = 0; $i <= $#querying_modules; $i++)
    {
        my $key = $querying_modules[$i];
        if ($color[$key] eq "White")
        {
            dfs($key);
        }
    }
}

sub main
{
    preprocess($map_file);

    ## prune some nodes, too many edges connected with them.
    if ($prune_nodes ne "")
    {
        my @fields = split(/\ /, $prune_nodes);
        for (my $j = 0; $j <= $#fields; $j++)
        {
            my $node = $fields[$j];
            $dg_pruning_objects{$node} = 1;
        }
    }

    build_dependence_graph($dep_file);
    compute_node_depths();
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
                push(@querying_modules, $key);
            }
        }
    }

    if ($module_dirs ne "")
    {
        my @fields   = split(/\ +/, $module_dirs);
        for (my $i = 0; $i <= $#fields; $i++)
        {
            my $dir = $fields[$i];
            for (my $j = 0; $j < $dg_n_nodes; $j++)
            {
                my $obj = $dg_build_objects[$j];
                my $obj_dir = "";
                if (exists($nodes{$obj}))
                {
                    my $index = $nodes{$obj}; 
                    $obj_dir = $build_dirs[$index];
                }
                if ($obj_dir =~ m/^$dir/)
                {
                    push(@querying_modules, $j);
                }
            }
        }
    }

    if ($module_names ne "" || $module_dirs ne "")
    {
        if ($#querying_modules < 0)
        {
            print "The specified module names or dir names could not be found in the build database\n";
            exit(1);
        }
    }

    ## prune nodes less than prune_level 
    prune_node_with_small_depth($prune_level);

    if ($#querying_modules >= 0)
    {
        produce_module_graph();
        for (my $i = 0; $i < $dg_n_nodes; $i++)
        {
            if (! exists($module_nodes{$i}))
            {
                $ge_pruned_objects{$i} = 1;
            }
        }
        %ge_edges = %module_edges;
    }else
    {
        %ge_edges = %dg_edges;
    }

    my %pruned_objects = %ge_pruned_objects;

    $out_dir =~ s/\ /_/g;
    mkpath($out_dir);
    if ($split_level > 0)
    {
        my $top_filename  = "$out_dir/top.txt";
        my $top_file;
        open($top_file, ">", $top_filename) or die "The obj file $top_filename could not be opened\n";
        for (my $i = $prune_level; $i < $split_level; $i++)
        {
            my $depth = $i;
            my @fields = split(/\ /, $dg_depth_nodes[$i]);
            for (my $j = 0; $j <= $#fields; $j++)
            {
                my $dg_node = $fields[$j];
                $ge_pruned_objects{$dg_node} = 1;
            }
        }

        dump_header($top_file);
        dump_color_section($top_file);
        dump_node_section($top_file);
        dump_edge_section($top_file);
        close($top_file);

        system "graph-easy $top_filename --as png";

        %ge_pruned_objects =  %pruned_objects;
        for (my $i = $split_level + 1; $i < $dg_max_depth; $i++)
        {
            my $depth = $i;
            my @fields = split(/\ /, $dg_depth_nodes[$i]);
            for (my $j = 0; $j <= $#fields; $j++)
            {
                my $dg_node = $fields[$j];
                $ge_pruned_objects{$dg_node} = 1;
            }
        }

        my $bottom_filename = "$out_dir/bottom.txt";
        my $bottom_file;
        open($bottom_file, ">", $bottom_filename) or die "The obj file $top_filename could not be opened\n";

        dump_header($bottom_file);
        dump_color_section($bottom_file);
        dump_node_section($bottom_file);
        dump_edge_section($bottom_file);

        close($bottom_file);
        system "graph-easy $bottom_filename --as png";
    }else
    {
        my $module_filename = "$out_dir/modules_dg.txt";

        my $module_file;
        open($module_file, ">", $module_filename) or die "The obj file $module_filename could not be opened\n";

        dump_header($module_file);
        dump_color_section($module_file);
        dump_node_section($module_file);
        dump_edge_section($module_file);

        close($module_file);
        system "graph-easy $module_filename --as png";

        my $description_filename = "$out_dir/description.txt";
        my $desc; 
        open($desc, ">", $description_filename) or die "The obj file $description_filename could not be opened\n";
        print $desc "Description of the querying result:\n";
        if ($module_names ne "")
        {
            print $desc "    The querying module names are: $module_names\n";
        }
        if ($module_dirs ne "")
        {
            print $desc "    The querying directories are: $module_dirs\n";
        }
        print $desc "\n";
        print $desc "The following modules are involved with this querying request:\n";
        for (my $i = 0; $i < $dg_n_nodes; $i++)
        {
            if (exists($module_nodes{$i}))
            {
                my $obj = $dg_build_objects[$i];
                print $desc "    $obj\n";
            }
        }

        print $desc "\n";
        print $desc "Please view the modules_dg.png for detailed dependence information.\n";
        close($desc);
    }
}
