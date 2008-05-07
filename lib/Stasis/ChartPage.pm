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

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{ext} ||= {};
    $params{raid} ||= {};
    $params{name} ||= "Untitled";
    $params{short} ||= $params{name};
    
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
                
        if( !$raidEnd || $self->{ext}{Presence}{actors}{$_}{end} > $raidEnd ) {
            $raidEnd = $self->{ext}{Presence}{actors}{$_}{end};
        }
    }
    
    # Raid duration
    my $raidPresence = $raidEnd - $raidStart;
    
    # Calculate raid DPS
    # Also get a list of total damage by raid member (on the side)
    my %raiderDamage;
    my $raidDamage = 0;
    foreach my $actor (keys %{$self->{ext}{Presence}{actors}}) {
        # Only show raiders
        next unless $self->{raid}{$actor}{class};
        
        if( $self->{raid}{$actor}{class} eq "Pet" ) {
            # Pet.
            # Add damage to the raider.
            
            foreach my $spell (keys %{$self->{ext}{Damage}{actors}{$actor}}) {
                foreach my $target (keys %{$self->{ext}{Damage}{actors}{$actor}{$spell}}) {
                    # Skip friendlies
                    next if $self->{raid}{$target}{class};
                    
                    # Find the raider to add this damage to.
                    foreach my $raider (keys %{$self->{raid}}) {
                        next unless $self->{raid}{$raider}{pets} && grep $actor eq $_, @{$self->{raid}{$raider}{pets}};
                        
                        $raiderDamage{$raider} += $self->{ext}{Damage}{actors}{$actor}{$spell}{$target}{total};
                        $raidDamage += $self->{ext}{Damage}{actors}{$actor}{$spell}{$target}{total};
                        last;
                    }
                }
            }
        } else {
            # Raider.
            # Start it at zero.
            $raiderDamage{$actor} ||= 0;

            foreach my $spell (keys %{$self->{ext}{Damage}{actors}{$actor}}) {
                foreach my $target (keys %{$self->{ext}{Damage}{actors}{$actor}{$spell}}) {
                    # Skip friendlies
                    next if $self->{raid}{$target}{class};

                    $raiderDamage{$actor} += $self->{ext}{Damage}{actors}{$actor}{$spell}{$target}{total};
                    $raidDamage += $self->{ext}{Damage}{actors}{$actor}{$spell}{$target}{total};
                }
            }
        }
    }
    
    # Calculate raid healing
    # Also get a list of total healing and effectiving healing by raid member (on the side)
    my %raiderHealing;
    my %raiderHealingTotal;
    my $raidHealing = 0;
    my $raidHealingTotal = 0;
    foreach my $actor (keys %{$self->{ext}{Presence}{actors}}) {
        # Only show raiders
        next unless $self->{raid}{$actor}{class};
        
        if( $self->{raid}{$actor}{class} eq "Pet" ) {
            # Pet.
            # Add healing to the raider.
            
            foreach my $spell (keys %{$self->{ext}{Healing}{actors}{$actor}}) {
                foreach my $target (keys %{$self->{ext}{Healing}{actors}{$actor}{$spell}}) {
                    # Skip non-friendlies
                    next unless $self->{raid}{$target}{class};
                    
                    # Find the raider to add this Healing to.
                    foreach my $raider (keys %{$self->{raid}}) {
                        next unless $self->{raid}{$raider}{pets} && grep $actor eq $_, @{$self->{raid}{$raider}{pets}};
                        
                        $raiderHealing{$raider} += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{effective};
                        $raidHealing += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{effective};
                        $raiderHealingTotal{$raider} += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{total};
                        $raidHealingTotal += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{total};
                        last;
                    }
                }
            }
        } else {
            # Raider.
            # Start it at zero.
            $raiderHealing{$actor} ||= 0;
            $raiderHealingTotal{$actor} ||= 0;

            foreach my $spell (keys %{$self->{ext}{Healing}{actors}{$actor}}) {
                foreach my $target (keys %{$self->{ext}{Healing}{actors}{$actor}{$spell}}) {
                    # Skip friendlies
                    next unless $self->{raid}{$target}{class};

                    $raiderHealing{$actor} += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{effective};
                    $raidHealing += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{effective};
                    $raiderHealingTotal{$actor} += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{total};
                    $raidHealingTotal += $self->{ext}{Healing}{actors}{$actor}{$spell}{$target}{total};
                }
            }
        }
    }
    
    # Raid DPS
    my $raidDPS = $raidPresence && ($raidDamage / $raidPresence);
    
    ####################
    # PRINT TOP HEADER #
    ####################
    
    $PAGE .= $pm->pageHeader($self->{name}, $raidStart);
    
    $PAGE .= "<h3>Raid Information</h3>";
    $PAGE .= $pm->textBox( sprintf( "%d DPS over %dm%02ds<br />%d raid members", $raidDPS, $raidPresence/60, $raidPresence%60, scalar keys %raiderDamage ) );
    
    ################
    # DAMAGE CHART #
    ################
    
    $PAGE .= "<h3><a name=\"damage\"></a>Damage</h3>";
    
    $PAGE .= $pm->tableStart( "chart" );
    
    my @damageHeader = (
            "Player",
            "Presence",
            "R-Dam. Out",
            "R-Dam. %",
            "R-DPS",
            "R-DPS Time",
            " ",
        );
    
    $PAGE .= $pm->tableHeader(@damageHeader);
    
    my @damagesort = sort {
        $raiderDamage{$b} <=> $raiderDamage{$a} || $a cmp $b
    } keys %raiderDamage;
    
    my $mostdmg = keys %raiderDamage && $raiderDamage{ $damagesort[0] };
    
    foreach my $actor (@damagesort) {
        my $ptime = $self->{ext}{Presence}{actors}{$actor}{end} - $self->{ext}{Presence}{actors}{$actor}{start};
        
        $PAGE .= $pm->tableRow( 
            header => \@damageHeader,
            data => {
                "Player" => $pm->actorLink( $actor, $self->{ext}{Index}->actorname($actor), $self->{raid}{$actor}{class} ),
                "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Dam. %" => $raiderDamage{$actor} && $raidDamage && sprintf( "%d%%", ceil($raiderDamage{$actor} / $raidDamage * 100) ),
                "R-Dam. Out" => $raiderDamage{$actor},
                " " => $mostdmg && sprintf( "%d", ceil($raiderDamage{$actor} / $mostdmg * 100) ),
                "R-DPS" => $raiderDamage{$actor} && $self->{ext}{Activity}{actors}{$actor}{all}{time} && sprintf( "%d", $raiderDamage{$actor} / $self->{ext}{Activity}{actors}{$actor}{all}{time} ),
                "R-DPS Time" => $raiderDamage{$actor} && $self->{ext}{Activity}{actors}{$actor}{all}{time} && $ptime && sprintf( "%0.1f%%", $self->{ext}{Activity}{actors}{$actor}{all}{time} / $ptime * 100 ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    
    #################
    # HEALING CHART #
    #################
    
    $PAGE .= "<h3><a name=\"healing\"></a>Healing</h3>";
    
    $PAGE .= $pm->tableStart( "chart" );
    
    my @healingHeader = (
            "Player",
            "Presence",
            "R-Eff. Heal",
            "R-%",
            "R-Overheal",
            " ",
        );
    
    $PAGE .= $pm->tableHeader(@healingHeader);
    
    my @healsort = sort {
        $raiderHealing{$b} <=> $raiderHealing{$a} || $a cmp $b
    } keys %raiderHealing;
    
    my $mostheal = keys %raiderHealing && $raiderHealing{ $healsort[0] };
    
    foreach my $actor (@healsort) {
        my $ptime = $self->{ext}{Presence}{actors}{$actor}{end} - $self->{ext}{Presence}{actors}{$actor}{start};
        
        $PAGE .= $pm->tableRow( 
            header => \@healingHeader,
            data => {
                "Player" => $pm->actorLink( $actor, $self->{ext}{Index}->actorname($actor), $self->{raid}{$actor}{class} ),
                "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Eff. Heal" => $raiderHealing{$actor},
                "R-%" => $raiderHealing{$actor} && $raidHealing && sprintf( "%d%%", ceil($raiderHealing{$actor} / $raidHealing * 100) ),
                " " => $mostheal && $raiderHealing{$actor} && sprintf( "%d", ceil($raiderHealing{$actor} / $mostheal * 100) ),
                "R-Overheal" => $raiderHealingTotal{$actor} && $raiderHealing{$actor} && sprintf( "%0.1f%%", ($raiderHealingTotal{$actor}-$raiderHealing{$actor}) / $raiderHealingTotal{$actor} * 100 ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    
    ####################
    # RAID & MOBS LIST #
    ####################
    
    $PAGE .= "<h3><a name=\"actors\"></a>Raid &amp; Mobs</h3>";
    
    $PAGE .= $pm->tableStart("chart");
    
    my @actorHeader = (
            "Actor",
            "Class",
            "Presence",
            "R-Presence %",
        );
    
    my @actorsort = sort {
        $self->{ext}{Index}->actorname($a) cmp $self->{ext}{Index}->actorname($b)
    } keys %{$self->{ext}{Presence}{actors}};
        
    $PAGE .= $pm->tableHeader(@actorHeader);
    
    foreach my $actor (@actorsort) {
        my $ptime = $self->{ext}{Presence}{actors}{$actor}{end} - $self->{ext}{Presence}{actors}{$actor}{start};

        $PAGE .= $pm->tableRow( 
            header => \@actorHeader,
            data => {
                "Actor" => $pm->actorLink( $actor,  $self->{ext}{Index}->actorname($actor), $self->{raid}{$actor}{class} ),
                "Class" => $self->{raid}{$actor}{class} || "Mob",
                "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Presence %" => $raidPresence && sprintf( "%d%%", ceil($ptime/$raidPresence*100) ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    
    #####################
    # PRINT HTML FOOTER #
    #####################
    
    $PAGE .= $pm->pageFooter;
    
    #########################
    # PRINT OPENING XML TAG #
    #########################
    
    $XML .= sprintf( '  <raid dpstime="%d" start="%s" dps="%d" comment="%s" lg="%d" dir="%s">' . "\n",
                100,
                $raidStart*1000 - 8*3600000,
                $raidDPS,
                $self->{name},
                $raidPresence*60000,
                sprintf( "sws-%s-%d", $self->{short}, floor($raidStart) ),
            );
    
    #########################
    # PRINT PLAYER XML KEYS #
    #########################
    
    my %xml_classmap = (
            "Warrior" => "war",
            "Druid" => "drd",
            "Warlock" => "wrl",
            "Shaman" => "sha",
            "Paladin" => "pal",
            "Priest" => "pri",
            "Rogue" => "rog",
            "Mage" => "mag",
            "Hunter" => "hnt",
        );
        
    foreach my $actor (@damagesort) {
        my $ptime = $self->{ext}{Presence}{actors}{$actor}{end} - $self->{ext}{Presence}{actors}{$actor}{start};
        
        my %xml_keys = (
            name => $self->{ext}{Index}->actorname($actor) || "Unknown",
            classe => $xml_classmap{ $self->{raid}{$actor}{class} } || "war",
            dps => $self->{ext}{Activity}{actors}{$actor}{all}{time} && ceil( $raiderDamage{$actor} / $self->{ext}{Activity}{actors}{$actor}{all}{time} ) || 0,
            dpstime => $self->{ext}{Activity}{actors}{$actor}{all}{time} && $ptime && $self->{ext}{Activity}{actors}{$actor}{all}{time} / $ptime * 100 || 0,
            dmgout => $raiderDamage{$actor} && $raidDamage && $raiderDamage{$actor} / $raidDamage * 100 || 0,
            heal => $raiderHealing{$actor} && $raidHealing && $raiderHealing{$actor} / $raidHealing * 100 || 0,
            ovh => $raiderHealing{$actor} && $raiderHealingTotal{$actor} && ceil( ($raiderHealingTotal{$actor} - $raiderHealing{$actor}) / $raiderHealingTotal{$actor} * 100 ) || 0,
            death => 0,
            
            # Ignored values
            dmgin => 0,
            decurse => 0,
            pres => 100,
        );
        
        $XML .= sprintf "    <player %s />\n", join " ", map { sprintf "%s=\"%s\"", $_, $xml_keys{$_} } (keys %xml_keys);
    }
    
    ####################
    # PRINT XML FOOTER #
    ####################
    
    $XML .= "  </raid>\n";
    
    return ($XML, $PAGE);
}

1;
