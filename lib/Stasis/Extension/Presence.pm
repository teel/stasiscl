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

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
    delete $self->{total};
}

sub process {
    my ($self, $entry) = @_;
    
    if( $entry->{actor} ) {
        my ($start, $end) = $self->{actors}{ $entry->{actor} } && unpack "dd", $self->{actors}{ $entry->{actor} };
        $self->{actors}{ $entry->{actor} } = pack "dd", $start||$entry->{t}, $entry->{t};
    }
    
    if( $entry->{target} ) {
        my ($start, $end) = $self->{actors}{ $entry->{target} } && unpack "dd", $self->{actors}{ $entry->{target} };
        $self->{actors}{ $entry->{target} } = pack "dd", $start||$entry->{t}, $entry->{t};
    }
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
