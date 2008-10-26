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

package Stasis::Extension::Power;

use strict;
use warnings;
use Stasis::Extension;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{targets} = {};
}

sub actions {
    map { $_ => \&process } qw(SPELL_LEECH SPELL_PERIODIC_LEECH SPELL_DRAIN SPELL_PERIODIC_DRAIN SPELL_ENERGIZE SPELL_PERIODIC_ENERGIZE);
}

sub key {
    qw(actor spell target)
}

sub value {
    qw(count type amount);
}

sub process {
    my ($self, $entry) = @_;
    
    if( 
        $entry->{action} eq "SPELL_LEECH" ||
        $entry->{action} eq "SPELL_PERIODIC_LEECH" ||
        $entry->{action} eq "SPELL_DRAIN" ||
        $entry->{action} eq "SPELL_PERIODIC_DRAIN"
      ) 
    {
        # For leech and drain effects, store the amount of power gained.
        $self->{targets}{ $entry->{actor} }{ $entry->{extra}{spellid} }{ $entry->{target} }{type} = $entry->{extra}{type};
        $self->{targets}{ $entry->{actor} }{ $entry->{extra}{spellid} }{ $entry->{target} }{amount} += $entry->{extra}{amount};
        $self->{targets}{ $entry->{actor} }{ $entry->{extra}{spellid} }{ $entry->{target} }{count} += 1;
    }
    
    elsif( 
        $entry->{action} eq "SPELL_ENERGIZE" || 
        $entry->{action} eq "SPELL_PERIODIC_ENERGIZE"
      ) 
    {
        # "Energize" effects are done backwards because for each actor, we want to store what power
        # they gained, and not what power they gave to other people.
        $self->{targets}{ $entry->{target} }{ $entry->{extra}{spellid} }{ $entry->{actor} }{type} = $entry->{extra}{type};
        $self->{targets}{ $entry->{target} }{ $entry->{extra}{spellid} }{ $entry->{actor} }{amount} += $entry->{extra}{amount};
        $self->{targets}{ $entry->{target} }{ $entry->{extra}{spellid} }{ $entry->{actor} }{count} += 1;
    }
}

1;
