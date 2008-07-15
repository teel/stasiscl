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

package Stasis::Extension::Death;

use strict;
use warnings;
use Stasis::Parser;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
    $self->{ohtrack} = {};
    $self->{dtrack} = {};
    $self->{_autopsylen} = 40;
}

sub actions {
    return qw(ENVIRONMENTAL_DAMAGE SWING_DAMAGE SWING_MISSED RANGE_DAMAGE RANGE_MISSED SPELL_DAMAGE DAMAGE_SPLIT SPELL_MISSED SPELL_PERIODIC_DAMAGE SPELL_PERIODIC_MISSED DAMAGE_SHIELD DAMAGE_SHIELD_MISSED SPELL_HEAL SPELL_PERIODIC_HEAL SPELL_AURA_APPLIED SPELL_AURA_REMOVED UNIT_DIED SPELL_AURA_APPLIED_DOSE);
}

sub process {
    my ($self, $entry) = @_;
    
    # HP tracking, done in the same manner as overheal tracking for Healing.pm
    if( $entry->{action} eq "SPELL_HEAL" || $entry->{action} eq "SPELL_PERIODIC_HEAL" ) {
        # This was a heal. Add the HP to the target.
        $self->{ohtrack}{ $entry->{target} } += $entry->{extra}{amount};
    
        # Account for overhealing, if it happened, by removing the excess.
        $self->{ohtrack}{ $entry->{target} } = 0 if( $self->{ohtrack}{ $entry->{target} } > 0 );
    } elsif( grep $entry->{action} eq $_, qw(ENVIRONMENTAL_DAMAGE SWING_DAMAGE RANGE_DAMAGE SPELL_DAMAGE DAMAGE_SPLIT SPELL_PERIODIC_DAMAGE DAMAGE_SHIELD) ) {
        # If someone is taking damage we need to debit the HP.
        $self->{ohtrack}{ $entry->{target} } -= $entry->{extra}{amount};
    } elsif( $entry->{action} eq "UNIT_DIED" ) {
        # Make a deaths array if it doesn't exist already.
        if( $self->{dtrack}{ $entry->{target} } ) {
            $self->{actors}{ $entry->{target} } ||= [];

            # Push this death onto it.
            push @{$self->{actors}{ $entry->{target} }}, {
                "t" => $entry->{t},
                "actor" => $entry->{target},
                "autopsy" => $self->{dtrack}{ $entry->{target} } || [],
            };
        }
        
        # Delete the death tracker log.
        delete $self->{dtrack}{ $entry->{target} };
        
        # Bail out.
        return;
    } elsif( ! grep $entry->{action} eq $_, qw(SPELL_AURA_APPLIED SPELL_AURA_APPLIED_DOSE SPELL_AURA_REMOVED) ) {
        # Bail out now.
        # If this action was a damage, miss, or heal we will fall through to the next section.
        return;
    }
    
    # Add a combat event to the death tracker log.
    $self->{dtrack}{ $entry->{target} } ||= [];
    push @{ $self->{dtrack}{ $entry->{target} } }, {
        "t" => $entry->{t},
        "hp" => $self->{ohtrack}{ $entry->{target} },
        "text" => Stasis::Parser->toString( $entry, sub { "[[" . ($_[0]||0) . "]]" }, sub { "{{" . ($_[0]||0) . "}}" } ),
    };
    
    # Shorten the list if it got too long.
    shift @{ $self->{dtrack}{ $entry->{target} } } if scalar @{ $self->{dtrack}{ $entry->{target} } } > $self->{_autopsylen};
}

1;
