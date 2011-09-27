#!/usr/bin/perl -w
BEGIN { 
        # our lib path is ../lib from this script add it to @INC 
        use Cwd; 
        use File::Basename; 
        my $oldpwd=getcwd;
        chdir(dirname($0));      my $parent=getcwd;
        chdir(dirname($parent)); my $gparent=getcwd;
        unshift(@INC,"$gparent/lib") if(-d "$gparent/lib");
        chdir( $oldpwd ); 
      };

use Nagios::Config::Intelligent;
use Getopt::Long;
use FileHandle;
use YAML;
use Data::Dumper;
$Getopt::Long::ignorecase = 0;
my $result = GetOptions(
  'help'              => \$opt->{'help'},
  'config=s'          => \$opt->{'config'},
);

my $n = Nagios::Config::Intelligent->new();

my @object_files = $n->object_files($opt->{'config'});
while(my $file = shift(@object_files)){ print ""; }
