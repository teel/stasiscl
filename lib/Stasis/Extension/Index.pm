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

package Stasis::Extension::Index;

use strict;
use warnings;

our @ISA = "Stasis::Extension";

our %rank = (
    # Chain Heal
    "1064" => 1,
    "10622" => 2,
    "10623" => 3,
    "25422" => 4,
    "25423" => 5,
    
    # Healing Wave
    "331" => 1,
    "332" => 2,
    "547" => 3,
    "913" => 4,
    "939" => 5,
    "959" => 6,
    "8005" => 7,
    "10395" => 8,
    "10396" => 9,
    "25357" => 10,
    "25391" => 11,
    "25396" => 12,
    
    # Lesser Healing Wave
    "8004" => 1,
    "8008" => 2,
    "8010" => 3,
    "10466" => 4,
    "10467" => 5,
    "10468" => 6,
    "25420" => 7,
);

sub start {
    my $self = shift;
    $self->{actors} = {};
    $self->{spells} = {};
}

sub process {
    my ($self, $entry) = @_;
    
    # The purpose of this index is to associate IDs with names.
    
    # ACTOR INDEX: check actor
    if( $entry->{actor} ) {
        $self->{actors}{ $entry->{actor} } = $entry->{actor_name};
    }
    
    # ACTOR INDEX: check target
    if( $entry->{target} ) {
        $self->{actors}{ $entry->{target} } = $entry->{target_name};
    }
    
    # SPELL INDEX: check for spellid
    if( $entry->{extra}{spellid} ) {
        $self->{spells}{ $entry->{extra}{spellid} } = $entry->{extra}{spellname};
    }
    
    # SPELL INDEX: check for extraspellid
    if( $entry->{extra}{extraspellid} ) {
        $self->{spells}{ $entry->{extra}{extraspellid} } = $entry->{extra}{extraspellname};
    }
}

sub spellname {
    my ($self, $spell) = @_;
    if( $spell ) {
        
        if( $self->{spells}{$spell} ) {
            my $r = $rank{$spell};
            return $self->{spells}{$spell} . ($r ? " $r" : "");
        } else {
            return $spell;
        }
    } else {
        return "Melee";
    }
}

sub actorname {
    my ($self, $actor) = @_;
    if( $actor ) {
        return $self->{actors}{$actor} || $actor;
    } else {
        return "Environment";
    }
}

1;
