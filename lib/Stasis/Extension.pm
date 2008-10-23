# Copyright (c) 2008, Gian Merlino
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package Stasis::Extension;

use strict;
use warnings;
use Carp;
use Exporter "import";

our @EXPORT_OK = qw(ext_sum span_sum);
our @ISA = "Stasis::EventListener";

# Meant to be called statically like:
# Stasis::Extension->factory "Aura" 
sub factory {
    my ($self, $ext) = @_;
    my $class = "Stasis::Extension::$ext";
    
    # Grab the file.
    require "Stasis/Extension/$ext.pm" or return undef;
    
    # Create the object.
    my $obj = $class->new();
    
    # Return it.
    return $obj ? $obj : undef;
}

# Standard constructor.
sub new {
    my $class = shift;
    my %params = @_;
    
    bless {
        params => \%params
    }, $class;
}

# Subclasses may implement this function, which will be called once at
# the start of processing.
sub start {
    return 1;
}

# Subclasses may implement this function, which will be called once at
# the end of processing.
sub finish {
    return 1;
}

# This should be the order of keys in the {actors} hash.
sub fields {
    qw(actor spell target);
}

sub sum {
    my $self = shift;
    my %params = @_;
    
    # Get our field list.
    my @fields = ($self->fields);
    
    # Get list of things to expand in the returned hash.
    $params{expand} ||= [];
    my @expand = grep { my $f = $_; grep { $f eq $_ } (@fields) } @{$params{expand}};
    
    # Code reference to get a key for grouping actors.
    my $keyActor = $params{keyActor};
    
    # This is the hash we'll be returning.
    my $data;
    
    # Check if we have a {targets} hash, and if so, check if we should use it.
    if( exists $self->{actors} && exists $self->{targets} ) {
        # Measure the size of our inputs.
        # We can start with actors or targets. Start with the one we need less from.
        my $asz = $params{actor} ? scalar @{$params{actor}} : 0;
        my $tsz = $params{target} ? scalar @{$params{target}} : 0;
        
        if( $tsz && (!$asz || $tsz < $asz) ) {
            # Assign {targets} to $data, and then switch targets and actors in the fields array.
            # This works because when both {actors} and {targets} are present, @fields is meant to correspond to {actors}.
            $data = $self->{targets};
            @fields = map { if( $_ eq "target" ) { "actor" } elsif( $_ eq "actor" ) { "target" } else { $_ } } @fields;
        } else {
            $data = $self->{actors};
        }
    } else {
        # Only one exists.
        if( exists $self->{targets} ) {
            $data = $self->{targets};
            @fields = map { if( $_ eq "target" ) { "actor" } elsif( $_ eq "actor" ) { "target" } else { $_ } } @fields;
        } else {
            $data = $self->{actors};
        }
    }
    
    # Get our search list. Importantly, this is done after @fields reassignment in the previous block.
    my @fields_search = map { $params{$_} || [] } (@fields);
    my @fields_skip = map { $params{"-$_"} } (@fields);
    
    # Map numbers to each field.
    my %fields_map;
    $fields_map{$fields[$_]} = $_ for (0..$#fields);
    
    # We'll eventually return this.
    my %ret;
    
    # This function walks through the {actors} or {targets} hash.
    my $walk; $walk = sub {
        my ($hash, $f, @keys) = @_;
        $f ||= 0;

        # $hash is the current level of the hash we're at (it might be a leaf)
        # $f is how deep we are, it starts at zero
        # @keys are what keys we've seen so far (in order to get to $hash)... its size should be @fields - $f

        if( @keys < @fields ) {
            # We still have fields to go through.
            foreach my $k (scalar @{$fields_search[$f]} ? @{$fields_search[$f]} : keys %$hash ) {
                $walk->( $hash->{$k}, $f+1, @keys, $k ) if exists $hash->{$k} && ( !$fields_skip[$f] || ! grep { $k eq $_ } @{$fields_skip[$f]} );
            }
        } else {
            # $hash should be a leaf.
            my $ref = \%ret;
            foreach my $e (@expand) {
                $ref = $ref->{ $keyActor && ($e eq "actor" || $e eq "target") ? $keyActor->($keys[$fields_map{$e}]) : $keys[$fields_map{$e}] } ||= {};
            }

            ext_sum( $ref, $hash );
        }
    };

    $walk->( $data );
    
    # Necessary because otherwise perl won't figure out that it has to delete $walk (due to its self-reference)
    undef $walk;
            
    return \%ret;
}

# NOT object oriented.
sub ext_sum {
    my $sd1 = shift;
    
    # Merge the rest of @_ into $sd1.
    foreach my $sd2 (@_) {
        while( my ($key, $val) = each (%$sd2) ) {
            if( $sd1->{$key} ) {
                if( ref $val && ref $val eq 'ARRAY' ) {
                    push @{$sd1->{$key}}, @$val;
                } elsif( $key =~ /[Mm](in|ax)$/ ) {
                    # Minimum or maximum
                    if( lc $1 eq "in" && $val && $val < $sd1->{$key} ) {
                        $sd1->{$key} = $val;
                    } elsif( lc $1 eq "ax" && $val && $val > $sd1->{$key} ) {
                        $sd1->{$key} = $val;
                    }
                } elsif( $key ne "type" ) {
                    # Total
                    $sd1->{$key} += $val;
                }
            } else {
                # Use the new value.
                $sd1->{$key} = ref $val && ref $val eq 'ARRAY' ? [@$val] : $val;
            }
        }
    }
    
    # Return $sd1.
    return $sd1;
}

# NOT object oriented.
sub span_sum {
    my ($spans, $start, $end) = @_;
    
    return 0 if !$spans;
    
    # Sort spans by start time.
    my @span = sort { ( unpack "dd", $a )[0] <=> ( unpack "dd", $b )[0] } @$spans;
    
    # Store the final list in here.
    my @final = ();
    
    foreach my $span (@span) {
        # We are assured that $span starts at the same time as, or after, everything in @final.
        # If it overlaps the last span in @final then merge it in.
        my ($sstart, $send) = unpack "dd", $span;
        $send ||= $end;
        
        if( @final ) {
            my ($lstart, $lend) = unpack "dd", $final[-1];
            $lend ||= $end;
            
            if( $sstart <= $lend ) {
                # There is an overlap. Possibly extend $last.
                $final[-1] = pack "dd", $lstart, $send if $send > $lend;
            } else {
                # No overlap.
                push @final, $span;
            }
        } else {
            # @final has nothing in it yet.
            push @final, $span;
        }
    }
    
    # Total up @final.
    my $sum = 0;
    foreach (@final) {
        my ($fstart, $fend) = unpack "dd", $_;
        $sum += ($fend||$end) - ($fstart||$start);
    }
    
    return $sum;
}

1;
