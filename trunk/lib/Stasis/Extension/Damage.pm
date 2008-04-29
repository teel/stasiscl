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

package Stasis::Extension::Damage;

use strict;
use warnings;
use Carp;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
}

sub process {
    my ($self, $entry) = @_;
    
    if( grep $entry->{action} eq $_, qw(ENVIRONMENTAL_DAMAGE SWING_DAMAGE SWING_MISSED RANGE_DAMAGE RANGE_MISSED SPELL_DAMAGE DAMAGE_SPLIT SPELL_MISSED SPELL_PERIODIC_DAMAGE SPELL_PERIODIC_MISSED DAMAGE_SHIELD DAMAGE_SHIELD_MISSED) ) {
        # This was a damage event, or an attempted damage event.
        
        # We are going to take some liberties with environmental damage and white damage in order to get them
        # into the neat actor > spell > target framework. Namely an abuse of actor IDs and spell IDs (using
        # "0" as an actor ID for the environment and using "0" for the spell ID to signify a white hit). These
        # will both fail to look up in Index, but that's okay.
        my $actor;
        my $spell;
        if( $entry->{action} eq "ENVIRONMENTAL_DAMAGE" ) {
            $actor = 0;
            $spell = 0;
        } elsif( $entry->{action} eq "SWING_DAMAGE" || $entry->{action} eq "SWING_MISSED" ) {
            $actor = $entry->{actor};
            $spell = 0;
        } else {
            $actor = $entry->{actor};
            $spell = $entry->{extra}{spellid};
        }
        
        # Create an empty hash if it does not exist yet.
        if( !exists( $self->{actors}{ $actor }{ $spell }{ $entry->{target} } ) ) {
            $self->{actors}{ $actor }{ $spell }{ $entry->{target} } = {
                # Aggregate information
                # "count" includes misses
                count => 0,
                total => 0,
                min => 0,
                max => 0,
                
                # Hits
                hitCount => 0,
                hitTotal => 0,
                hitMin => 0,
                hitMax => 0,
                
                # Crits
                critCount => 0,
                critTotal => 0,
                critMin => 0,
                critMax => 0,
                
                # Dot ticks
                tickCount => 0,
                tickTotal => 0,
                tickMin => 0,
                tickMax => 0,
                
                # Important mods, these are all counts and are going to overlap with
                # the counts listed above.
                partialResist => 0,
                partialBlock => 0,
                crushing => 0,
                glancing => 0,
                
                # Complete misses
                # Note we do not track partial resists or partial blocks
                dodgeCount => 0,
                absorbCount => 0,
                resistCount => 0,
                parryCount => 0,
                missCount => 0,
                blockCount => 0,
                reflectCount => 0,
                deflectCount => 0,
                immuneCount => 0,
            }
        };
        
        my $ddata = $self->{actors}{ $actor }{ $spell }{ $entry->{target} };
        
        # Check if this was a hit or a miss.
        if( $entry->{extra}{amount} ) {
            # HIT
            # Classify the damage WWS-style as a "hit", "crit", or "tick".
            my $type;
            if( $entry->{action} eq "SPELL_PERIODIC_DAMAGE" ) {
                $type = "tick";
            } elsif( $entry->{extra}{critical} ) {
                $type = "crit";
            } else {
                $type = "hit";
            }
            
            # Add the damage to the total for this spell.
            $ddata->{count} += 1;
            $ddata->{total} += $entry->{extra}{amount};
            
            # Add the damage to the total for this type of hit (hit/crit/tick).
            $ddata->{"${type}Count"} += 1;
            $ddata->{"${type}Total"} += $entry->{extra}{amount};
            
            # Update min/max hit size.
            $ddata->{"${type}Min"} = $entry->{extra}{amount}
                if( 
                    !$ddata->{"${type}Min"} ||
                    $entry->{extra}{amount} < $ddata->{"${type}Min"}
                );

            $ddata->{"${type}Max"} = $entry->{extra}{amount}
                if( 
                    !$ddata->{"${type}Max"} ||
                    $entry->{extra}{amount} > $ddata->{"${type}Max"}
                );
            
            # Add any mods.
            $ddata->{partialBlock}++ if $entry->{extra}{blocked};
            $ddata->{partialResist}++ if $entry->{extra}{resisted};
            $ddata->{crushing}++ if $entry->{extra}{crushing};
            $ddata->{glancing}++ if $entry->{extra}{glancing};
        } elsif( $entry->{extra}{misstype} ) {
            # MISS
            $ddata->{count} += 1;
            $ddata->{ lc( $entry->{extra}{misstype} ) . "Count" }++;
        } else {
            # Ignore this warning.
            #my $txtline = Stasis::Parser->toString($entry) || "(unprintable)";
            #carp( "Unrecognized potential damage event: $txtline\n" );
        }
    }
}

1;
