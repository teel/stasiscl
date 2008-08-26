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

package Stasis::Extension::Activity;

use strict;
use warnings;
use Stasis::Extension;

our @ISA = "Stasis::Extension";

sub start {
    my $self = shift;
    $self->{actors} = {};
    $self->{span_scratch} = {};
    $self->{last_scratch} = {};
    
    # No damage for this long will end a DPS span.
    $self->{_dpstimeout} = 5;
}

sub actions {
    return qw(ENVIRONMENTAL_DAMAGE SWING_DAMAGE SWING_MISSED RANGE_DAMAGE RANGE_MISSED SPELL_DAMAGE DAMAGE_SPLIT SPELL_MISSED SPELL_PERIODIC_DAMAGE SPELL_PERIODIC_MISSED DAMAGE_SHIELD DAMAGE_SHIELD_MISSED);
}

sub process {
    my ($self, $entry) = @_;
    
    # This was a damage event, or an attempted damage event.
    
    # We are going to take some liberties with environmental damage and white damage in order to get them
    # into the neat actor > spell > target framework. Namely an abuse of actor IDs and spell IDs (using
    # "0" as an actor ID for the environment and using "0" for the spell ID to signify a white hit). These
    # will both fail to look up in Index, but that's okay.
    my $actor;
    my $spell;
    if( $entry->{action} eq "ENVIRONMENTAL_DAMAGE" ) {
        $actor = 0;
        $spell = 0;
    } elsif( $entry->{action} eq "SWING_DAMAGE" || $entry->{action} eq "SWING_MISSED" ) {
        $actor = $entry->{actor};
        $spell = 0;
    } else {
        $actor = $entry->{actor};
        $spell = $entry->{extra}{spellid};
    }
    
    my $target = $entry->{target};
    
    # Create a scratch hash for this actor/target pair if it does not exist already.
    $self->{span_scratch}{ $actor }{ $target } ||= {
        start => 0,
        end => 0,
    };
    
    # Track DPS time.
    my $adata = $self->{span_scratch}{ $actor }{ $target };
    if( !$adata->{start} ) {
        # This is the first DPS action, so mark the start of a span.
        $adata->{start} = $entry->{t};
        $adata->{end} = $entry->{t};
    } elsif( $adata->{end} + $self->{_dpstimeout} < $entry->{t} ) {
        # The last span ended, add it.
        $self->{actors}{ $actor }{ $target } ||= [];
        
        my $span = {
            start => $adata->{start},
            end => $adata->{end} + $self->{_dpstimeout},
        };
        
        push @{$self->{actors}{ $actor }{ $target }}, $span;
        
        # Update last_scratch
        if( !$self->{last_scratch}{$actor} || $span->{end} > $self->{last_scratch}{$actor}{end} ) {
            $self->{last_scratch}{$actor} = $span;
        }
        
        # Reset the start and end times to the current time.
        $adata->{start} = $entry->{t};
        $adata->{end} = $entry->{t};
    } else {
        # The last span is continuing.
        $adata->{end} = $entry->{t};
    }
}

sub finish {
    my $self = shift;
    
    # We need to close up all the un-closed dps spans.
    while( my ($kactor, $vactor) = each( %{ $self->{span_scratch} } ) ) {
        while( my ($ktarget, $vtarget) = each( %$vactor ) ) {
            $self->{actors}{ $kactor }{ $ktarget } ||= [];
            
            my $span = {
                start => $vtarget->{start},
                end => $vtarget->{end} + $self->{_dpstimeout},
            };
            
            push @{$self->{actors}{ $kactor }{ $ktarget }}, $span;
            
            # Update last_scratch
            if( !$self->{last_scratch}{$kactor} || $span->{end} > $self->{last_scratch}{$kactor}{end} ) {
                $self->{last_scratch}{$kactor} = $span;
            }
        }
    }
    
    # Remove _dpstimeout from all last spans for each actor.
    foreach (values %{ $self->{last_scratch} }) {
        $_->{end} -= $self->{_dpstimeout};
    }
    
    delete $self->{span_scratch};
    delete $self->{last_scratch};
}

# Returns total for a set of actors "actor" onto targets "target".
# If blank will use all.
sub activity {
    my $self = shift;
    my %params = @_;
    
    $params{actor} ||= [];
    $params{target} ||= [];
    
    # Store relevant activity spans.
    my @span;
    
    while( my ($kactor, $vactor) = each( %{ $self->{actors} } ) ) {
        # Skip actors we do not wish to examine.
        next if @{$params{actor}} && ! grep $_ eq $kactor, @{$params{actor}};
        
        while( my ($ktarget, $vtarget) = each( %$vactor ) ) {
            # Skip targets we do not wish to examine.
            next if @{$params{target}} && ! grep $_ eq $ktarget, @{$params{target}};
            
            # Include the spans listed in $vtarget (an array of start/end hashes)
            push @span, @$vtarget;
        }
    }
    
    # Sort spans by start time.
    @span = sort { $a->{start} <=> $b->{start} } @span;
    
    # Store the final list in here.
    my @final = ();
    
    foreach my $span (@span) {
        # We are assured that $span starts at the same time as, or after, everything in @final.
        # If it overlaps the last span in @final then merge it in.
        
        if( @final ) {
            my $last = $final[$#final];
            if( $span->{start} <= $last->{end} ) {
                # There is an overlap.
                if( $span->{end} > $last->{end} ) {
                    # Extend $last.
                    $last->{end} = $span->{end};
                }
            } else {
                # No overlap.
                push @final, {
                    start => $span->{start},
                    end => $span->{end},
                };
            }
        } else {
            # @final has nothing in it yet.
            push @final, {
                start => $span->{start},
                end => $span->{end},
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
