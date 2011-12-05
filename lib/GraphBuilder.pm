package GraphBuilder;
use strict;
use warnings;
use Exporter;

our $VERSION = "1.0";
our @ISA = qw(Exporter);
our @EXPORT = qw(%dg_nodes %dg_edges $dg_n_nodes @dg_preds @dg_succs @dg_n_preds @dg_n_succs @dg_build_objects %dg_pruning_objects %pruned_forward_edges %pruned_pseduo_objects $dg_max_depth @dg_node_depth @dg_depth_nodes @dg_reachings %dg_reachings @dg_reacheds build_dependence_graph prune_pseduo_build_objects prune_forward_edges compute_node_depths);

use Preprocessor;

our %dg_nodes = ();
our %dg_edges = ();
our $dg_n_nodes = 0;
our @dg_preds = ();
our @dg_succs = ();
our @dg_n_preds = ();
our @dg_n_succs = ();
our @dg_build_objects = ();
our %dg_pruning_objects = ();

our %pruned_pseduo_objects = ();

our @color = ();
our @enter_time = ();
our @leave_time = ();
our $time = 0;
our %pruned_forward_edges = ();
our @dfs_stack = ();

our %dg_reachings = ();
our @dg_reachings = ();
our @dg_reacheds = ();

our $dg_max_depth   = 0;
our @dg_node_depth  = ();
our @dg_depth_nodes = (); 

###
### Set up the nodes, build_objects
###
sub create_dg_node
{
    my ($node) = @_;
    $dg_nodes{$node} = $dg_n_nodes;
    push(@dg_build_objects, $node);
    my $node_value = $dg_n_nodes;
    $dg_n_preds[$node_value] = 0;
    $dg_preds[$node_value] = [];
    $dg_n_succs[$node_value] = 0;
    $dg_succs[$node_value] = [];
    $dg_reachings[$node_value] = [];
    $dg_reacheds[$node_value] = [];
    $dg_n_nodes++;
    return $node_value;
}

sub build_dependence_graph
{
    my ($dep_file) = @_;
    my $dep_info;
    open($dep_info, "<", $dep_file) or die "The dependence file $dep_file could not be opened\n";
    while (<$dep_info>)
    {
        my ($line) = $_;
        chomp($line);
        my @fields = split(/\ ->\ /, $line);
        my $from = $fields[0];
        my $to = $fields[1];
        if (!(exists($dg_pruning_objects{$from}) || exists($dg_pruning_objects{$to}))){
            my $from_value;
            my $to_value;
            if (! exists($dg_nodes{$from}))
            {
                $from_value = create_dg_node($from);
            }else
            {
                $from_value = $dg_nodes{$from};	
            }

            if (! exists($dg_nodes{$to}))
            {
                $to_value = create_dg_node($to);
            }else
            {
                $to_value = $dg_nodes{$to};	
            }

            $dg_preds[$from_value]->[$dg_n_preds[$from_value]] = $to_value;
            $dg_n_preds[$from_value]++;
            $dg_succs[$to_value]->[$dg_n_succs[$to_value]] = $from_value;
            $dg_n_succs[$to_value]++;
            my $edge = "$from_value -> $to_value";
            $dg_edges{$edge} = $line;
        }
    }

    close($dep_info);
}

sub prune_pseduo_build_objects()
{
    my %queue;
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        $queue{$i} = $i;
    }

    my $n_queue = $dg_n_nodes;
    my $round = 1;
    while ($n_queue > 0)
    {
        my $saved_n_queue = $n_queue;
        while((my $key, my $value) = each(%queue))
        {
            if ($dg_n_preds[$key] == 0)
            {
                my $object = $dg_build_objects[$key];
                if (! exists($nodes{$object}))
                {
                    $pruned_pseduo_objects{$object} = 1;
                    delete($queue{$key});
                    $n_queue--;
                }
                for (my $j = 0; $j < $dg_n_succs[$key]; $j++)
                {
                    $dg_n_preds[$dg_succs[$key]->[$j]]--;
                }
            }
        }
        if ($saved_n_queue == $n_queue)
        {
            last;
        }else
        {
            $round++;
        }
    }
}

sub find_root
{
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        if ($dg_n_succs[$i] == 0)
        {
            return $i;
        }
    }
}

sub prune_edge
{
    my ($edge) = @_;
    delete $dg_edges{$edge};

    my @fields = split(/\ ->\ /, $edge);
    my $node = $fields[0];
    my $pred = $fields[1];

    my $pref = $dg_preds[$node];
    for (my $j = 0; $j < $dg_n_preds[$node]; $j++)
    {
        my $p = $dg_preds[$j];
        if ($p == $pred)
        {
            my $pref = $dg_preds[$node];
            splice(@$pref, $j, 1);
            last;
        }
    }
    $dg_n_preds[$node]--;

    for (my $j = 0; $j < $dg_n_succs[$pred]; $j++)
    {
        my $s = $dg_succs[$j];
        if ($s == $node)
        {
            my $sref = $dg_succs[$pred];
            splice(@$sref, $j, 1);
            last;
        }
    }
    $dg_n_succs[$pred]--;
}

sub prune_edges
{
    foreach my $edge (keys %pruned_forward_edges)
    {
        prune_edge($edge);
    }
}

sub add_reaching
{
    my ($node, $pred) = @_;
    my $edge = "$node -> $pred";
    $dg_reachings{$edge} = 1;
    my $ref1 = $dg_reachings[$node];
    push(@$ref1, $pred);
    my $ref2 = $dg_reacheds[$pred];
    push(@$ref2, $node); 
}

sub handle_reaching_nodes 
{
    my ($node, $pred) = @_;
    my $edge = "$node -> $pred";
    if (! exists($dg_reachings{$edge}))
    {
        add_reaching($node, $pred);
    }else
    {
        if (exists($dg_edges{$edge}))
        {
            $pruned_forward_edges{$edge} = 1;
        }
    }
}

sub dfs
{
    my ($node) = @_;
    push(@dfs_stack, $node);
    $enter_time[$node] = $time;
    $time++;
    $color[$node] = "Gray";
    for (my $i = 0; $i < $dg_n_preds[$node]; $i++)
    {
        my $pred = $dg_preds[$node][$i]; 
        if ($color[$pred] eq "White")
        {
            dfs($pred);
        }elsif ($color[$pred] eq "Gray")
        {
            die "Fatal error: SCC exists in the dependence graph\n";
        }elsif ($color[$pred] eq "Black")
        {
            ##forward and cross edges
            for (my $i = $#dfs_stack; $i >= 0; $i--)
            {
                my $dfs_node = $dfs_stack[$i];
                handle_reaching_nodes($dfs_node, $pred);
                my $ref = $dg_reachings[$pred];
                for (my $j = 0; $j <= $#$ref; $j++)
                {
                    my $r = $ref->[$j];
                    handle_reaching_nodes($dfs_node, $r);
                }
            }
        }
    }

    $leave_time[$node] = $time;
    $color[$node] = "Black";
    pop(@dfs_stack);
    for (my $i = $#dfs_stack; $i >= 0; $i--)
    {
        my $dfs_node = $dfs_stack[$i];
        add_reaching($dfs_node, $node);
    }

=qod
    my $obj = $dg_build_objects[$node];
    print "Node is $obj\n";
    my $ref = $dg_reachings[$node];
    for (my $j = 0; $j <= $#$ref; $j++)
    {
        my $r = $ref->[$j];
        print "    $obj -> $dg_build_objects[$r]\n";
    }
    print "\n";
=cut    
}

sub prune_forward_edges
{
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        $color[$i] = "White";
    }
    my $root = find_root();
    dfs($root);
    prune_edges();
}

sub compute_node_depths
{
    my %queue;
    my @ready_list;
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        $queue{$i} = $i;
    }

    my $n_queue = $dg_n_nodes;
    my $round   = 0;
    my @tmp_dg_n_preds = @dg_n_preds;
    while ($n_queue > 0)
    {
        $dg_depth_nodes[$round] .= "";
        while((my $key, my $value) = each(%queue))
        {
            if ($tmp_dg_n_preds[$key] == 0)
            {
                push(@ready_list, $key);
           }
        }

        while ($#ready_list >= 0)
        {
            my $node = pop(@ready_list);
            $dg_node_depth[$node] = $round;
            $dg_depth_nodes[$round] .= "$node ";
            delete($queue{$node});
            $n_queue--;
            for (my $j = 0; $j < $dg_n_succs[$node]; $j++)
            {
                $tmp_dg_n_preds[$dg_succs[$node]->[$j]]--;
            }
        }
        $round++;
    }

    $dg_max_depth = $round; 
}

1;
