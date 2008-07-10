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

package Stasis::Extension::Healing;

use strict;
use warnings;

our @ISA = "Stasis::Extension";

my %damage_actions = (
    ENVIRONMENTAL_DAMAGE => 1,
    SWING_DAMAGE => 1,
    RANGE_DAMAGE => 1,
    SPELL_DAMAGE => 1,
    DAMAGE_SPLIT => 1,
    SPELL_PERIODIC_DAMAGE => 1,
    DAMAGE_SHIELD => 1,
);

sub start {
    my $self = shift;
    my %params = @_;
    
    $self->{actors} = {};
    $self->{ohtrack} = {};
    $self->{eshield} = {};
    $self->{__eshield} = $params{eshield} || 0;
}

sub process {
    my ($self, $entry) = @_;
    
    #########################
    # EARTH SHIELD TRACKING #
    #########################
    
    if( $entry->{action} eq "SPELL_CAST_SUCCESS" && $entry->{extra}{spellid} eq "32594" ) {
        # Earth Shield applied
        $self->{eshield}{ $entry->{target} } = $entry->{actor};
    }
    
    if( $entry->{action} eq "SPELL_AURA_REMOVED" && $entry->{extra}{spellid} eq "32594" ) {
        # Earth Shield applied
        delete $self->{eshield}{ $entry->{target} };
    }
    
    ################
    # NORMAL LOGIC #
    ################
    
    if( $entry->{action} eq "SPELL_HEAL" || $entry->{action} eq "SPELL_PERIODIC_HEAL" ) {
        # This was a heal. Create an empty hash if it does not exist yet.
        if( !exists( $self->{actors}{ $entry->{actor} }{ $entry->{extra}{spellid} }{ $entry->{target} } ) ) {
            $self->{actors}{ $entry->{actor} }{ $entry->{extra}{spellid} }{ $entry->{target} } = {
                count => 0,
                total => 0,
                effective => 0,
                hitCount => 0,
                hitTotal => 0,
                hitEffective => 0,
                critCount => 0,
                critTotal => 0,
                critEffective => 0,
                tickCount => 0,
                tickTotal => 0,
                tickEffective => 0,
            }
        }
        
        my $hdata;
        
        # Earth shield reassignment
        if( $self->{__eshield} && $entry->{extra}{spellid} eq "379" && $self->{eshield}{ $entry->{target} } ) {
            if( !exists( $self->{actors}{ $self->{eshield}{ $entry->{target} } }{ $entry->{extra}{spellid} }{ $entry->{target} } ) ) {
                $self->{actors}{ $self->{eshield}{ $entry->{target} } }{ $entry->{extra}{spellid} }{ $entry->{target} } = {
                    count => 0,
                    total => 0,
                    effective => 0,
                    hitCount => 0,
                    hitTotal => 0,
                    hitMin => 0,
                    hitMax => 0,
                    hitEffective => 0,
                    critCount => 0,
                    critTotal => 0,
                    critMin => 0,
                    critMax => 0,
                    critEffective => 0,
                    tickCount => 0,
                    tickTotal => 0,
                    tickMin => 0,
                    tickMax => 0,
                    tickEffective => 0,
                }
            }
            
            $hdata = $self->{actors}{ $self->{eshield}{ $entry->{target} } }{ $entry->{extra}{spellid} }{ $entry->{target} };
        } else {
            $hdata = $self->{actors}{ $entry->{actor} }{ $entry->{extra}{spellid} }{ $entry->{target} };
        }
        
        # Add the HP to the target for overheal-tracking purposes.
        $self->{ohtrack}{ $entry->{target} } += $entry->{extra}{amount};
    
        # Add total healing to the healer.
        $hdata->{count} += 1;
        $hdata->{total} += $entry->{extra}{amount};
        $hdata->{effective} += $entry->{extra}{amount};
    
        # Add this as the appropriate kind of healing: tick, hit, or crit.
        my $type;
        if( $entry->{action} eq "SPELL_PERIODIC_HEAL" ) {
            $type = "tick";
        } elsif( $entry->{extra}{critical} ) {
            $type = "crit";
        } else {
            $type = "hit";
        }
        
        $hdata->{"${type}Count"} += 1;
        $hdata->{"${type}Total"} += $entry->{extra}{amount};
        $hdata->{"${type}Effective"} += $entry->{extra}{amount};
        
        # Update min/max hit size.
        $hdata->{"${type}Min"} = $entry->{extra}{amount}
            if( 
                !$hdata->{"${type}Min"} ||
                $entry->{extra}{amount} < $hdata->{"${type}Min"}
            );

        $hdata->{"${type}Max"} = $entry->{extra}{amount}
            if( 
                !$hdata->{"${type}Max"} ||
                $entry->{extra}{amount} > $hdata->{"${type}Max"}
            );
    
        # Account for overhealing, if it happened, by removing the excess from effective healing.
        if( $self->{ohtrack}{ $entry->{target} } > 0 ) {
            $hdata->{effective} -= $self->{ohtrack}{ $entry->{target} };
            $hdata->{"${type}Effective"} -= $self->{ohtrack}{ $entry->{target} };
            
            # Reset HP to zero (meaning full).
            $self->{ohtrack}{ $entry->{target} } = 0;
        }
    } elsif( $damage_actions{ $entry->{action} } ) {
            # If someone is taking damage we need to debit it for overheal tracking.
            $self->{ohtrack}{ $entry->{target} } -= $entry->{extra}{amount};
    }
}

1;
