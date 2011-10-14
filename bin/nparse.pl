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

use Getopt::Long;
$Getopt::Long::ignorecase = 0;
use Nagios::Config::Intelligent;
use Graph::Network;
use Data::Dumper;

my $result = GetOptions(
  'help'              => \$opt->{'help'},
  'config=s'          => \$opt->{'config'},
  'routers=s'        => \$opt->{'routers'},
);

my $nagios_cfg     = $opt->{'config'}  ||"/etc/nagios/nagios.cfg";
my $routers        = $opt->{'routers'} ||"/etc/routers.cfg";
my $nagios_servers = $opt->{'nagioses'}||"/etc/topology.cfg";

my $n = Nagios::Config::Intelligent->new({
                                           'cfg'     => $nagios_cfg,
                                           'routers' => $routers,
                                           'topology'=> $nagios_servers,
                                        });

# take a peek at the network
$n->{'g'}->draw("routers.png");

foreach my $host (@{ $n->{'objects'}->{'host'} }){
    print $host->{'address'};
}
#print Data::Dumper->Dump([ $n->{'objects'}->{'host'}  ]);
#print Data::Dumper->Dump(['result',$n->find_object('host',{ 'alias' => 'skrs0019' }) ]);
#print Data::Dumper->Dump([$n->intersection($n->{'objects'}->{'contact'}) ]);

################################################################################
# template reduction routines
# $n->reduce_objects; # this is computationally expensive
# #$n->reduce('contact');

#print $n->dump();

$n->write_object_cfgs({ 'dir' => '/tmp/nagios.d/'});
