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

package Stasis::Extension::Dispel;

use strict;
use warnings;

use Stasis::Extension;
use Stasis::Event qw/:constants/;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
}

sub actions {
    map { $_ => \&process } qw/SPELL_AURA_DISPELLED SPELL_AURA_STOLEN SPELL_STOLEN SPELL_DISPEL_FAILED SPELL_DISPEL/;
}

sub key {
    qw/actor spell target extraspell/
}

sub value {
    qw/count resist/;
}

sub process {
    my ($self, $event) = @_;
    
    $self->{actors}{ $event->{actor} }{ $event->{spellid} }{ $event->{target} }{ $event->{extraspellid} }{count} += 1;
    
    if( $event->{action} == SPELL_DISPEL_FAILED ) {
        $self->{actors}{ $event->{actor} }{ $event->{spellid} }{ $event->{target} }{ $event->{extraspellid} }{resist} += 1;
    }
}

1;
