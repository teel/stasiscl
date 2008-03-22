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

package Stasis::ChartPage;

use strict;
use warnings;
use POSIX;
use Stasis::PageMaker;
use Data::Dumper;
use Carp;

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
    
    my $PAGE;
    my $XML;
    my $pm = Stasis::PageMaker->new;
    
    ############################
    # RAID DURATION / RAID DPS #
    ############################
    
    # Determine start time and end times (earliest/latest presence)
    my $raidStart;
    my $raidEnd;
    foreach ( keys %{$self->{ext}{Presence}{actors}} ) {
        if( !$raidStart || $self->{ext}{Presence}{actors}{$_}{start} < $raidStart ) {
            $raidStart = $self->{ext}{Presence}{actors}{$_}{start};
        }
                
        if( !$raidEnd || $self->{ext}{Presence}{actors}{$_}{start} > $raidEnd ) {
            $raidEnd = $self->{ext}{Presence}{actors}{$_}{start};
        }
    }
    
    # Raid duration
    my $raidPresence = $raidEnd - $raidStart;
    
    # Calculate raid DPS
    # Also get a list of total damage by raid member (on the side)
    my %raiderDamage;
    my $raidDamage;
    foreach my $actor (keys %{$self->{ext}{Damage}{actors}}) {
        # Only show raiders
        next unless $self->{raid}{$actor}{class} && $self->{raid}{$actor}{class} ne "Pet";
        
        foreach my $spell (keys %{$self->{ext}{Damage}{actors}{$actor}}) {
            foreach my $target (keys %{$self->{ext}{Damage}{actors}{$actor}{$spell}}) {
                # Skip friendlies
                next if $self->{raid}{$target}{class};
                
                $raiderDamage{$actor} += $self->{ext}{Damage}{actors}{$actor}{$spell}{$target}{total};
                $raidDamage += $self->{ext}{Damage}{actors}{$actor}{$spell}{$target}{total};
            }
        }
    }
    
    # Raid DPS
    my $raidDPS = $raidDamage / $raidPresence;
    
    ####################
    # PRINT TOP HEADER #
    ####################
    
    $PAGE .= $pm->pageHeader($self->{name}, $raidStart);
    
    $PAGE .= "<h3>Raid Information</h3>";
    $PAGE .= $pm->textBox( sprintf( "Raid duration: %02d:%02d<br />Raid DPS: %d", $raidPresence/60, $raidPresence%60, $raidDPS ) );
    
    #########################
    # PRINT OPENING XML TAG #
    #########################
    
    $XML .= sprintf( '  <raid dpstime="%d" start="%s" dps="%d" comment="%s" lg="%d" dir="%s">' . "\n",
                100,
                $raidStart*1000 - 8*3600000,
                $raidDPS,
                $self->{name},
                $raidPresence*60000,
                sprintf( "sws-%d", floor($raidStart) ),
            );
        
    # We will store player keys in here.
    my %xml_keys;
    
    #######################
    # PRINT CLOSING STUFF #
    #######################
    
    $XML .= "  </raid>\n";
    $PAGE .= $pm->pageFooter;
    
    return ($XML, $PAGE);
}

1;
