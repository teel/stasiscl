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

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
}

sub process {
    my ($self, $entry) = @_;
    
    if( $entry->{actor} ) {
        $self->{actors}{ $entry->{actor} }{start} = $entry->{t} if !$self->{actors}{ $entry->{actor} }{start};
        $self->{actors}{ $entry->{actor} }{end} = $entry->{t};
    }
    
    if( $entry->{target} ) {
        $self->{actors}{ $entry->{target} }{start} = $entry->{t} if !$self->{actors}{ $entry->{target} }{start};
        $self->{actors}{ $entry->{target} }{end} = $entry->{t};
    }
}

1;
