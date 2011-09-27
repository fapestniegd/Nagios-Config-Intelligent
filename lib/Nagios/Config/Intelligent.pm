package Nagios::Config::Intelligent;

use 5.008008;
use strict;
use warnings;
use FileHandle;
use YAML;

require Exporter;
# use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Nagios::Config::Intelligent ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';


# Preloaded methods go here.
sub new{
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

# recursively return a list of nagios .cfg files per the nagios.cfg's cfg_dir directives
sub get_cfgs {
    my $self = shift;
    my $path    = shift;
    opendir (DIR, $path) or die "Unable to open $path: $!";
    my @files = map { $path . '/' . $_ } grep { !/^\.{1,2}$/ } readdir (DIR);
    # Rather than using a for() loop, we can just return a directly filtered list.
    return
        grep { (/\.cfg$/) && (! -l $_) }
        map { -d $_ ? get_cfgs ($_) : $_ }
        @files;
}

# return a list of nagios config files per the nagios.cfg cfg_file & cfg_dir directives
sub object_files {
    my $self = shift;
    my $nagios_cfg = shift||"/etc/nagios/nagios.cfg";
    return undef unless $nagios_cfg;
    my $fh = FileHandle->new;
    my @cfg_files;
    if ($fh->open("< $nagios_cfg")) {
        while(my $line=<$fh>){
            chomp($line);
            $line=~s/#.*//;
            next if($line=~m/^\s*$/);
            next unless($line=~m/^\s*cfg_(file|dir)\s*=(.*)$/);
            if($1 eq "file"){
                push(@cfg_files,$2);
            }elsif($1 eq "dir"){
                push(@cfg_files,$self->get_cfgs($2));
            }
        }
        $fh->close;
    }
    return @cfg_files;
}

# load one or many object files
sub load_object_files{
    my $self = shift;
    my $files=shift if @_;
    if(ref($files) eq 'SCALAR'){
        $self->load_object_file($files);
    }elsif(ref($files) eq 'ARRAY'){
        foreach my $file (@{ $files }){
            $self->load_object_file($file);
        }
    }else{
        print STDERR "unknown or unexpected reference type $!:\n";  
    }
    return $self;
}

# load one object file
sub load_object_file{
    my $self = shift;
    my $file=shift if @_;
    my $fh=new FileHandle->new; 
    if($fh->open("< $file")){
       while(my $line=<$fh>){
       chomp($line) if $line;
           $line=~s/#.*//g;
           $line=~s/^\s+$//g;
           next if $line=~m/^$/;
           if($line=~m/\s*define\s+(\S+)\s*{(.*)/){
               my $object_type=$1;
               my $definition="$line\n";
               # read the file until the parenthesis is balanced
               while( ($self->unbalanced($definition)) && ($definition.=<$fh>) ){}
               $definition=~s/^[^{]+{//g;
               $definition=~s/}[^}]*//g;
               my @keyvalues=split(/\n/,$definition);
               my $record = {};
               my $record_name = undef;
               foreach my $entry (@keyvalues){
                   # remove hash comments /* FIXME this shoulde be unquoted hashmarks */
                   $entry=~s/#.*$//;
                   # remove semicolon comments /* FIXME this shoulde be unquoted semicolons */
                   $entry=~s/;.*$//;
                   next if($entry=~m/^\s*$/);
                   # remove leading/trailing whitespace
                   $entry=~s/^\s*//;
                   $entry=~s/\s*$//;
                   # break down the key/value pairs 
                   if($entry=~m/(\S+)\s+(.*)/){
                       my ($key,$value) = ($1,$2);
                       $record->{$key} = $value;
                       # services don't have names they have a host name and a description, ugh.
#                           if(($key eq "name")||($key eq "${object_type}_name")){
#                               $record_name = $value;
#                               if(defined($self->{'objects'}->{$object_type}->{$record_name})){
#                                   print STDERR "Redefinittion of $object_type : $record_name\n";
#                               }
#                           } 
                   }else{
                       print STDERR "NOT SURE ABOUT:  $entry\n";
                   }
                   push(@{ $self->{'objects'}->{$object_type} },$entry);
               }
################################################################################
#               if($object_type eq "service"){
#                   if(!defined($record_name)){
#                       # it's a host service check append the host with it
#                       push(@{ $self->{'objects'}->{'service'}->{ $record->{'host_name'} } },$record);
#                   }else{
#                       # it's a template, treat it normally
#                       $self->{'objects'}->{$object_type}->{$record_name}=$record;
#                   }
#               }elsif($object_type eq "hostextinfo"){
#                       $self->{'objects'}->{'hostextinfo'}->{ $record->{'host_name'} } = $record;
#               }elsif($object_type eq "hostdependency"){
#                       $self->{'objects'}->{'hostdependency'}->{ $record->{'host_name'} } = $record;
#               }else{
#                   $self->{'objects'}->{$object_type}->{$record_name}=$record;
#               }
################################################################################
               undef $record_name;
           }
       }
    $fh->close;
    }
    return $self;
}

#sub parse_cfg{ 
#    my $self = shift;
#    my $file = shift if @_;
#    my $fh = FileHandle->new;
#    if ($fh->open("< $file")) {
#    while(my $line=<$fh>){
#        chomp($line);
#        $line=~s/#.*//;
#        if($line=~m/([^=]+)\s*=\s*(.*)/){
#            my ($key,$value)=($1,$2);
#            if(!defined($self->{'config'}->{$key})){ 
#                $self->{'config'}->{$key}=$value; 
#            }else{
#                my $deref=$self->{'config'}->{$key};
#                if(ref(\$deref) eq "SCALAR"){
#                    my $tmp = $self->{'config'}->{$key};
#                    delete $self->{'config'}->{$key};
#                    push(@{ $self->{'config'}->{$key} },$tmp,$value);
#                }elsif(ref($self->{'config'}->{$key}) eq "ARRAY"){
#                    push(@{ $self->{'config'}->{$key} },$value);
#                }
#            }
#        }
#    }
#    $fh->close;
#    $self->load_object_files($self->{'config'}->{'cfg_file'}) if $self->{'config'}->{'cfg_file'};
#    } 
#    return $self;
#}

sub unbalanced{
    my $self=shift;
    my $string=shift;
    my $balance=0;
    my @characters=split(//,$string);
    foreach my $c (@characters){
        if($c eq '{'){ $balance++ };
        if($c eq '}'){ $balance-- };
    }
    return $balance;
}


sub dump{
    my $self = shift;
    print YAML::Dump($self);
    return $self;
}

# $ncfg->dereference_use($hostrecord,'host');
# $ncfg->dereference_use($svcrecord,'service');

#sub dereference_use{
#    my $self = shift;
#    my $record_name=shift if @_;
#    my $record_type=shift if @_;
#    return undef unless $self->{'objects'}->{$record_type}->{$record_name};
#    my $new_record={};
#    if(defined($self->{'objects'}->{$record_type}->{$record_name}->{'use'})){
#        foreach my $key (keys(%{ $self->{'objects'}->{$record_type}->{ 
#                                        $self->{'objects'}->{$record_type}->{$record_name}->{'use'} 
#                                                                     } 
#                               })){
#            $new_record->{$key} = $self->{'objects'}->{$record_type}->{ $self->{'objects'}->{$record_type}->{$record_name}->{'use'} }->{$key};
#        }
#    }
#    # Nested templates
#    if(defined($new_record->{'use'})){
#        $new_record=$self->dereference_use($self->{'objects'}->{$record_type}->{$record_name}->{'use'}, $record_type);
#    }
#    foreach my $key (keys(%{ $self->{'objects'}->{$record_type}->{$record_name} })){
#        next if($key eq "use");
#        $new_record->{$key} = $self->{'objects'}->{$record_type}->{$record_name}->{$key};
#    }
#    return $new_record;
#}
#
#sub get_host{
#    my $self=shift;
#    my $name=shift if @_;
#    if(defined($self->{'objects'}->{'host'}->{$name})){
#        return $self->dereference_use($name,'host');
#    }
#    return undef;
#}
#
#sub load_status{
#    my $self=shift;
#    return undef if(!defined($self->{'config'}->{'status_file'}));
#    my $fh=new FileHandle->new;
#    if($fh->open("< $self->{'config'}->{'status_file'}")){
#       while(my $line=<$fh>){
#           chomp($line) if $line;
#           $line=~s/#.*//g;
#           $line=~s/^\s+$//g;
#           next if $line=~m/^$/;
#           if($line=~m/\s*(\S+)\s*{\s*$/){
#               my $item=$1;
#               my $definition="$line\n";
#               # read the file until the parenthesis is balanced
#               while( ($self->unbalanced($definition)) && ($definition.=<$fh>) ){}
#               $definition=~s/^[^{]+{//g;
#               $definition=~s/}[^}]*//g;
#               my @keyvalues=split(/\n/,$definition);
#               my $record = {};
#               my $record_name = undef;
#               foreach my $entry (@keyvalues){
#                   # remove hash comments /* FIXME this shoulde be unquoted hashmarks */
#                   $entry=~s/#.*$//;
#                   # remove semicolon comments /* FIXME this shoulde be unquoted semicolons */
#                   $entry=~s/;.*$//;
#                   next if($entry=~m/^\s*$/);
#                   # remove leading/trailing whitespace
#                   $entry=~s/^\s*//;
#                   $entry=~s/\s*$//;
#                   # break down the key/value pairs
#                   if($entry=~m/(\S+)\s*=\s*(.*)/){
#                       my ($key,$value) = ($1,$2);
#                       $record->{$key}=$value;
#                   }
#               }
#               if($item eq "info"){
#                   if(defined($self->{'status'}->{$item})){
#                       if($self->{'status'}->{$item}->{'created'} == $record->{'created'}){
#                           print STDERR "status has not changed since last parse\n";
#                           $fh->close;
#                           return $self;
#                       }
#                   }
#                   $self->{'status'}->{$item}=$record;
#               }elsif($item eq "program"){
#                   $self->{'status'}->{$item}=$record;
#               }elsif($item eq "host"){
#                   $self->{'status'}->{'host'}->{ $record->{'host_name'} } = $record;
#               }elsif($item eq "service"){
#                   push(@{ $self->{'status'}->{'service'}->{ $record->{'host_name'} } },$record);
#               }else{
#                    print STDERR "unknown item in status file [$item]\n";
#               }
#           }
#       }
#       $fh->close;
#    }
#    return $self;
#}
#
#sub find_contact{
#    my $self=shift;
#    my $attrs=shift if @_;
#    return $self->find_object('contact',$attrs);
#}
#
#sub find_host{
#    my $self=shift;
#    my $attrs=shift if @_;
#    return $self->find_object('host',$attrs);
#}
#
#sub find_service{
#    my $self=shift;
#    my $attrs=shift if @_;
#    my $type='service';
#    my $records = undef;
#    foreach my $host (keys(%{ $self->{'objects'}->{$type} })){
#        next if(ref($self->{'objects'}->{$type}->{$host}) ne 'ARRAY');
#        foreach my $service (@{ $self->{'objects'}->{$type}->{$host} }){
#            my $allmatch=1;
#            foreach my $needle (keys(%{ $attrs })){
#                if(defined($service->{$needle})){
#                    if( $attrs->{$needle} ne $service->{$needle} ){
#                        $allmatch=0;
#                    }
#                }else{
#                    $allmatch=0;
#                }
#            }
#            if($allmatch == 1){
#                push(@{ $records },$service);
#            }
#        }
#    }
#    return $records;
#}
#
#sub find_object{
#    my $self=shift;
#    my $type=shift if @_;
#    my $attrs=shift if @_;
#    my $records = undef;
#    foreach my $key (keys(%{ $self->{'objects'}->{$type} })){
#        my $allmatch=1;
#        foreach my $needle (keys(%{ $attrs })){
#            if(defined($self->{'objects'}->{$type}->{$key}->{$needle})){
#                if( $attrs->{$needle} ne $self->{'objects'}->{$type}->{$key}->{$needle} ){
#                    $allmatch=0;
#                }
#            }else{
#                $allmatch=0;
#            }
#        }
#        if($allmatch == 1){
#            push(@{ $records },$self->{'objects'}->{$type}->{$key});
#        }
#    }
#    return $records;
#}
#
#################################################################################
## Get statuses from the status.dat
#################################################################################
#sub host_status{
#    my $self=shift;
#    my $hostname=shift;
#    my $records = undef;
#    $self->load_status() unless( defined ($self->{'status'}) );
#    return $self->{'status'}->{'host'}->{$hostname} if(defined($self->{'status'}->{'host'}->{$hostname}));
#    return undef;
#} 
#
#sub service_status{
#    my $self=shift;
#    my $attrs=shift if @_;
#    my $records = undef;
#    my $allmatch;
#    $self->load_status() unless( defined ($self->{'status'}) );
#    foreach my $host (keys(%{ $self->{'status'}->{'service'} })){
#        foreach my $service (@{ $self->{'status'}->{'service'}->{$host} }){
#            $allmatch=1;
#            foreach my $needle (keys(%{ $attrs })){
#                if(defined($service->{$needle})){
#                    if($service->{$needle} ne $attrs->{$needle}){
#                        # They don't match if they don't match...
#                        $allmatch=0;
#                    }
#                }else{
#                    # They obviously don't match if it's not defined.
#                    $allmatch=0;
#                }
#            }
#            if($allmatch == 1){
#                push(@{ $records }, $service);
#            }
#        }
#    }
#    return $records;
#}
#
## Autoload methods go after =cut, and are processed by the autosplit program.
#
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Nagios::Config::Intelligent - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Nagios::Config::Intelligent;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Nagios::Config::Intelligent, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

James S. White, E<lt>jameswhite@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by James S. White

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut

