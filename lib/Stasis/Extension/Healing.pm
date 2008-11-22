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
use Stasis::Extension;
use Stasis::Extension::Damage;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    my %params = @_;
    
    $self->{actors} = {};
    $self->{targets} = {};
    $self->{ohtrack} = {};
}

sub actions {
    map( { $_ => \&process_healing } qw(SPELL_HEAL SPELL_PERIODIC_HEAL) ),
    
    map( { $_ => \&process_damage } qw(ENVIRONMENTAL_DAMAGE SWING_DAMAGE RANGE_DAMAGE SPELL_DAMAGE DAMAGE_SPLIT SPELL_PERIODIC_DAMAGE DAMAGE_SHIELD) )
}

sub value {
    qw(hitCount hitTotal hitEffective hitMin hitMax critCount critTotal critEffective critMin critMax tickCount tickTotal tickEffective tickMin tickMax);
}

sub process_healing {
    my ($self, $entry) = @_;
    
    # This was a heal. Create an empty hash if it does not exist yet.
    my $hdata = ($self->{actors}{ $entry->{actor} }{ $entry->{spellid} }{ $entry->{target} } ||= {});
    
    # Add to targets.
    $self->{targets}{ $entry->{target} }{ $entry->{spellid} }{ $entry->{actor} } ||= $hdata;
    
    # Add the HP to the target for overheal-tracking purposes.
    $self->{ohtrack}{ $entry->{target} } += $entry->{amount};
    
    # Figure out how much effective healing there was.
    my $effective;
    if( exists $entry->{extraamount} ) {
        # WLK-style. Overhealing is included.
        $effective = $entry->{amount} - $entry->{extraamount};
    } else {
        # TBC-style. Overhealing is not included.
        if( $self->{ohtrack}{ $entry->{target} } > 0 ) {
            $effective = $entry->{amount} - $self->{ohtrack}{ $entry->{target} };

            # Reset HP to zero (meaning full).
            $self->{ohtrack}{ $entry->{target} } = 0;
        } else {
            $effective = $entry->{amount};
        }
    }

    # Add this as the appropriate kind of healing: tick, hit, or crit.
    my $type;
    if( $entry->{action} == Stasis::Parser::SPELL_PERIODIC_HEAL ) {
        $type = "tick";
    } elsif( $entry->{critical} ) {
        $type = "crit";
    } else {
        $type = "hit";
    }
    
    # Add total healing to the healer.
    $hdata->{"${type}Count"} += 1;
    $hdata->{"${type}Total"} += $entry->{amount};
    $hdata->{"${type}Effective"} += $effective;
    
    # Update min/max hit size.
    $hdata->{"${type}Min"} = $entry->{amount}
        if( 
            !$hdata->{"${type}Min"} ||
            $entry->{amount} < $hdata->{"${type}Min"}
        );

    $hdata->{"${type}Max"} = $entry->{amount}
        if( 
            !$hdata->{"${type}Max"} ||
            $entry->{amount} > $hdata->{"${type}Max"}
        );
}

sub process_damage {
    my ($self, $entry) = @_;
    
    # If someone is taking damage we need to debit it for overheal tracking.
    $self->{ohtrack}{ $entry->{target} } -= $entry->{amount};
}

1;
