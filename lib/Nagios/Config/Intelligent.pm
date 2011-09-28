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
                   # remove comments at the beginning of the line FIXME comments can be at the ends of lines too.
                   $entry=~s/\s*[;#].*$//;
                   next if($entry=~m/^\s*$/);
                   # remove leading/trailing whitespace
                   $entry=~s/^\s*//;
                   $entry=~s/\s*$//;
                   # break down the key/value pairs 
                   if($entry=~m/(\S+)\s+(.*)/){
                       my ($key,$value) = ($1,$2);
                       $record->{$key} = $value;
                   }else{
                       print STDERR "NOT SURE ABOUT:  $entry\n";
                   }
               }
               push(@{ $self->{'objects'}->{$object_type} },$record);
               undef $record_name;
           }
       }
    $fh->close;
    }
    return $self;
}

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

sub load_status{
    my $self=shift;
    return undef if(!defined($self->{'config'}->{'status_file'}));
    my $fh=new FileHandle->new;
    if($fh->open("< $self->{'config'}->{'status_file'}")){
       while(my $line=<$fh>){
           chomp($line) if $line;
           $line=~s/#.*//g;
           $line=~s/^\s+$//g;
           next if $line=~m/^$/;
           if($line=~m/\s*(\S+)\s*{\s*$/){
               my $item=$1;
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
                   if($entry=~m/(\S+)\s*=\s*(.*)/){
                       my ($key,$value) = ($1,$2);
                       $record->{$key}=$value;
                   }
               }
               if($item eq "info"){
                   if(defined($self->{'status'}->{$item})){
                       if($self->{'status'}->{$item}->{'created'} == $record->{'created'}){
                           print STDERR "status has not changed since last parse\n";
                           $fh->close;
                           return $self;
                       }
                   }
                   $self->{'status'}->{$item}=$record;
               }elsif($item eq "program"){
                   $self->{'status'}->{$item}=$record;
               }elsif($item eq "host"){
                   $self->{'status'}->{'host'}->{ $record->{'host_name'} } = $record;
               }elsif($item eq "service"){
                   push(@{ $self->{'status'}->{'service'}->{ $record->{'host_name'} } },$record);
               }else{
                    print STDERR "unknown item in status file [$item]\n";
               }
           }
       }
       $fh->close;
    }
    return $self;
}

sub find_contact{
    my $self=shift;
    my $attrs=shift if @_;
    return $self->find_object('contact',$attrs);
}

sub find_host{
    my $self=shift;
    my $attrs=shift if @_;
    return $self->find_object('host',$attrs);
}

sub find_service{
    my $self=shift;
    my $attrs=shift if @_;
    my $type='service';
    my $records = undef;
    foreach my $host (keys(%{ $self->{'objects'}->{$type} })){
        next if(ref($self->{'objects'}->{$type}->{$host}) ne 'ARRAY');
        foreach my $service (@{ $self->{'objects'}->{$type}->{$host} }){
            my $allmatch=1;
            foreach my $needle (keys(%{ $attrs })){
                if(defined($service->{$needle})){
                    if( $attrs->{$needle} ne $service->{$needle} ){
                        $allmatch=0;
                    }
                }else{
                    $allmatch=0;
                }
            }
            if($allmatch == 1){
                push(@{ $records },$service);
            }
        }
    }
    return $records;
}

sub detemplate{
    my $self = shift; 
    my $type = shift;
    my $entry = shift;
    return $entry unless(defined($entry->{'use'}));
    my $template = $self->find_object($type,{ use => $entry->{'use'} });
    warn "no such template: $template\n" unless(defined($template));
    return $entry unless(defined($template));
    #my $new_entry = $self->detemplate($type, $template); # templates can use templates
    my $new_entry = $template;
    print Data::Dumper->Dump(['detemplate',$type,$new_entry]);
    delete $new_entry->{'register'} if( defined($new_entry->{'register'}) && ($new_entry->{'register'} == 0));
    delete $new_entry->{'name'} if( defined($new_entry->{'name'}) ); # lose the template name
    foreach my $key (%{ $entry }){ # override the template with entries from the entry being templated
        $new_entry->{$key} = $entry->{$key};
    }
    return $new_entry;
}

sub find_object{
    my $self = shift;
    my $type = shift if @_;   # the type of entry we're looking for (e.g. 'contact', 'host', 'servicegroup', 'command')
    my $attrs = shift if @_;  # a hash of the attributes that *all* must match to return the entry/entries
    my $records = undef;      # the list we'll be returning
    foreach my $entry (@{ $self->{'objects'}->{$type} }){
        $entry = $self->detemplate($type, $entry) if (defined($entry->{'use'}));
        my $allmatch=1;       # assume everything matches
        foreach my $needle (keys(%{ $attrs })){
            if(defined($entry->{$needle})){
                unless($entry->{$needle} eq $attrs->{$needle}){
                    $allmatch=0; # if the key's value we're looking for isn't the value in the entry, then all don't match
                }
            }else{
                $allmatch=0; # if we're missing a key in the attrs, then all don't match
            }
        }
        if($allmatch == 1){  # all keys were present, and matched the values for the same key in $attr
            push(@{ $records },$entry);
        }
    }
    return $records; # return the list of matched entries
}

sub find_object_regex{
    my $self = shift;
    my $type = shift if @_;   # the type of entry we're looking for (e.g. 'contact', 'host', 'servicegroup', 'command')
    my $attrs = shift if @_;  # a hash of the attributes that *all* must match to return the entry/entries
    my $records = undef;      # the list we'll be returning
    foreach my $entry (@{ $self->{'objects'}->{$type} }){
        $entry = $self->detemplate($type, $entry);
        my $allmatch=1;       # assume everything matches
        foreach my $needle (keys(%{ $attrs })){
            if(defined($entry->{$needle})){
                unless($entry->{$needle}=~m/$attrs->{$needle}/){
                    $allmatch=0; # if the key's value we're looking for isn't the value in the entry, then all don't match
                }
            }else{
                $allmatch=0; # if we're missing a key in the attrs, then all don't match
            }
        }
        if($allmatch == 1){  # all keys were present, and matched the values for the same key in $attr
            push(@{ $records },$entry);
        }
    }
    return $records; # return the list of matched entries
}


#################################################################################
## Get statuses from the status.dat
#################################################################################
sub host_status{
    my $self=shift;
    my $hostname=shift;
    my $records = undef;
    $self->load_status() unless( defined ($self->{'status'}) );
    return $self->{'status'}->{'host'}->{$hostname} if(defined($self->{'status'}->{'host'}->{$hostname}));
    return undef;
} 

sub service_status{
    my $self=shift;
    my $attrs=shift if @_;
    my $records = undef;
    my $allmatch;
    $self->load_status() unless( defined ($self->{'status'}) );
    foreach my $host (keys(%{ $self->{'status'}->{'service'} })){
        foreach my $service (@{ $self->{'status'}->{'service'}->{$host} }){
            $allmatch=1;
            foreach my $needle (keys(%{ $attrs })){
                if(defined($service->{$needle})){
                    if($service->{$needle} ne $attrs->{$needle}){
                        # They don't match if they don't match...
                        $allmatch=0;
                    }
                }else{
                    # They obviously don't match if it's not defined.
                    $allmatch=0;
                }
            }
            if($allmatch == 1){
                push(@{ $records }, $service);
            }
        }
    }
    return $records;
}
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

