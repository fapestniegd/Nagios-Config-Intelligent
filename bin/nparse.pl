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

print YAML::DumpFile("/etc/nagios.yaml",[{
                                           'g'        =>  $n->{'g'},
                                           'topology' =>  $n->{'topology'},
                                           'objects'  =>  $n->{'objects'},
                                           'work'     =>  $n->{'objects'},
                                      }]);


################################################################################
# take a peek at the network
#$n->{'g'}->draw("routers.png");

# calculate poll server for target
# trace hostdependencies from poll server to target, add if not present
# trace servicedependencies from poll server to target, add if not present
# for each poll host, write out active checks into cfg_root/hostname/obj.cfg
# for the report host, write out passive checks into cfg_root/hostname/obj.cfg

################################################################################
# my $poll;
# foreach my $host (@{ $n->{'objects'}->{'host'} }){
#     my $closest = $n->poll_server($host->{'address'});
#     push(@{ $poll->{$closest} },$host->{'host_name'});
# }
# print Data::Dumper->Dump([ $poll ]);

################################################################################
#print Data::Dumper->Dump(['result',$n->find_object('host',{ 'alias' => 'skrs0019' }) ]);
#print Data::Dumper->Dump([$n->intersection($n->{'objects'}->{'contact'}) ]);


################################################################################
# template reduction routines

#print $n->dump();



#print Data::Dumper->Dump([$n->hostgroup_members("bna_e_drives")]);

$n->delegate();
#$n->reduce; # this is computationally expensive
print Data::Dumper->Dump([{ 
                            'templates' => $n->{'templates'}, 
                            'objects' => $n->{'objects'}, 
                            'work' => $n->{'work'}
                        }]);


#$n->write_object_cfgs({ 'dir' => '/tmp/nagios.d/'});
