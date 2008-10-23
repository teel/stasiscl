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

package Stasis::LogClip;

use strict;
use warnings;
use POSIX;
use HTML::Entities;
use Stasis::Parser;

# Escape for single quotes
sub _sqesc($) {
    my ($str) = @_;
    $str =~ s/(['\\])/\\$1/g;
    return $str;
}

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{ext} ||= {};
    $params{raid} ||= {};
    
    if( !$params{grouper} ) {
        $params{grouper} = Stasis::ActorGroup->new;
        $params{grouper}->run( $params{raid}, $params{ext} );
    }
    
    $params{pm} ||= Stasis::PageMaker->new( raid => $params{raid}, ext => $params{ext}, grouper => $params{grouper}, collapse => $params{collapse} );
    
    $params{lines} = [];
    
    bless \%params, $class;
}

sub add {
    my ($self, $line, %params) = @_;
    
    $params{t} = $line->{t};
    push @{$self->{lines}}, [
        Stasis::Parser->toString( 
            $line, 
            sub { $self->{pm}->actorLink( $_[0], 1 ) }, 
            sub { $self->{pm}->spellLink( $_[0] ) } 
        ),
        \%params,
    ];
}

sub clear {
    my ($self) = @_;
    delete $self->{lines};
    $self->{lines} = [];
}

sub json {
    my ($self) = @_;
    
    # Figure out raid start time.
    my ($start) = $self->{ext}{Presence}->presence;
    
    my @out;
    foreach my $ldata (@{$self->{lines}}) {
        my ($line, $lp) = @$ldata;
        
        push @out, sprintf( "{str:'%s',hp:'%d',t:'%0.3f'}",
            _sqesc $line,
            $lp->{hp} || 0,
            ($lp->{t} || 0) - $start||0,
        );
    }
    
    return "[" . join( ",", @out ) . "]";
}

1;
