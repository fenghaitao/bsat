#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Getopt::Long;
use File::Basename;
use File::Path;
use Preprocessor;
use PathParser;
use GraphBuilder;
use EasyGraph;

our $map_file = "";
our $dep_file = "";
our $color_file = "";
our $pout_file = "";
our $gout_file = "";
&GetOptions("map|map_file=s" =>\$map_file,
            "dep|dep_file=s" =>\$dep_file,
            "color|color_file=s" =>\$color_file,
            "pout|pout_file=s" =>\$pout_file,
            "gout|gout_file=s" =>\$gout_file,
);
{
    if ($map_file eq "" || $dep_file eq "" || $color_file eq "" || $pout_file eq "" || $gout_file eq "")
    {
        print "-map map_file && -dep dep_file && -color color_file && -pout package_out_file && -gout easy_graph_out_file should be specified\n";
        exit(1);
    }
}

## The packaging dir is from color_file 
#  Temp Solution
our %packaging_dirs = ();
our @packaging_dirs = ();
our @packaging_groups = ();
our @group_status = ();
our %ready_list = ();

&main;

sub add_group
{
    my ($index, $dg_node) = @_;
    if ($group_status[$index] eq "Closed")
    {
        $group_status[$index] = "Opening";
        my $ref = $packaging_groups[$index];
        my $top = $#$ref;
        push(@$ref, "$dg_node");
    }else
    {
        my $ref = $packaging_groups[$index];
        my $top = $#$ref;
        $ref->[$top] .= " $dg_node";
    }
}

sub merge
{
    my ($dg_node) = @_;
    my $obj = $dg_build_objects[$dg_node];
    if (exists($nodes{$obj}))
    {
        my $value = $nodes{$obj};
        my $dir   = $build_dirs[$value];
        my $top   = topdir($dir);
        my $index = $packaging_dirs{$top};
        add_group($index, $dg_node);
    }
}

sub check_merge
{
    my ($node, $top_dir, $top) = @_;
    my %top_nodes = ();
    for (my $i = 0; $i < $#$top; $i++)
    {
        $top_nodes{$top->[$i]} = 1;
    }

    my $ref1 = $dg_reachings[$node];
    for (my $j = 0; $j <= $#$ref1; $j++)
    {
        my $r1 = $ref1->[$j];
        my $obj1 = $dg_build_objects[$r1];
        if (exists($nodes{$obj1}))
        {
            my $value = $nodes{$obj1};
            my $dir   = $build_dirs[$value];
            my $top   = topdir($dir);
            if ($top_dir ne $top)
            {
                my $ref2 = $dg_reachings[$r1];
                for (my $k = 0; $k <= $#$ref2; $k++)
                {
                    my $r2 = $ref2->[$k];
                    if (exists($top_nodes{$r2}))
                    {
                        return 0;
                    }
                } 
            }
        }
    }

    return 1;
}

sub process_ready_list
{
    my $total_nodes = $dg_n_nodes;
    my @tmp_dg_n_preds = @dg_n_preds;
    while ($total_nodes > 0)
    {
        my $changed;
        my %kill_dirs;
        do
        {
            $changed = 0;
            %kill_dirs = ();
            my @pending   = ();
            foreach my $node (keys %ready_list)
            {
                my $top_dir = $ready_list{$node};
                if (exists($packaging_dirs{$top_dir}))
                {
                    my $index = $packaging_dirs{$top_dir};
                    if ($group_status[$index] eq "Closed")
                    {
                        $group_status[$index] = "Opening";
                        my $ref = $packaging_groups[$index];
                        my $top = $#$ref;
                        push(@$ref, "$node");
                        $changed = 1;
                        $total_nodes--;
                        delete($ready_list{$node});
                        for (my $j = 0; $j < $dg_n_succs[$node]; $j++)
                        {
                            $tmp_dg_n_preds[$dg_succs[$node]->[$j]]--;
                            if ($tmp_dg_n_preds[$dg_succs[$node]->[$j]] == 0)
                            {
                                push(@pending, $dg_succs[$node]->[$j]);
                            }
                        }
                    }else
                    {
                        my $ref = $packaging_groups[$index];
                        my $context = $ref->[$#$ref];
                        my @fields = split(/\ /, $context);
                        my $f_ref  = \@fields;
                        my $ok = check_merge($node, $top_dir, $f_ref);
                        if ($ok == 1)
                        {
                            $ref->[$#$ref] .= " $node";
                            $changed = 1;
                            $total_nodes--;
                            delete($ready_list{$node});
                            for (my $j = 0; $j < $dg_n_succs[$node]; $j++)
                            {
                                $tmp_dg_n_preds[$dg_succs[$node]->[$j]]--;
                                if ($tmp_dg_n_preds[$dg_succs[$node]->[$j]] == 0)
                                {
                                    push(@pending, $dg_succs[$node]->[$j]);
                                }
                            }
                        }else
                        {
                            $kill_dirs{$index} = 1;
                        }
                    }
                }else
                {
                    $changed = 1;
                    $total_nodes--;
                    delete($ready_list{$node});
                    for (my $j = 0; $j < $dg_n_succs[$node]; $j++)
                    {
                        $tmp_dg_n_preds[$dg_succs[$node]->[$j]]--;
                        if ($tmp_dg_n_preds[$dg_succs[$node]->[$j]] == 0)
                        {
                            push(@pending, $dg_succs[$node]->[$j]);
                        }
                    }
                }
            }

            if ($changed == 1)
            {
                for (my $i = 0; $i <= $#pending; $i++)
                {
                    my $n = $pending[$i];
                    my $obj = $dg_build_objects[$n];
                    if (exists($nodes{$obj}))
                    {
                        my $value = $nodes{$obj};
                        my $dir   = $build_dirs[$value];
                        my $top   = topdir($dir);
                        $ready_list{$n} = $top;
                    }else
                    {
                        $ready_list{$n} = $obj . "1";
                    }
                }
            }else
            {
                foreach my $dir_index (keys %kill_dirs)
                {
                    $group_status[$dir_index] = "Closed";
                }
            }
        }
        while ($changed);
    }
}

sub process_depth
{
    my ($depth) = @_;
    my @ready_list = ();
    my @ready_dir = ();
    my %kill = ();
    my $copied1 = $dg_depth_nodes[$depth];
    my @fields1 = split(/\ /, $copied1);
    for (my $j = 0; $j <= $#fields1; $j++)
    {
        my $dg_node = $fields1[$j];
        my $obj = $dg_build_objects[$dg_node];
        if (exists($nodes{$obj}))
        {
            my $value = $nodes{$obj};
            my $dir   = $build_dirs[$value];
            my $top   = topdir($dir);
            push(@ready_list, $dg_node);
            push(@ready_dir, $top);
        }
    }

    for (my $i = 0; $i <= $#ready_list; $i++)
    {
        my $n       = $ready_list[$i];
        my $top_dir = $ready_dir[$i]; 

        my %dir1 = ();
        my $ref1 = $dg_reacheds[$n];
        for (my $j = 0; $j <= $#$ref1; $j++)
        {
            my $r = $ref1->[$j];
            my $obj = $dg_build_objects[$r];
            if (exists($nodes{$obj}))
            {
                my $value = $nodes{$obj};
                my $dir   = $build_dirs[$value];
                my $top   = topdir($dir);
                if ($top_dir ne $top)
                {
                    $dir1{$top} = 1;
                }
            }
        }

        my %dir2 = ();
        my $ref2 = $dg_reachings[$n];
        for (my $j = 0; $j <= $#$ref2; $j++)
        {
            my $r = $ref2->[$j];
            my $obj = $dg_build_objects[$r];
            if (exists($nodes{$obj}))
            {
                my $value = $nodes{$obj};
                my $dir   = $build_dirs[$value];
                my $top   = topdir($dir);
                if ($top_dir ne $top)
                {
                    # r should on the top of the current stack
                    my $index   = $packaging_dirs{$top};
                    my $ref = $packaging_groups[$index];
                    my $context = $ref->[$#$ref];
                    my @fields = split(/\ /, $context);
                    for (my $k = 0; $k <= $#fields; $k++)
                    {
                        if ($r == $fields[$k])
                        {
                            $dir2{$top} = 1;
                            last;
                        }
                    }
                }
            }
        }

        for (my $i = 0; $i <= $#packaging_dirs; $i++)
        {
            my $dir = $packaging_dirs[$i];
            if (exists($dir1{$dir}) && exists($dir2{$dir}))
            {
                $kill{$dir} = 1;
            }
        }
    }
 
    my $copied2 = $dg_depth_nodes[$depth];
    my @fields2 = split(/\ /, $copied2);
    for (my $j = 0; $j <= $#fields2; $j++)
    {
        my $dg_node = $fields2[$j];
        merge($dg_node);
    }

    for (my $i = 0; $i <= $#packaging_dirs; $i++)
    {
        my $dir = $packaging_dirs[$i];
        if (exists($kill{$dir}))
        {
            $group_status[$i] = "Closed";
        }
    }
}

sub dump_group_section
{
    my ($out_file) = @_;
    for (my $i = 0; $i <= $#packaging_dirs; $i++)
    {
        my $ref  = $packaging_groups[$i];
        my $pdir = $packaging_dirs[$i];
        if ($#$ref > 0)
        {
            for (my $j = 0; $j <= $#$ref; $j++)
            {
                my $dg_objs   = $ref->[$j];
                my @fields = split(/\ /, $dg_objs);
                print $out_file "(\n";
                for (my $k = 0; $k <= $#fields; $k++)
                {
                    my $index = $fields[$k];
                    if (! exists($ge_pruned_objects{$index}))
                    {
                        my $object  = $dg_build_objects[$index];
                        my $dirname = "";
                        if (exists($nodes{$object}))
                        {
                            my $index = $nodes{$object};
                            $dirname = $build_dirs[$index];
                        }
                        if ($dirname ne "")
                        {
                            my $class = topdir($dirname);
                            $class =~ s/-/_/g;

                            my @fields = split(/\//, $dirname); 
                                my $n = $#fields;
                            my $splited_name = "";
                            for (my $i = 0; $i < $n; $i++)
                            {
                                if ($i == 1 || $i == 3)
                                {
                                    $splited_name .= $fields[$i] . "/\\n";
                                }else
                                {
                                    $splited_name .= $fields[$i] . "/";
                                }
                            }
                            $splited_name .= $fields[$n];

                            print $out_file "[ $object ] { label: $object:\\n$splited_name; class: $class; }\n";
                        }
                    }
                }
                print $out_file ")";
                print $out_file "{ flow: down; label: $pdir Group $j; }\n";
            }
        }else
        {
            #single group, prune
            my $dg_objs   = $ref->[0];
            my @fields = split(/\ /, $dg_objs);
            for (my $k = 0; $k <= $#fields; $k++)
            {
                my $index = $fields[$k];
                $ge_pruned_objects{$index} = 1;
            }
        }
    }
}

sub main
{
    preprocess($map_file);
    build_dependence_graph($dep_file);
    prune_forward_edges();
    compute_node_depths();
    read_color_map($color_file);

    my $prune_level = 1; 
    prune_node_with_small_depth($prune_level);
    ##prune build system
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        my $obj   = $dg_build_objects[$i];
        if (exists($nodes{$obj}))
        {
            my $index = $nodes{$obj};
            my $dir   = $build_dirs[$index];
            if ($dir =~ m/^system/ || $dir =~ m/^build/)
            {
                $ge_pruned_objects{$i} = 1;
            }
        }
    }

    foreach my $dir (keys %dir_color_map)
    {
        my $color = $dir_color_map{$dir};
        $dir =~ s/_/-/g;
        push(@packaging_dirs, $dir);
        $packaging_dirs{$dir} = $#packaging_dirs;
        $packaging_groups[$#packaging_dirs] = [];
        push(@group_status, "Closed");
    }

    my $copied = $dg_depth_nodes[0];
    my @fields = split(/\ /, $copied);
    for (my $j = 0; $j <= $#fields; $j++)
    {
        my $dg_node = $fields[$j];
        my $obj = $dg_build_objects[$dg_node];
        if (exists($nodes{$obj}))
        {
            my $value = $nodes{$obj};
            my $dir   = $build_dirs[$value];
            my $top   = topdir($dir);
            $ready_list{$dg_node} = $top;
        }
    }
    process_ready_list();

    my $p_dir = dirname($pout_file);
    mkpath($p_dir);
    my $pout;
    open($pout, ">", $pout_file) or die "The out file $pout_file could not be opened\n";

    print $pout "Total Modules: $dg_n_nodes\n\n";
    for (my $i = 0; $i <= $#packaging_dirs; $i++)
    {
        my $ref    = $packaging_groups[$i];
        my $nparts = $#$ref + 1;
        print $pout "  Packaging $packaging_dirs[$i] into $nparts parts\n\n";
        for (my $j = 0; $j <= $#$ref; $j++)
        {
            my $dg_objs   = $ref->[$j];
            my @fields = split(/\ /, $dg_objs);
            my $k;
            print $pout  "    Part $j:\n";
            for ($k = 0; $k <= $#fields; $k++)
            {
                my $index = $fields[$k];
                my $obj = $dg_build_objects[$index];
                my $n_index = $nodes{$obj};
                my $dir = $build_dirs[$n_index];
                print $pout "      $obj: $dir\n";
            }
            print $pout "\n";
        }
    }

    close($pout);    

    my $files_key = $dg_nodes{"files"};
    $ge_pruned_objects{$files_key} = 1;
    %ge_edges = %dg_edges;

    my $g_dir = dirname($gout_file);
    mkpath($g_dir);
    my $gout;
    open($gout, ">", $gout_file) or die "The out file $gout_file could not be opened\n";

    dump_header($gout);
    dump_color_section($gout);
    dump_group_section($gout);
    dump_edge_section($gout);
    close($gout);

    system "graph-easy $gout_file --as png";
}
