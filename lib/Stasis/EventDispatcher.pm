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

package Stasis::EventDispatcher;

use strict;
use warnings;
use Stasis::Parser;
use Stasis::EventListener;

sub new {
    my $class = shift;
    my %exts;
    my @handlers;
    
    # Initialize the handler arrays.
    $handlers[0] = [];
    foreach (values %Stasis::Parser::action_map) {
        $handlers[$_] = [];
    }
    
    bless \@handlers, $class;
}

# Add an EventListener or subroutine
sub add {
    my ($self, $listener, @actions) = @_;
    
    # Check if $listener is an EventListener or a code reference
    if( ref $listener eq 'CODE' ) {
        foreach my $action (@actions) {
            push @{ $self->[ $Stasis::Parser::action_map{$action} ] }, [ $listener, undef ];
        }
    } elsif( $listener ) {
        # Flush it first.
        $self->remove($listener);

        # Now add it.
        my %actions = $listener->actions;
        while( my ($action, $handler) = each (%actions) ) {
            push @{ $self->[ $Stasis::Parser::action_map{$action} ] }, [ $handler, $listener ];
        }
    } else {
        die "null listener";
    }
}

# Remove an EventListener
sub remove {
    my ($self, $listener) = @_;
    
    foreach my $action (values %Stasis::Parser::action_map) {
        $self->[$action] = [ grep { $_->[1] != $listener } @{$self->[$action]} ];
    }
}

sub process {
    my ($self, $entry) = @_;
    
    foreach my $pair (@{ $self->[ $entry->{action} ] }) {
        if( defined $pair->[1] ) {
            $pair->[0]->( $pair->[1], $entry );
        } else {
            $pair->[0]->( $entry );
        }
    }
}

# Remove everything
sub flush {
    my ($self) = @_;
    
    $self->[$_] = [] foreach (values %Stasis::Parser::action_map);
}

1;
