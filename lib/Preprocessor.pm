package Preprocessor;
use strict;
use warnings;
use Exporter;

our $VERSION = "1.0";
our @ISA = qw(Exporter);
our @EXPORT = qw(%nodes $n_nodes @build_objects @build_dirs %dir_has_multi_objects preprocess);

our %nodes = ();
our $n_nodes = 0;
our @build_objects = ();
our @build_dirs = ();
our %dir_has_multi_objects = ();

################################Preprocessor###########################
use File::Basename;
use PathParser;

### Create a build node
sub create_node
{
    my ($fields) = @_;
    my $obj = $fields->[0];
    my $dir = $fields->[1];
    my $n = $#$fields; 
    for (my $i = 0; $i <= $n; $i++)
    {
        $nodes{$fields->[$i]} = $n_nodes;
    }
    push(@build_objects, $obj);
    push(@build_dirs, $dir);
    $n_nodes++;
}

### Return the common dir
sub combine_dir
{
    my ($d1, $d2) = @_;
    while ($d1 !~ m/$d2/)
    {
        $d2 = dirname($d2);
    }
    return $d2;
}

sub preprocess
{
    my ($map_file) = @_;
    my $map;
    open($map, "<", $map_file) or die "The map file $map_file could not be opened\n";

    my %multi_objects = ();
    while (<$map>)
    {
        my ($line) = $_;
        chomp($line);
        my @fields = split(/:\ |\ /, $line);
        my $n = $#fields;
        my $obj = $fields[0];
        my $dir = $fields[1];

        if ((! exists($nodes{$obj})) && (! exists($nodes{$dir})))
        {
            create_node(\@fields);
        }elsif (exists($nodes{$obj}))
        {
            ## single object, multi-dirs
            my $value = $nodes{$obj};
            my $hashed_dir = $build_dirs[$value];
            $build_dirs[$value] = combine_dir($hashed_dir, $dir);; 
            for (my $i = 1; $i <= $n; $i++)
            {
                $nodes{$fields[$i]} = $value;
            }
        }else
        {
            ## single dir, multi-targets
            my $old_value = $nodes{$dir};
            my $new_value = $n_nodes;
            create_node(\@fields);
            if (! exists($dir_has_multi_objects{$dir}))
            {
                $dir_has_multi_objects{$dir} = "$old_value";
            }else
            {
                $dir_has_multi_objects{$dir} .= " $new_value";
            }
        }
    }

    close($map);
}

1;
