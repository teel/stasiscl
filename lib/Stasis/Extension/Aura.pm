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

package Stasis::Extension::Aura;

use strict;
use warnings;
use Stasis::Extension;
use Stasis::Extension::Activity;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
}

sub actions {
    SPELL_AURA_APPLIED => \&process_applied,
    SPELL_AURA_REMOVED => \&process_removed,
    UNIT_DIED => \&process_death,
}

sub process_death {
    my ($self, $entry) = @_;    
    
    # Forcibly fade all auras when a unit dies.
    if( exists $self->{actors}{ $entry->{target} } ) {
        foreach my $vaura (values %{ $self->{actors}{ $entry->{target} } } ) {
            foreach my $vactor (values %$vaura) {
                if( @{ $vactor->{spans} } ) {
                    my ($start, $end) = unpack "dd", $vactor->{spans}[-1];

                    if( !$end ) {
                        $vactor->{spans}[-1] = pack "dd", $start, $entry->{t};
                    }
                }
            }
        }
    }
}

sub process_applied {
    my ($self, $entry) = @_;

    # Create a blank entry if none exists.
    # Stored "backwards", the person the aura is applied to (the target) is first.
    my $sdata = $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{ $entry->{actor} || 0 } ||= {
        gains => 0,
        fades => 0,
        type => undef,
        spans => [],
    };
    
    # Get the most recent span.
    my ($sstart, $send) = @{$sdata->{spans}} ? unpack( "dd", $sdata->{spans}->[-1] ) : (undef, undef);
    
    # An aura was gained, update the timeline.
    if( $send || !defined $sstart ) {
        # Either this is the first span, or the previous one has ended. We should make a new one.
        push @{$sdata->{spans}}, pack "dd", $entry->{t}, 0;
        
        # In other cases, this means that we probably missed the fade message or this
        # is a dose application.
        
        # The best we can do in that situation is nothing, just keep the aura on even
        # though it may have faded at some point.
    }
    
    # Update the number of times this aura was gained.
    $sdata->{gains} ++;
    
    # Update the type of this aura.
    $sdata->{type} ||= $entry->{extra}{auratype};
}

sub process_removed {
    my ($self, $entry) = @_;
    
    # Create a blank entry if none exists.
    my $sdata = $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{ $entry->{actor} || 0 } ||= {
        gains => 0,
        fades => 0,
        type => undef,
        spans => [],
    };
    
    # Get the most recent span.
    my ($sstart, $send) = @{$sdata->{spans}} ? unpack( "dd", $sdata->{spans}->[-1] ) : (undef, undef);
    
    # An aura faded, update the timeline.
    if( defined $sstart && !$send ) {
        # We should end the most recent span.
        $sdata->{spans}->[-1] = pack "dd", $sstart, $entry->{t};
    } else {
        # There is no span in progress, we probably missed the gain message.
        if( !$sdata->{gains} && !$sdata->{fades} ) {
            # if this is the first fade and there were no gains, let's assume it was up since 
            # before the log started (brave assumption)
            push @{$sdata->{spans}}, pack "dd", 0, $entry->{t};
        }
    }
    
    # Update the number of times this aura faded.
    $sdata->{fades} ++;
    
    # Update the type of this aura.
    $sdata->{type} ||= $entry->{extra}{auratype};
}

# Returns type, gains, fades, and total uptime for a set of auras
# "aura" on actors "actor".
sub aura {
    my $self = shift;
    my %params = @_;
    
    $params{actor} ||= [];
    $params{spell} ||= [];
    $params{target} ||= [];
    $params{expand} ||= [];
    
    # Code reference to get a key for grouping actors.
    my $keyActor = $params{keyActor} || sub { return $_[0] };
    
    # Presence information
    $params{p} ||= {};
    
    # Filter the expand list.
    my @expand = map { $_ eq "actor" || $_ eq "spell" || $_ eq "target" ? $_ : () } @{$params{expand}};
    
    # We'll eventually return this.
    my %ret;
    
    # This holds references to the informational arrays.
    my @refs;
    
    # Examine what we were told to.
    foreach my $ktarget (scalar @{$params{target}} ? @{$params{target}} : keys %{$self->{actors}}) {
        my $vtarget = $self->{actors}{$ktarget} or next;
        my ($start, $end) = unpack "dd", $params{p}{$ktarget};
        my $ktarget_use;
        
        foreach my $kspell (scalar @{$params{spell}} ? @{$params{spell}} : keys %$vtarget) {
            my $vspell = $vtarget->{$kspell} or next;
            
            foreach my $kactor (scalar @{$params{actor}} ? @{$params{actor}} : keys %$vspell) {
                my $vactor = $vspell->{$kactor} or next;
                my $kactor_use;
            
                # Get a reference to the hash we want to add to.
                my $ref = \%ret;
                foreach (@expand) {
                    my $key;
                    if( $_ eq "spell" ) {
                        $key = $kspell;
                    } elsif( $_ eq "target" ) {
                        $key = $keyActor->($ktarget);
                    } else {
                        # actor
                        $key = $keyActor->($kactor);
                    }
                    
                    $ref = $ref->{$key} ||= {};
                }
                
                # Add the info.
                push @refs, $ref if ! %$ref;
            
                $ref->{type} ||= $vactor->{type};
                $ref->{gains} += $vactor->{gains};
                $ref->{fades} += $vactor->{fades};
                $ref->{spans} ||= [];
                
                push @{$ref->{spans}}, map { ($a, $b) = unpack "dd", $_; pack "dd", $a||$start, $b||$end } @{$vactor->{spans}};
            }
        }
    }
    
    # Resolve the spans into uptimes.
    foreach my $ref (@refs) {
        $ref->{time} = $self->_uptime( delete $ref->{spans} );
    }
    
    return \%ret;
}

sub _uptime {
    # This is pretty much the same function.
    goto &Stasis::Extension::Activity::_activity;
}

1;
