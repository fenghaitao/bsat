#!/usr/bin/perl
use strict;
use warnings;

&main;

sub main
{
    my @a = (1, 2, 3);
    print "Size is $#a \n";
    splice(@a, 1, 1);
    print "Size is $#a \n";
    for (my $i = 0; $i <= $#a; $i++)
    {
        print "$a[$i] ";
    }
    print "\n";
}
