#!/usr/bin/perl -I../lib

use strict;
use warnings;

use PathParser;
        
&main;

sub main
{
    my $name1 = "./frameworks/../..";
    my $pathname1 = pathname($name1);
    print "pathname of $name1 is $pathname1\n";

    $name1 = "frameworks/base/./a";
    $pathname1 = pathname($name1);
    print "pathname of $name1 is $pathname1\n";

    $name1 = "frameworks/base";
    $pathname1 = pathname($name1);
    print "pathname of $name1 is $pathname1\n";

    $name1 = "frameworks/base/../../d";
    $pathname1 = pathname($name1);
    print "pathname of $name1 is $pathname1\n";

    $name1 = "frameworks/base/../../external/../frameworks";
    $pathname1 = pathname($name1);
    print "pathname of $name1 is $pathname1\n";

    $name1 = "frameworks/base/../../external/";
    $pathname1 = pathname($name1);
    print "pathname of $name1 is $pathname1\n";
}
