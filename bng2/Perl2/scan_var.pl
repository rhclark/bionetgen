#!/usr/bin/perl
# Simple parameter scanning script.  Creates and runs a single BNGL file that
# scans a single parameter using the setParameter command".  User provides
# a BNGL file containing the model - actions in this file are ignored.
#
# Written by Jim Faeder, Los Alamos National Laboratory, 3/6/2007 

# Updated on 2 April 2012 by J.Hogg
# + checks environment variables BNGPATH and BioNetGenRoot for the BNG folder
# + now using File::Spec for platform independent path handling
# + output now written in current directory (not the model directory!)
# + This version requires BioNetGen version 2.2.0-testing

use strict;
use warnings;

# Perl Modules
use FindBin;
use lib $FindBin::RealBin;
use File::Spec;
use File::Path qw(remove_tree);

# get perl binary
my $perlbin = $^X;

# get BNG path
my $bngpath;
my $bngexec;
{
    # try to find path in environment variables
    $bngpath = (exists $ENV{'BNGPATH'} ? $ENV{'BNGPATH'} :
                                (exists $ENV{'BioNetGenRoot'} ? $ENV{'BioNetGenRoot'} : undef) );
    unless (defined $bngpath)
    {   # use FindBin to locate BNG
        my ($volume,$directories,$file) = File::Spec->splitpath( $FindBin::RealBin );
        my @dirs = File::Spec->splitdir( $directories );
        pop @dirs;   # BNG executable script should be down one directory from here
        $bngpath = File::Spec->catpath( $volume, File::Spec->catdir(@dirs) );
    }
    # define executable
    $bngexec = File::Spec->catfile( $bngpath, "BNG2.pl" );
}

# some default parameters
my $log     = 0;
my $t_end   = 20;
my $n_steps = 20;
my $steady_state = 0;

my $prefix;
my @mandatory_args = ();
while ( @ARGV )
{
    my $arg = shift @ARGV;
    if ( $arg =~ s/^(-{1,2})// )
    {  
        if ( $arg eq 'log' ){
            $log = 1;
        }
        elsif($arg eq 'n_steps'){
            unless (@ARGV) { die "Syntax error: $arg requires value"; }
            $n_steps = shift @ARGV;
        }
        elsif($arg eq 'prefix'){
            unless (@ARGV) { die "Syntax error: $arg requires value"; }
            $prefix = shift @ARGV;
        }
        elsif($arg eq 'steady_state'){
            $steady_state = 1;
        }
        elsif($arg eq 't_end'){
            unless (@ARGV) { exit_error("Syntax error: $arg requires value"); }
            $t_end = shift @ARGV;
        }
        elsif($arg eq 'help'){
            display_help();
            exit 0;
        }
        else{
            die "Syntax error: unrecognized command line option $arg";
        }
    }
    else
    {   # assume this is a mandatory argument
        push @mandatory_args, $arg;
    }
}

#print "args: ", join(',', @mandatory_args), "\n";
unless (@mandatory_args==5)
{   # complain about too few arguments
    die "Syntax error: 5 required arguments (Try scan_var.pl --help)";
}

# get mandatory arguments
my ($file, $var, $var_min, $var_max, $n_pts) = @mandatory_args;


# Automatic assignment of prefix if unset
unless ($prefix)
{
	# separate directories from filename (if any)
    my ($volume,$directories,$file) = File::Spec->splitpath( $file );
	unless ( $file =~ /\.bngl$/ )
	{   die "Cannot extract prefix from filename $file";   }
	# trim bngl extension to define prefix
	($prefix = $file) =~ s/\.bngl$//;
}
# add variable name to prefix
$prefix.="_${var}";


if ($log)
{   # convert min and max into log values
    $var_min = log($var_min);
    $var_max = log($var_max);
}

# calculate parameter step
my $delta = ($var_max-$var_min)/($n_pts-1);

# Read file 
open(IN, $file) or die "Couldn't open file $file: $?\n";
my $script = "";
while ( my $line = <IN> )
{
    $script .= $line;
    # Skip actions
    last if ($line =~ /^\s*end\s+model/);
}
close(IN);

# prepare working directory
if (-d $prefix)
{   # delete output directory
    print "WARNING: overwriting existing work directory $prefix.\n";
    my $err;
    remove_tree( $prefix, {'safe'=>1, 'keep_root'=>1, 'error'=> \$err} );
    if (@$err)
    {   die "Unable to delete files in work directory $prefix";   }
}
else
{   # make directory for output files
    mkdir $prefix;
}

# Create model file with scan actions
my $scanmodel = File::Spec->catfile( ${prefix}, "${prefix}.bngl" );
my $logfile   = File::Spec->catfile( ${prefix}, "${prefix}.log" );

open(BNGL,">", $scanmodel) or die "Couldn't open $scanmodel for output";
print BNGL $script;
print BNGL "generate_network({overwrite=>1})\n";

{
    my $val = $var_min;
    foreach my $run (1..$n_pts)
    {
        my $srun = sprintf "%05d", $run;
        if ($run>1){
            print BNGL "resetConcentrations()\n";
        }
        my $x= $val;
        if ($log){ $x = exp($val);}
        printf BNGL "setParameter(\"$var\",%.12g)\n", $x;

        my $opt = "suffix=>\"$srun\",t_end=>$t_end,n_steps=>$n_steps";
        if ($steady_state){
            $opt .= ",steady_state=>1";
        }
        printf BNGL "simulate_ode({$opt})\n";
        $val += $delta;
    }  
}
close(BNGL);

# Run BioNetGen on file
print "Running BioNetGen on $scanmodel\n";
my $BNGARGS = "--outdir \"${prefix}\"";
my $command = "\"$perlbin\" \"$bngexec\" $BNGARGS \"$scanmodel\" > \"$logfile\"";
system( $command )==0
    or die "System $command failed: $?\n";

# Process output
my $outfile = "${prefix}.scan";
open(OUT,">", $outfile) or die "Couldn't open $outfile for output ($!)";

{
    my $val = $var_min;
    foreach my $run (1..$n_pts)
    {
        # Get data from gdat file
        my $gdat_file = File::Spec->catfile( $prefix, sprintf("${prefix}_%05d.gdat", $run) );
        print "Extracting data from $gdat_file\n";
        open(IN, "<", $gdat_file) or die "Couldn't open $gdat_file for input ($!)";
        if ($run==1)
        {
            my $head = <IN>;
            $head =~ s/^\s*\#//;
            my @heads = split(' ',$head);
            shift @heads;
            printf OUT "# %+14s", $var;
            foreach my $head (@heads)
            {
                printf OUT " %+14s", $head;
            }
            print OUT "\n";
        }
        my $last;
        while (my $line = <IN>) { $last = $line };
        my @dat = split(' ',$last);
        my $time = shift @dat;
        my $x = $log ? exp($val) : $val;
        printf OUT "%16.8e %s\n", $x, join(' ',@dat);
        close(IN);
        $val += $delta;
    }
}
close(OUT);
print "Final state data printed to $outfile\n";
exit 0;




# display help
sub display_help
{

    print <<END_HELP

scan_var.pl, a simple parameter scan utility for BioNetGen.

SYNOPSIS:
  scan_var.pl [OPTS] MODEL VAR MIN MAX NPTS     : perform parameter scan
  scan_var.pl --help                            : display help

OPTIONS:
  --log           : select parameter values on a log scale
  --n_steps N     : number of output time steps per simulation
  --t_end VAL     : end time for each simulation 
  --prefix PREFIX : prefix for output file (default: MODEL basename)
  --steady-state  : check for steady state at end of each simulation

Runs ODE simulations of MODEL with a range of values ofr parameter VAR.
Simulation data is placed in a directory folder named PREFIX_VAR. A data file
called PREFIX_VAR.scan contains the final smulation state for each 
parameter value. The scan file may be visualized with a plotting tool, such
as PhiBPlot.

END_HELP

}

