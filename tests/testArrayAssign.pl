#!/usr/bin/perl

&main;

sub main
{
    my @a;
    $a[0] = 1;
    $a[1] = 2;
    $a[2] = 3;
    my $n = $#a;
    for (my $i = 0; $i <= $n; $i++)
    {
        print "a[$i]: $a[$i] ";
    }
    print "\n";

    my @b;
    @b = @a;
    for (my $i = 0; $i <= $n; $i++)
    {
        print "b[$i]: $b[$i] ";
    }
    print "\n";

    $a[0] = 4;
    $a[1] = 5;
    $a[2] = 6;
    for (my $i = 0; $i <= $n; $i++)
    {
        print "b[$i]: $b[$i] ";
    }
    print "\n";
}
