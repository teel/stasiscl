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
use Stasis::Extension;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
    $self->{ohtrack} = {};
    $self->{dtrack} = {};
    $self->{_autopsylen} = 40;
}

sub actions {
    map( { $_ => \&process_heal } qw(SPELL_HEAL SPELL_PERIODIC_HEAL) ),
    map( { $_ => \&process_damage } qw(ENVIRONMENTAL_DAMAGE SWING_DAMAGE RANGE_DAMAGE SPELL_DAMAGE DAMAGE_SPLIT SPELL_PERIODIC_DAMAGE DAMAGE_SHIELD) ),
    map( { $_ => \&process_death } qw(UNIT_DIED) ),
    map( { $_ => \&process_common } qw(SWING_MISSED RANGE_MISSED SPELL_MISSED SPELL_PERIODIC_MISSED DAMAGE_SHIELD_MISSED SPELL_AURA_APPLIED SPELL_AURA_APPLIED_DOSE SPELL_AURA_REMOVED) ),
}

sub process_heal {
    my ($self, $entry) = @_;
    
    # This was a heal. Add the HP to the target.
    $self->{ohtrack}{ $entry->{target} } += $entry->{amount};

    # Account for overhealing, if it happened, by removing the excess.
    $self->{ohtrack}{ $entry->{target} } = 0 if( $self->{ohtrack}{ $entry->{target} } > 0 );
    
    goto &process_common;
}

sub process_damage {
    my ($self, $entry) = @_;
    
    # If someone is taking damage we need to debit the HP.
    $self->{ohtrack}{ $entry->{target} } -= $entry->{amount};
    
    goto &process_common;
}

sub process_death {
    my ($self, $entry) = @_;
    
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
}

sub process_common {
    my ($self, $entry) = @_;
    
    # Add a combat event to the death tracker log.
    $self->{dtrack}{ $entry->{target} } ||= [];
    push @{ $self->{dtrack}{ $entry->{target} } }, {
        "t" => $entry->{t},
        "hp" => $self->{ohtrack}{ $entry->{target} },
        "entry" => $entry,
    };
    
    # Shorten the list if it got too long.
    shift @{ $self->{dtrack}{ $entry->{target} } } if @{ $self->{dtrack}{ $entry->{target} } } > $self->{_autopsylen};
}

sub sum {
    die "unsupported";
}

1;
