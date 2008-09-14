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

package Stasis::Extension::Presence;

use strict;
use warnings;
use Stasis::Extension;
use Stasis::Parser;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
    $self->{start} = {};
    $self->{end} = {};
    delete $self->{total};
}

sub actions {
    map { $_ => \&process } keys %Stasis::Parser::action_map;
}

sub process {
    my $guid;
    if( $guid = $_[1]->{actor} ) {
        $_[0]->{start}{ $guid } ||= $_[1]->{t};
        $_[0]->{end}{ $guid } = $_[1]->{t};
    }
    
    if( $guid = $_[1]->{target} ) {
        $_[0]->{start}{ $guid } ||= $_[1]->{t};
        $_[0]->{end}{ $guid } = $_[1]->{t};
    }
}

sub finish {
    my ($self) = @_;
    
    foreach (keys %{$self->{start}}) {
        $self->{actors}{$_} = pack "dd", $self->{start}{$_}, $self->{end}{$_};
    }
    
    delete $self->{start};
    delete $self->{end};
}

# Returns (start, end, total) for the raid or for an actor
sub presence {
    my $self = shift;

    if( @_ ) {
        my $start = undef;
        my $end = undef;

        foreach (@_) {
            if( $_ && $self->{actors}{$_} ) {
                my ($istart, $iend) = unpack "dd", $self->{actors}{$_};
                if( !defined $start || $start > $istart ) {
                    $start = $istart;
                }

                if( !defined $end || $end < $iend ) {
                    $end = $iend;
                }
            }
        }
        
        return ( $start || 0, $end || 0, ($end || 0) - ($start || 0) );
    } else {
        # Raid
        if( !$self->{total} ) {
            my ($start, $end);
            foreach my $h (values %{ $self->{actors} }) {
                my ($istart, $iend) = unpack "dd", $h;
                $start = $istart if( !$start || $start > $istart );
                $end = $iend if( !$end || $end < $iend );
            }
            
            $self->{total} = pack "dd", $start, $end;
        }
        
        my ($tstart, $tend) = unpack "dd", $self->{total};
        return ( $tstart, $tend, $tend - $tstart );
    }
}

1;
