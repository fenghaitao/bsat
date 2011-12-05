package EasyGraph;
use strict;
use warnings;
use Exporter;

our $VERSION = "1.0";
our @ISA = qw(Exporter);
our @EXPORT = qw(%ge_pruned_objects %ge_edges %dir_color_map read_color_map dump_header dump_color_section dump_node_section dump_edge_section prune_node_with_small_depth);

###########################Easy Graph###############################
use Preprocessor;
use GraphBuilder;
use PathParser;

our %dir_color_map = ();
our %ge_pruned_objects = ();
our %ge_edges;

sub read_color_map
{
    my ($color_filename) = @_;
    my $color_info;
    open($color_info, "<", $color_filename) or die "The color map file $color_filename could not be opened\n";
    while (<$color_info>)
    {
        my $line = $_;
        chomp($line);
        my @fields = split(/:\ /, $line);
        my $dirname = $fields[0];
        ## graph-easy cound not parse "-".
        $dirname =~ s/-/_/g;
        my $color = $fields[1];
        $dir_color_map{$dirname} = $color;
    }

    close($color_info);
}

sub prune_node_with_small_depth
{
    my ($prune_level) = @_;
    for (my $i = 0; $i < $prune_level; $i++)
    {
        my @fields = split(/\ /, $dg_depth_nodes[$i]);
        for (my $j = 0; $j <= $#fields; $j++)
        {
            my $dg_node = $fields[$j];
            $ge_pruned_objects{$dg_node} = 1;
        }
    }
}

sub dump_header
{
    my ($out_file) = @_;
    print $out_file "graph { flow: down; }\n\n";
}

sub dump_color_section
{
    my ($out_file) = @_;
    foreach my $dir (keys %dir_color_map)
    {
        my $color = $dir_color_map{$dir};
        print $out_file "node.$dir { fill: $color; }\n";
    }
    print $out_file "\n";
}

sub dump_node_section
{
    my ($out_file) = @_;
    for (my $i = 0; $i < $dg_n_nodes; $i++)
    {
        if (! exists($ge_pruned_objects{$i}))
        {
            my $object  = $dg_build_objects[$i];
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
}

sub dump_edge_section
{
    my ($out_file) = @_;
    foreach my $key (keys %ge_edges)
    {
        my $value = $ge_edges{$key};
        my @key_fields   = split(/\ ->\ /, $key);
        my $k1 = $key_fields[0];
        my $k2 = $key_fields[1];
        my @value_fields = split(/\ ->\ /, $value);
        my $obj1 = $value_fields[0];
        my $obj2 = $value_fields[1];
        if (!(exists($ge_pruned_objects{$k1}) || exists($ge_pruned_objects{$k2})))
        {
            print $out_file "[ $obj1 ] -> [ $obj2 ]\n";
        }
    }
}

1;
