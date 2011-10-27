# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Nagios-Config-Intelligent.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 4;
BEGIN {
        # our lib path is ../lib from this script add it to @INC 
        use Cwd;
        use File::Basename;
        my $oldpwd = getcwd;
        chdir(dirname($0));      my $parent=getcwd;
        chdir(dirname($parent)); my $gparent=getcwd;
        unshift(@INC,"$gparent/lib") if(-d "$gparent/lib");
        chdir( $oldpwd )if(defined($oldpwd));
        use_ok('Nagios::Config::Intelligent');
        use_ok('Getopt::Long');
        use_ok('Graph::Network');
        use_ok('Data::Dumper');
      };
$Getopt::Long::ignorecase = 0;


#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

