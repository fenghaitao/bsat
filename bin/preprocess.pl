#!/usr/bin/perl -I../lib

use strict;
use warnings;
use Preprocessor;
use File::Path;
use File::Basename;

use Getopt::Long;

our $map_file = "";
our $out_file = "";
&GetOptions("map|map_file=s" =>\$map_file,
            "out|out_file=s" =>\$out_file,
);
{
    if ($map_file eq "" || $out_file eq "")
    {
        print "-map map_file && -out out_file should be specified\n";
        exit(1);
    }
}

&main;

sub main
{
    preprocess($map_file);

    my %handled = ();

    my $dir = dirname($out_file);
    mkpath($dir);
    my $out;
    open($out, ">", $out_file) or die "The out file could not be opened\n";

    for (my $i = 0; $i < $n_nodes; $i++)
    {
        my $dir = $build_dirs[$i];
        my $obj = $build_objects[$i];
        if (exists($dir_has_multi_objects{$dir}))
        {
            if (! exists($handled{$dir}))
            {
                $handled{$dir} = 1;
                my $value  = $dir_has_multi_objects{$dir};
                my @fields = split(/\ +/, $value);
                print $out "$dir: ";
                for (my $j = 0; $j <= $#fields; $j++)
                {
                    my $o = $build_objects[$j];
                    print $out "$o ";
                }
                print $out "\n";
            }
        }else
        {
            print $out "$dir: $obj\n";
        }
    }

    close($out);
}
