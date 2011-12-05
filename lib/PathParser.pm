package PathParser;
use strict;
use warnings;
use Exporter;

our $VERSION = "1.0";
our @ISA = qw(Exporter);
our @EXPORT = qw(pathname topdir);

###########################Path Parser###############################
sub pathname
{
    my ($arg1) = @_;
    chomp($arg1);
    my @fields = split(/\//, $arg1);
    if ($#fields == 0)
    {
        return $arg1;
    }else
    {
        my $n = $#fields;
        my $skip = 0;
        my $name = "";
        for (my $i = $n; $i >= 0; $i--)
        {
            my $fragment = $fields[$i];
            if ($fragment eq "..")
            {
                $skip++;
            }else
            {
                if ($skip == 0)
                {
                    my $prefix = "";
                    if ($fragment ne ".")
                    {
                        $prefix = $fragment;
                    }elsif ($i == 0)
                    {
                        $prefix = $fragment;
                    }

                    if ($prefix ne "")
                    {
                        if ($name eq "")
                        {
                            $name = $prefix;
                        }else
                        {
                            $name = $prefix . "/" . $name;
                        }
                    }
                }else
                {
                    $skip--;
                }
            }
        }
        return $name;
    }
}

sub topdir
{
    my ($arg1) = @_;
    chomp($arg1);
    my $full_path = pathname($arg1);
    my @fields = split(/\//, $full_path);
    return $fields[0];
}

1;
