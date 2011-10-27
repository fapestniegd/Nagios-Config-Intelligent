#!/usr/bin/perl -w
BEGIN { 
        # our lib path is ../lib from this script add it to @INC 
        use Cwd; 
        use File::Basename; 
        my $oldpwd = getcwd;
        chdir(dirname($0));      my $parent=getcwd;
        chdir(dirname($parent)); my $gparent=getcwd;
        unshift(@INC,"$gparent/lib") if(-d "$gparent/lib");
        chdir( $oldpwd )if(defined($oldpwd)); 
      };

use Getopt::Long;
$Getopt::Long::ignorecase = 0;
use Nagios::Config::Intelligent;
use Graph::Network;
use Data::Dumper;
################################################################################

my $result = GetOptions(
  'help'              => \$opt->{'help'},
  'config=s'          => \$opt->{'config'},
  'routers=s'        => \$opt->{'routers'},
);

my $nagios_cfg     = $opt->{'config'}  ||"/etc/nagios/nagios.cfg";
my $routers        = $opt->{'routers'} ||"/etc/routers.cfg";
my $nagios_servers = $opt->{'nagioses'}||"/etc/topology.cfg";

# load in the nagios.cfg, routers, and nagios server topology
my $n = Nagios::Config::Intelligent->new({
                                           'cfg'     => $nagios_cfg,
                                           'routers' => $routers,
                                           'topology'=> $nagios_servers,
                                        });

# draw the graph of the service checks
$n->{'g'}->draw("nagios.png");

# delegate the work based on proximity
print STDERR "Delegating...\n";
$n->delegate();
print STDERR "Delegation Complete.\n";

foreach my $ngsrv (keys(%{ $n->{'work'} })){
    print STDERR "Server: $ngsrv\n";
    foreach $type (keys(%{ $n->{'work'} ->{$ngsrv} })){

        print STDERR "  Reducing: $type...\n";
        my $newobj = $n->reduce({
                                  'objects'  => $n->{'work'}->{$ngsrv}->{$type},
                                  'templates' => $n->{'templates'}->{$type}
                               });

        print STDERR "  Reducing Complete.\n";
    }
}

print STDERR "Writing Configs...\n";
$n->write_object_cfgs({ 'dir' => '/tmp/nagios.d/'});
print STDERR "Done.\n";
