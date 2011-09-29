#!/usr/bin/perl 
use strict;
use Data::Dumper;

package Set::Hash;
sub new { my $class = shift; my $self = { }; bless($self, $class); return $self; }
sub intersection {
    my $self=shift;
    my (@sets) = @_;
    my $intersection = shift; # the first one intersects fully with itself;
    while(my $next = shift(@sets)){
        foreach my $key (keys(%{ $intersection })){ # remove things in intersection that are not in next
            if( (!defined($next->{$key})) || ($intersection->{$key} ne $next->{$key}) ){
                print "deleting $key from intersection\n";
                delete $intersection->{$key};
            }
        }
    }
    return $intersection;
}
1;


my $sh = Set::Hash->new();
my $i = $sh->intersection(
                           { 'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4            },
                           {           'b' => 2, 'c' => 3, 'd' => 4            },
                           {                     'c' => 3, 'd' => 4, 'e' =>  5 },
                           {                     'c' => 3, 'd' => 4, 'e' =>  5, 'f' => 6 },
                         );

print Data::Dumper->Dump([$i]);
