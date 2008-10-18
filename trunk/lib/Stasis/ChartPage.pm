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
use Stasis::ActorGroup;

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{ext} ||= {};
    $params{raid} ||= {};
    
    if( !$params{grouper} ) {
        $params{grouper} = Stasis::ActorGroup->new;
        $params{grouper}->run( $params{raid}, $params{ext} );
    }
    
    $params{pm} ||= Stasis::PageMaker->new( raid => $params{raid}, ext => $params{ext}, grouper => $params{grouper}, collapse => $params{collapse} );
    $params{name} ||= "Untitled";
    $params{short} ||= $params{name};
    
    bless \%params, $class;
}

sub page {
    my $self = shift;
    
    my $PAGE;
    my $XML;
    
    my $grouper = $self->{grouper};
    my $pm = $self->{pm};
    
    ############################
    # RAID DURATION / RAID DPS #
    ############################
    
    # Determine start time and end times (earliest/latest presence)
    my ($raidStart, $raidEnd, $raidPresence) = $self->{ext}{Presence}->presence;
    
    # Figure out pet owners.
    my %powner;
    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        if( $ractor->{pets} ) {
            foreach my $p (@{$ractor->{pets}}) {
                $powner{ $p } = $kactor;
            }
        }
    }
    
    # Calculate raid DPS
    # Also get a list of total damage by raid member (on the side)
    my %raiderDamage;
    my %raiderIncoming;
    my $raidDamage = 0;
    
    my @raiders = map { $self->{raid}{$_}{class} ? ( $_ ) : () } keys %{$self->{raid}};
    
    # All damage done by raiders and their pets
    my $deOutAll = $self->{ext}{Damage}->sum( actor => \@raiders, expand => [ "actor" ], fields => [ "total" ] );
    
    # Friendly fire by raiders and their pets
    my $deOutFriendly = $self->{ext}{Damage}->sum( actor => \@raiders, target => \@raiders, expand => [ "actor" ], fields => [ "total" ] );
    
    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        # Only show raiders
        next unless $ractor->{class} && $self->{ext}{Presence}->presence($kactor);
        
        my $raider = $ractor->{class} eq "Pet" ? $powner{ $kactor } : $kactor;
        $raiderDamage{$raider} ||= 0;
        $raiderIncoming{$raider} ||= 0;
        
        $raiderDamage{$raider} += $deOutAll->{$kactor}{total} || 0 if $deOutAll->{$kactor};
        $raiderDamage{$raider} -= $deOutFriendly->{$kactor}{total} || 0 if $deOutFriendly->{$kactor};
    }
    
    foreach (values %raiderDamage) {
        $raidDamage += $_;
    }
    
    # Calculate incoming damage
    my $raidInDamage = 0;
    my $deInAll = $self->{ext}{Damage}->sum( target => \@raiders, expand => [ "target" ], fields => [ "total" ] );
    while( my ($kactor, $ractor) = each %{$self->{raid}} ) {
        # Only show raiders
        next if !$ractor->{class} || $ractor->{class} eq "Pet" || !$self->{ext}{Presence}->presence($kactor);
        
        $raiderIncoming{$kactor} += $deInAll->{$kactor}{total} || 0 if $deInAll->{$kactor};
        $raidInDamage += $deInAll->{$kactor}{total} || 0 if $deInAll->{$kactor};
    }

	# Calculate death count
	my %deathCount;
    foreach my $deathevent (keys %{$self->{ext}{Death}{actors}}) {
        if ($self->{raid}{$deathevent} && 
            $self->{raid}{$deathevent}{class} &&
            $self->{raid}{$deathevent}{class} ne "Pet") {
				$deathCount{$deathevent} = @{$self->{ext}{Death}{actors}{$deathevent}};
        }
    }
    
    # Calculate raid healing
    # Also get a list of total healing and effectiving healing by raid member (on the side)
    my %raiderHealing;
    my %raiderHealingTotal;
    my $raidHealing = 0;
    my $raidHealingTotal = 0;
    
    # Friendly healing by raiders and their pets
    my $heOutFriendly = $self->{ext}{Healing}->sum( actor => \@raiders, target => \@raiders, expand => [ "actor" ], fields => [ "effective", "total" ] );
    
    while( my ($kactor, $ractor) = each (%{$self->{raid}}) ) {
        # Only show raiders
        next unless $ractor->{class} && $self->{ext}{Presence}->presence($kactor);
        
        my $raider = $ractor->{class} eq "Pet" ? $powner{ $kactor } : $kactor;
        $raiderHealing{$raider} ||= 0;
        $raiderHealingTotal{$raider} ||= 0;
        
        $raiderHealing{$raider} += $heOutFriendly->{$kactor}{effective} || 0 if $heOutFriendly->{$kactor};
        $raiderHealingTotal{$raider} += $heOutFriendly->{$kactor}{total} || 0 if $heOutFriendly->{$kactor};
        
        $raidHealing += $heOutFriendly->{$kactor}{effective} || 0;
        $raidHealingTotal += $heOutFriendly->{$kactor}{total} || 0;
    }
    
    # Raid DPS
    my $raidDPS = $raidPresence && ($raidDamage / $raidPresence);
    
    ####################
    # PRINT TOP HEADER #
    ####################
    
    $PAGE .= $pm->pageHeader($self->{name}, "", $raidStart);
    
    $PAGE .= $pm->vertBox( "Raid summary",
        "Duration"   => sprintf( "%dm%02ds", $raidPresence/60, $raidPresence%60 ),
        "Damage out" => sprintf( "%d", $raidDamage || 0 ),
        "DPS"        => sprintf( "%d", $raidDPS || 0 ),
        "Members"    => scalar keys %raiderDamage,
    );
    
    ############
    # TAB LIST #
    ############
    
    my @deathlist;

    foreach my $deathevent (keys %{$self->{ext}{Death}{actors}}) {
        if ($self->{raid}{$deathevent} && 
            $self->{raid}{$deathevent}{class} &&
            $self->{raid}{$deathevent}{class} ne "Pet") {
                push @deathlist, @{$self->{ext}{Death}{actors}{$deathevent}};
        }
    }

    @deathlist = sort { $a->{'t'} <=> $b->{'t'} } @deathlist;
    
    my @tabs = ( "Damage Out", "Damage In", "Healing", "Raid & Mobs", "Deaths" );
    $PAGE .= "<br />" . $pm->tabBar(@tabs);
    
    ################
    # DAMAGE CHART #
    ################
    
    my @damageHeader = (
            "Player",
            "R-Presence",
            "R-Activity",
            "R-Pres. DPS",
            "R-Act. DPS",
            "R-Dam. Out",
            "R-%",
            " ",
        );
    
    $PAGE .= $pm->tabStart("Damage Out");
    $PAGE .= $pm->tableStart();
    $PAGE .= $pm->tableHeader("Damage Out", @damageHeader);
    
    my @damagesort = sort {
        $raiderDamage{$b} <=> $raiderDamage{$a} || $a cmp $b
    } keys %raiderDamage;
    
    my $mostdmg = keys %raiderDamage && $raiderDamage{ $damagesort[0] };
    
    foreach my $actor (@damagesort) {
        my $ptime = $self->{ext}{Presence}->presence($actor);
        my $dpsTime = $self->{ext}{Activity}->activity( actor => [ $actor, @{ $self->{raid}{$actor}{pets} } ] );
        
        $PAGE .= $pm->tableRow( 
            header => \@damageHeader,
            data => {
                "Player" => $pm->actorLink( $actor, $self->{ext}{Index}->actorname($actor), $self->{raid}{$actor}{class} ),
                "R-Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-%" => $raiderDamage{$actor} && $raidDamage && sprintf( "%d%%", ceil($raiderDamage{$actor} / $raidDamage * 100) ),
                "R-Dam. Out" => $raiderDamage{$actor},
                " " => $mostdmg && sprintf( "%d", ceil($raiderDamage{$actor} / $mostdmg * 100) ),
                "R-Pres. DPS" => $raiderDamage{$actor} && $dpsTime && $ptime && sprintf( "%d", $raiderDamage{$actor} / $ptime ),
                "R-Act. DPS" => $raiderDamage{$actor} && $dpsTime && sprintf( "%d", $raiderDamage{$actor} / $dpsTime ),
                "R-Activity" => $dpsTime && $ptime && sprintf( "%0.1f%%", $dpsTime / $ptime * 100 ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;

    #########################
    # DAMAGE INCOMING CHART #
    #########################
    
    my @damageInHeader = (
            "Player",
            "R-Presence",
            "",
            "R-Deaths",
            "",
            "R-Dam. In",
            "R-%",
            " ",
        );
    
    $PAGE .= $pm->tabStart("Damage In");
    $PAGE .= $pm->tableStart();
    $PAGE .= $pm->tableHeader("Damage In", @damageInHeader);
    
    my @damageinsort = sort {
        $raiderIncoming{$b} <=> $raiderIncoming{$a} || $a cmp $b
    } keys %raiderIncoming;
    
    my $mostindmg = keys %raiderIncoming && $raiderIncoming{ $damageinsort[0] };
    
    foreach my $actor (@damageinsort) {
        my $ptime = $self->{ext}{Presence}->presence($actor);
        
        $PAGE .= $pm->tableRow( 
            header => \@damageInHeader,
            data => {
                "Player" => $pm->actorLink( $actor, $self->{ext}{Index}->actorname($actor), $self->{raid}{$actor}{class} ),
                "R-Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-%" => $raiderIncoming{$actor} && $raidInDamage && sprintf( "%d%%", ceil($raiderIncoming{$actor} / $raidInDamage * 100) ),
                "R-Dam. In" => $raiderIncoming{$actor},
                "R-Deaths" => $deathCount{$actor} || " 0",
                " " => $mostindmg && sprintf( "%d", ceil($raiderIncoming{$actor} / $mostindmg * 100) ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    #################
    # HEALING CHART #
    #################
    
    my @healingHeader = (
            "Player",
            "R-Presence",
            "",
            "R-Overheal",
            "",
            "R-Eff. Heal",
            "R-%",
            " ",
        );
        
    $PAGE .= $pm->tabStart("Healing");
    $PAGE .= $pm->tableStart();
    $PAGE .= $pm->tableHeader("Healing", @healingHeader);    
    
    my @healsort = sort {
        $raiderHealing{$b} <=> $raiderHealing{$a} || $a cmp $b
    } keys %raiderHealing;
    
    my $mostheal = keys %raiderHealing && $raiderHealing{ $healsort[0] };
    
    foreach my $actor (@healsort) {
        my $ptime = $self->{ext}{Presence}->presence($actor);
        
        $PAGE .= $pm->tableRow( 
            header => \@healingHeader,
            data => {
                "Player" => $pm->actorLink( $actor, $self->{ext}{Index}->actorname($actor), $self->{raid}{$actor}{class} ),
                "R-Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Eff. Heal" => $raiderHealing{$actor},
                "R-%" => $raiderHealing{$actor} && $raidHealing && sprintf( "%d%%", ceil($raiderHealing{$actor} / $raidHealing * 100) ),
                " " => $mostheal && $raiderHealing{$actor} && sprintf( "%d", ceil($raiderHealing{$actor} / $mostheal * 100) ),
                "R-Overheal" => $raiderHealingTotal{$actor} && $raiderHealing{$actor} && sprintf( "%0.1f%%", ($raiderHealingTotal{$actor}-$raiderHealing{$actor}) / $raiderHealingTotal{$actor} * 100 ),
            },
            type => "",
        );
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    ####################
    # RAID & MOBS LIST #
    ####################
    
    my @actorHeader = (
        "Actor",
        "Class",
        "Presence",
        "R-Presence %",
    );
        
    $PAGE .= $pm->tabStart("Raid & Mobs");
    $PAGE .= $pm->tableStart();
    
    {
        my @actorsort = sort {
            $self->{ext}{Index}->actorname($a) cmp $self->{ext}{Index}->actorname($b)
        } keys %{$self->{ext}{Presence}{actors}};
        
        $PAGE .= "";
        $PAGE .= $pm->tableHeader("Raid &amp; Mobs", @actorHeader);

        my @rows;

        foreach my $actor (@actorsort) {
            my ($pstart, $pend, $ptime) = $self->{ext}{Presence}->presence($actor);
            
            my $group = $grouper->group($actor);
            if( $group ) {
                # See if this should be added to an existing row.
                
                my $found;
                foreach my $row (@rows) {
                    if( $row->{key} eq $group->{members}->[0] ) {
                        # It exists. Add this data to the existing master row.
                        $row->{row}{start} = $pstart if( $row->{row}{start} > $pstart );
                        $row->{row}{end} = $pstart if( $row->{row}{end} < $pend );
                        
                        $found = 1;
                        last;
                    }
                }
                
                if( !$found ) {
                    # Create the row.
                    push @rows, {
                        key => $group->{members}->[0],
                        row => {
                            start => $pstart,
                            end => $pend,
                        },
                    }
                }
            } else {
                # Create the row.
                push @rows, {
                    key => $actor,
                    row => {
                        start => $pstart,
                        end => $pend,
                    },
                }
            }
        }
        
        foreach my $row (@rows) {
            # Master row
            my $class = $self->{raid}{$row->{key}}{class} || "Mob";
            my $owner;
            
            if( $class eq "Pet" ) {
                foreach (keys %{$self->{raid}}) {
                    if( grep $_ eq $row->{key}, @{$self->{raid}{$_}{pets}}) {
                        $owner = $_;
                        last;
                    }
                }
            }
            
            my $group = $grouper->group($row->{key});
            my ($pstart, $pend, $ptime) = $self->{ext}{Presence}->presence( $group ? @{$group->{members}} : $row->{key} );
            
            $PAGE .= $pm->tableRow( 
                header => \@actorHeader,
                data => {
                    "Actor" => $pm->actorLink( $row->{key} ),
                    "Class" => $class . ($owner ? " (" . $pm->actorLink($owner) . ")" : "" ),
                    "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                    "R-Presence %" => $raidPresence && sprintf( "%d%%", ceil($ptime/$raidPresence*100) ),
                },
                type => "",
            );
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    ##########
    # DEATHS #
    ##########

    $PAGE .= "";

    my @deathHeader = (
        "Death",
        "Time",
        "R-Health",
        "Event",
    );
    
    $PAGE .= $pm->tabStart("Deaths");
    $PAGE .= $pm->tableStart();
    
    my %dnum;
    if( scalar @deathlist ) {
        $PAGE .= $pm->tableHeader("Deaths", @deathHeader);
        foreach my $death (@deathlist) {
            my $id = lc $death->{actor};
            $id = $self->{pm}->tameText($id);
            
            # Get the last line of the autopsy.
            my $lastline = $death->{autopsy}->[-1];
            my $text = Stasis::Parser->toString( 
                $lastline->{entry}, 
                sub { $self->{pm}->actorLink( $_[0], 1 ) }, 
                sub { $self->{pm}->spellLink( $_[0] ) } 
            );
            
            my $t = $death->{t} - $raidStart;
            $PAGE .= $pm->tableRow(
                header => \@deathHeader,
                data => {
                    "Death" => $pm->actorLink( $death->{actor},  $self->{ext}{Index}->actorname($death->{actor}), $self->{raid}{$death->{actor}}{class} ),
                    "Time" => $death->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                    "R-Health" => $lastline->{hp} || "",
                    "Event" => $text,
                },
                type => "master",
                url => sprintf( "death_%s_%d.html", $id, ++$dnum{ $death->{actor} } ),
            );
            
            # Print subsequent rows.
            foreach my $line (@{$death->{autopsy}}) {
                $PAGE .= $pm->tableRow(
                    header => \@deathHeader,
                    data => {},
                    type => "slave",
                );
            }
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    #####################
    # PRINT HTML FOOTER #
    #####################
    
    $PAGE .= $pm->jsTab("Damage Out");
    $PAGE .= $pm->tabBarEnd;
    $PAGE .= $pm->pageFooter;
    
    if( wantarray ) {
        #########################
        # PRINT OPENING XML TAG #
        #########################
        
        $XML .= sprintf( '  <raid dpstime="%d" start="%s" dps="%d" comment="%s" lg="%d" dmg="%d" dir="%s" zone="%s">' . "\n",
            100,
            $raidStart*1000,
            $raidDPS,
            $self->{name},
            $raidPresence*60000,
            $raidDamage,
            $self->{dirname},
            Stasis::LogSplit->zone( $self->{short} ) || "",
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
            "Death Knight" => "dk",
        );

        foreach my $actor (@damagesort) {
            my $ptime = $self->{ext}{Presence}->presence($actor);
            my $dpsTime = $self->{ext}{Activity}->activity( actor => [ $actor, @{ $self->{raid}{$actor}{pets} } ] );
            
            # Count decurses.
            my $decurse = 0;
            if( exists $self->{ext}{Dispel}{actors}{$actor} ) {
                while( my ($kspell, $vspell) = each(%{ $self->{ext}{Dispel}{actors}{$actor} } ) ) {
                    while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                        while( my ($kextraspell, $vextraspell) = each (%$vtarget) ) {
                            # Add the row.
                            $decurse += $vextraspell->{count} - ($vextraspell->{resist}||0);
                        }
                    }
                }
            }

            my %xml_keys = (
                name => $self->{ext}{Index}->actorname($actor) || "Unknown",
                classe => $xml_classmap{ $self->{raid}{$actor}{class} } || "war",
                dps => $dpsTime && ceil( $raiderDamage{$actor} / $dpsTime ) || 0,
                dpstime => $dpsTime && $ptime && $dpsTime / $ptime * 100 || 0,
                dmgout => $raiderDamage{$actor} && $raidDamage && $raiderDamage{$actor} / $raidDamage * 100 || 0,
                dmgin => $raiderIncoming{$actor} && $raidInDamage && $raiderIncoming{$actor} / $raidInDamage * 100 || 0,
                heal => $raiderHealing{$actor} && $raidHealing && $raiderHealing{$actor} / $raidHealing * 100 || 0,
                ovh => $raiderHealing{$actor} && $raiderHealingTotal{$actor} && ceil( ($raiderHealingTotal{$actor} - $raiderHealing{$actor}) / $raiderHealingTotal{$actor} * 100 ) || 0,
                death => $deathCount{$actor} || 0,
                decurse => $decurse,
                
                # Ignored values
                pres => 100,
            );

            $XML .= sprintf "    <player %s />\n", join " ", map { sprintf "%s=\"%s\"", $_, $xml_keys{$_} } (keys %xml_keys);
        }

        ####################
        # PRINT XML FOOTER #
        ####################

        $XML .= "  </raid>\n";
    }
    
    return wantarray ? ($XML, $PAGE) : $PAGE;
}

1;
