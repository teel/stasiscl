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
use Stasis::Extension;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
}

sub actions {
    return qw(SPELL_AURA_APPLIED SPELL_AURA_REMOVED UNIT_DIED);
}

sub process {
    my ($self, $entry) = @_;
    
    # Forcibly fade all auras when a unit dies.    
    if( $entry->{action} eq "UNIT_DIED" ) {
        if( exists $self->{actors}{ $entry->{target} } ) {
            foreach my $vaura (values %{ $self->{actors}{ $entry->{target} } } ) {
                if( @{ $vaura->{spans} } ) {
                    $vaura->{spans}->[-1]->{end} ||= $entry->{t};
                }
            }
        }
        
        return;
    }
    
    # Create a blank entry if none exists.
    my $sdata = $self->{actors}{ $entry->{target} }{ $entry->{extra}{spellid} } ||= {
        gains => 0,
        fades => 0,
        type => "",
        spans => [],
    };
    
    # Get a reference to the most recent span.
    my $span = @{$sdata->{spans}} ? $sdata->{spans}->[-1] : undef;
    
    if( $entry->{action} eq "SPELL_AURA_APPLIED" ) {
        # An aura was gained, update the timeline.
        if( !$span || $span->{end} ) {
            # Either this is the first span, or the previous one has ended. We should make a new one.
            push @{$sdata->{spans}}, {
                start => $entry->{t},
                end => 0,
            }
            
            # In other cases, this means that we probably missed the fade message or this
            # is a dose application.
            
            # The best we can do in that situation is nothing, just keep the aura on even
            # though it may have faded at some point.
        }
        
        # Update the number of times this aura was gained.
        $sdata->{gains} ++;
        
        # Update the type of this aura.
        $sdata->{type} ||= $entry->{extra}{auratype};
    } elsif( $entry->{action} eq "SPELL_AURA_REMOVED" ) {
        # An aura faded, update the timeline.
        if( $span && !$span->{end} ) {
            # We should end the most recent span.
            $span->{end} = $entry->{t};
        } else {
            # There is no span in progress, we probably missed the gain message.
            if( !$sdata->{gains} && !$sdata->{fades} ) {
                # if this is the first fade and there were no gains, let's assume it was up since 
                # before the log started (brave assumption)
                
                push @{$sdata->{spans}}, {
                    start => 0,
                    end => $entry->{t},
                }
            }
        }
        
        # Update the number of times this aura faded.
        $sdata->{fades} ++;
        
        # Update the type of this aura.
        $sdata->{type} ||= $entry->{extra}{auratype};
    }
}

# Returns total uptime for a set of auras "aura" on actors "actor".
# Also needs a "start" and "end" to be able to resolve zero on spans.
# If either is blank, will return 0.
sub aura {
    my $self = shift;
    my %params = @_;
    
    $params{actor} ||= [];
    $params{aura} ||= [];
    my $start = $params{start};
    my $end = $params{end};
    
    # Return 0 with blank arguments, as promised.
    return 0 unless @{$params{actor}} && @{$params{aura}};
    
    # Store relevant aura spans.
    my @span;
    
    # Examine what we were told to.
    foreach my $kactor ( @{$params{actor}} ) {
        if( my $vactor = $self->{actors}{$kactor} ) {
            foreach my $kaura ( @{$params{aura}} ) {
                if( my $vaura = $vactor->{$kaura} ) {
                    # Add the spans.
                    push @span, @{$vaura->{spans}};
                }
            }
        }
    }
    
    # Sort spans by start time.
    @span = sort { ($a->{start}||$start) <=> ($b->{start}||$start) } @span;
    
    # Store the final list in here.
    my @final = ();
    
    foreach my $span (@span) {
        # We are assured that $span starts at the same time as, or after, everything in @final.
        # If it overlaps the last span in @final then merge it in.
        
        if( @final ) {
            my $last = $final[$#final];
            if( ($span->{start}||$start) <= $last->{end} ) {
                # There is an overlap.
                if( ($span->{end}||$end) > $last->{end} ) {
                    # Extend $last.
                    $last->{end} = ($span->{end}||$end);
                }
            } else {
                # No overlap.
                push @final, {
                    start => $span->{start} || $start,
                    end => $span->{end} || $end,
                };
            }
        } else {
            # @final has nothing in it yet.
            push @final, {
                start => $span->{start} || $start,
                end => $span->{end} || $end,
            };
        }
    }
    
    # Total up @final.
    my $sum = 0;
    foreach (@final) {
        $sum += $_->{end} - $_->{start};
    }
    
    return $sum;
}

1;
