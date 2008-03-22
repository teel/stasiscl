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

package Stasis::Extension::Aura;

use strict;
use warnings;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
    $self->{presence} = {};
}

sub process {
    my ($self, $entry) = @_;
    
    # We need to track presence for the purpose of closing the auras later, in finish()
    if( $entry->{actor} ) {
        $self->{presence}{ $entry->{actor} }{start} = $entry->{t} if !$self->{presence}{ $entry->{actor} }{start};
        $self->{presence}{ $entry->{actor} }{end} = $entry->{t};
    }
    
    if( $entry->{target} ) {
        $self->{presence}{ $entry->{target} }{start} = $entry->{t} if !$self->{presence}{ $entry->{target} }{start};
        $self->{presence}{ $entry->{target} }{end} = $entry->{t};
    }
    
    # If an aura status changed, act on it.
    if( $entry->{action} eq "SPELL_AURA_APPLIED" ) {
        # Create a blank entry if none exists.
        if( !exists $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} } ) {
            $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} } = {
                start => 0,
                end => 0,
                gains => 0,
                fades => 0,
                uptime => 0,
            }
        }
        
        # An aura was gained, update the timeline.
        if( $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{start} ) {
            # 'start' is set, this means that we probably missed the fade message or this
            # is a dose application.
            
            # The best we can do in this situation is nothing, just keep the aura on even
            # though it may have faded at some point.
        } else {
            # 'start' is not set, so we should set it.
            $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{start} = $entry->{t};
        }
        
        # Update the number of times this aura was gained.
        $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{gains} += 1;
        
        # Update the type of this aura.
        $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{type} = $entry->{extra}{auratype};
    } elsif( $entry->{action} eq "SPELL_AURA_REMOVED" ) {
        # Create a blank entry if none exists.
        if( !exists $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} } ) {
            $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} } = {
                start => 0,
                end => 0,
                gains => 0,
                fades => 0,
                uptime => 0,
            }
        }
        
        # An aura faded, update the timeline.
        if( $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{start} ) {
            # 'start' is set, so we should turn it off and add the time to this aura duration.
            $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{time} += $entry->{t} - $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{start};
            $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{start} = 0;
        } else {
            # no 'start' is set, we probably missed the gain message.
            
            if( !$self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{gains} &&
                !$self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{fades} ) 
            {
                # if this is the first fade and there were no gains, let's assume it was up since 
                # before the log started (brave assumption)
                
                $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{time} += $entry->{t} - $self->{presence}{ $entry->{target} }{start};
            }
        }
        
        # Update the number of times this aura faded.
        $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} }{fades} += 1;
    }
}

sub finish {
    my $self = shift;
    
    # We need to close up all the un-closed aura uptimes.    
    foreach my $actor (keys %{ $self->{actors} }) {
        foreach my $aura (keys %{ $self->{actors}{$actor} } ) {
            if( $self->{actors}{$actor}{$aura}{start} ) {
                # 'start' is still set, this means the aura overlapped the end of the log.
                # Fill in the uptime until the presence end time.
                
                $self->{actors}{$actor}{$aura}{time} += $self->{presence}{$actor}{end} - $self->{actors}{$actor}{$aura}{start};
                $self->{actors}{$actor}{$aura}{start} = 0;
            }
        }
    }
}

1;
