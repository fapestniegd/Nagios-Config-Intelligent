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

my $main_config=$opt->{'config'}||"/etc/nagios/nagios.cfg";
my $n = Nagios::Config::Intelligent->new();
foreach ($n->object_files($main_config)){
    $n->load_object_file($_)
}
print $n->dump;
print Data::Dumper->Dump([$n->find_object_regex('contact',{ 'email' => '^scottstuder@eftsource.com$' }) ]);
