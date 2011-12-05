package GraphCreator;
use strict;
use warnings;
use Exporter;

our $VERSION = "1.0";
our @ISA = qw(Exporter);
our @EXPORT = qw(%edges create_dependence_graph);
use Preprocessor;
use PathParser;

our %edges = ();
our @stack = ();

###########################Graph Creator###############################
sub get_build_object
{
    my ($arg1) = @_;
    chomp($arg1);

    my $value = -1;
    if (exists($nodes{$arg1}))
    {
        $value = $nodes{$arg1};
    }elsif ($arg1 !~ m/^out/ && $arg1 !~ m/NOTICE/)
    {
        ### extends build_objects
        $arg1 = pathname($arg1);

        $nodes{$arg1} = $n_nodes;
        push(@build_objects, $arg1);
        push(@build_dirs, $arg1);
        $value = $n_nodes;
        $n_nodes++;
    }

    return $value;
}

sub get_top_build_target
{
    for (my $i = $#stack; $i >= 0; $i--)
    {
        if ($stack[$i] >= 0)
        {
            return $stack[$i];
        }
    }

    return -1;
}

sub add_edge
{
    my ($arg1, $arg2) = @_;
    if ("$arg1" != "$arg2")
    {
        if ($arg1 == -1)
        {
            $arg1 = get_top_build_target(); 
        }
        if ($arg2 != -1)
        {
            my $dir1 = $build_dirs[$arg1];
            my $dir2 = $build_dirs[$arg2];
            if ($dir2 !~ m/$dir1/)
            {
                my $edge  = "$arg1 -> $arg2";
                if (! exists($edges{$edge}))
                {
                    $edges{$edge} = "$build_objects[$arg1] -> $build_objects[$arg2]";
                }   
            }
        }
    }
}

sub create_dependence_graph
{
    my ($map_file, $log_file) = @_;
    preprocess($map_file);

    my $make_log;
    open($make_log, "<", $log_file) or die "The input file $log_file could not be opened\n";

    my $considering = "Considering target file `";
    my $considered = "' was considered already.";
    my $considered_prefix = "File `";
    my $pruning  = "Pruning file `";
    my $finished = "Finished prerequisites of target file `";
    my $tail = "'.";

    my $level = 0;
    while (<$make_log>)
    {
##      remove the heading spaces and tail
        my $line = $_;
        chomp($line);
        $line =~ s/^\ +//;
        $line =~ s/$tail$//;

        my $old_top;
        my $current_top;
        if ($_ =~ m/$considering/)  
        {
            $level++;
            $line =~ s/$considering//;
            my $o = get_build_object($line);
            push(@stack, $o);
        }elsif ($_ =~ m/$considered/)
        { 
            $level--;
            $line =~ s/$considered//;
            $line =~ s/$considered_prefix//;
            $old_top = pop(@stack);
            my $o = get_build_object($line);
            add_edge($old_top, $o);
        }elsif ($_ =~ m/$pruning/)
        {
            $line =~ s/$pruning//;
            $current_top = $stack[$#stack];
            my $o = get_build_object($line);
            add_edge($current_top, $o);
        }elsif ($_ =~ m/$finished/)
        {
            $level--;
            $old_top = pop(@stack);
            if ($#stack >= 0)
            {
                $current_top = $stack[$#stack];
                add_edge($current_top, $old_top);
            }
        }
    }

    close($make_log);
}

1;
