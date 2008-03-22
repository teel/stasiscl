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

package Stasis::ActorPage;

use strict;
use warnings;
use POSIX;
use Stasis::PageMaker;

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{ext} ||= {};
    $params{raid} ||= {};
    $params{name} ||= "Untitled";
    
    bless \%params, $class;
}

sub page {
    my $self = shift;
    my $PLAYER = shift;
    
    my $PAGE;
        
    my $pm = Stasis::PageMaker->new;
    
    #################
    # RAID DURATION #
    #################
    
    # Determine start time and end times (earliest/latest presence)
    my $raidStart;
    my $raidEnd;
    foreach ( keys %{$self->{ext}{Presence}{actors}} ) {
        if( !$raidStart || $self->{ext}{Presence}{actors}{$_}{start} < $raidStart ) {
            $raidStart = $self->{ext}{Presence}{actors}{$_}{start};
        }
                
        if( !$raidEnd || $self->{ext}{Presence}{actors}{$_}{end} > $raidEnd ) {
            $raidEnd = $self->{ext}{Presence}{actors}{$_}{end};
        }
    }
    
    # Raid duration
    my $raidPresence = $raidEnd - $raidStart;
    
    #####################
    # TOTAL DAMAGE DONE #
    #####################
    
    my $alldmg = 0;
    if( $self->{ext}{Damage}{actors}{$PLAYER} ) {
        foreach my $spell (keys %{$self->{ext}{Damage}{actors}{$PLAYER}}) {
            foreach my $target (keys %{$self->{ext}{Damage}{actors}{$PLAYER}{$spell}}) {
                # Skip friendlies
                next if $self->{raid}{$target}{class};

                # Add the damage.
                $alldmg += $self->{ext}{Damage}{actors}{$PLAYER}{$spell}{$target}{total};
            }
        }
    }
    
    ###############
    # PAGE HEADER #
    ###############
    
    $PAGE .= $pm->pageHeader($self->{name}, $raidStart);
    $PAGE .= sprintf "<h3 style=\"color: #%s\">%s</h3>", $pm->classColor( $self->{raid}{$PLAYER}{class} ), $PLAYER;
    
    my $ptime = $self->{ext}{Presence}{actors}{$PLAYER}{end} - $self->{ext}{Presence}{actors}{$PLAYER}{start};
    my $presence_text = sprintf( "Presence: %02d:%02d", $ptime/60, $ptime%60 );
    $presence_text .= sprintf( "<br />DPS time: %02d:%02d (%0.1f%% of presence), %d DPS", 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}/60, 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}%60, 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}/$ptime*100, 
        $alldmg/$self->{ext}{Activity}{actors}{$PLAYER}{all}{time} ) 
            if $ptime && $alldmg && $self->{ext}{Activity}{actors}{$PLAYER} && $self->{ext}{Activity}{actors}{$PLAYER}{all}{time};
    
    $PAGE .= $pm->textBox( $presence_text, "Actor Information" );
    
    $PAGE .= "<br />";
    
    ##########
    # FOOTER #
    ##########
    
    $PAGE .= $pm->pageFooter;
}

1;
