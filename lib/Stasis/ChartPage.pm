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
    $params{grouper} = Stasis::ActorGroup->new;
    $params{grouper}->run( $params{raid}, $params{ext} );
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
    my %raiderIncoming;
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
            $raiderIncoming{$actor} ||= 0;

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

    # Calculate incoming damage
    my $raidInDamage = 0;
    while( my ($kactor, $vactor) = each(%{ $self->{ext}{Damage}{actors} }) ) {
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
				next unless $self->{raid}{$ktarget}{class};
				next if $self->{raid}{$ktarget}{class} eq "Pet";

				$raiderIncoming{$ktarget} ||= 0;
				$raiderIncoming{$ktarget} += $vtarget->{total};
				$raidInDamage += $vtarget->{total};
			}
		}
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
    
    $PAGE .= $pm->pageHeader($self->{name}, "", $raidStart);
    
    $PAGE .= $pm->vertBox( "Raid summary",
        "Duration"   => sprintf( "%dm%02ds", $raidPresence/60, $raidPresence%60 ),
        "Damage out" => sprintf( "%d", $raidDamage || 0 ),
        "DPS"        => sprintf( "%d", $raidDPS || 0 ),
        "Members"    => scalar keys %raiderDamage,
    );
    
    ################
    # DAMAGE CHART #
    ################
    
    $PAGE .= $pm->tableStart( "chart" );
    
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
                "R-Pres. DPS" => $raiderDamage{$actor} && $dpsTime && sprintf( "%d", $raiderDamage{$actor} / $ptime ),
                "R-Act. DPS" => $raiderDamage{$actor} && $dpsTime && sprintf( "%d", $raiderDamage{$actor} / $dpsTime ),
                "R-Activity" => $raiderDamage{$actor} && $dpsTime && $ptime && sprintf( "%0.1f%%", $dpsTime / $ptime * 100 ),
            },
            type => "",
        );
    }
    

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
    
    $PAGE .= $pm->tableHeader("<a name=\"damagein\"></a>Damage In", @damageInHeader);
    
    my @damageinsort = sort {
        $raiderIncoming{$b} <=> $raiderIncoming{$a} || $a cmp $b
    } keys %raiderIncoming;
    
    my $mostindmg = keys %raiderIncoming && $raiderIncoming{ $damageinsort[0] };
    
    foreach my $actor (@damageinsort) {
        my $ptime = $self->{ext}{Presence}{actors}{$actor}{end} - $self->{ext}{Presence}{actors}{$actor}{start};
        
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
    
    $PAGE .= $pm->tableHeader("<a name=\"healing\"></a>Healing", @healingHeader);    
    
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
    
    ##########
    # DEATHS #
    ##########

    $PAGE .= "<a name=\"deaths\"></a>";

    my @deathHeader = (
            "Death",
            "Time",
            "R-Health",
            "Event",
        );
        
    my @deathlist;

    foreach my $deathevent (keys %{$self->{ext}{Death}{actors}}) {
        if ($self->{raid}{$deathevent} && 
            $self->{raid}{$deathevent}{class} &&
            $self->{raid}{$deathevent}{class} ne "Pet") {
                push @deathlist, @{$self->{ext}{Death}{actors}{$deathevent}};
        }
    }

    @deathlist = sort { $a->{'t'} <=> $b->{'t'} } @deathlist;

    if( scalar @deathlist ) {

        $PAGE .= $pm->tableStart("chart");
        $PAGE .= $pm->tableHeader("Deaths", @deathHeader);
        my $deathid = 0;
        foreach my $death (@deathlist) {
            # Increment death ID.
            $deathid++;

            # Get the last line of the autopsy.
            my $lastline = pop @{$death->{autopsy}};
            push @{$death->{autopsy}}, $lastline;

            # Print the front row.
            my $text = $lastline->{text}||"";
            $text =~ s/\[\[([^\[\]]+?)\]\]/ $pm->actorLink($1, 1) /eg;
            $text =~ s/\{\{([^\{\}]+?)\}\}/ $pm->spellLink($1, $self->{ext}{Index}->spellname($1)) /eg;
            
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
                    name => "death_$deathid",
                );

            # Print subsequent rows.
            foreach my $line (@{$death->{autopsy}}) {
                my $t = ($line->{t}||0) - $raidStart;
                
                my $text = $line->{text}||"";
                $text =~ s/\[\[([^\[\]]+?)\]\]/ $pm->actorLink($1, 1) /eg;
                $text =~ s/\{\{([^\{\}]+?)\}\}/ $pm->spellLink($1, $self->{ext}{Index}->spellname($1)) /eg;
                
                $PAGE .= $pm->tableRow(
                        header => \@deathHeader,
                        data => {
                            "Death" => $line->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                            "R-Health" => $line->{hp} || "",
                            "Event" => $text,
                        },
                        type => "slave",
                        name => "death_$deathid",
                    );
            }

            $PAGE .= $pm->jsClose("death_$deathid");
        }

        $PAGE .= $pm->tableEnd;
    }
    
    ####################
    # RAID & MOBS LIST #
    ####################
    
    $PAGE .= $pm->tableStart("chart");
    
    {
        my @actorHeader = (
                "Actor",
                "Class",
                "Presence",
                "R-Presence %",
            );

        my @actorsort = sort {
            $self->{ext}{Index}->actorname($a) cmp $self->{ext}{Index}->actorname($b)
        } keys %{$self->{ext}{Presence}{actors}};
        
        $PAGE .= "<a name=\"actors\"></a>";
        $PAGE .= $pm->tableHeader("Raid &amp; Mobs", @actorHeader);

        my @rows;

        foreach my $actor (@actorsort) {
            my ($pstart, $pend, $ptime) = $self->{ext}{Presence}->presence($actor);
            
            my $group = $grouper->group($actor);
            if( $group ) {
                # See if this should be added to an existing row.
                
                my $found;
                foreach my $row (@rows) {
                    if( $row->{key} eq $grouper->captain($group) ) {
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
                        key => $grouper->captain($group),
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
    
    #####################
    # PRINT HTML FOOTER #
    #####################
    
    $PAGE .= $pm->pageFooter;
    
    #########################
    # PRINT OPENING XML TAG #
    #########################
    
    $XML .= sprintf( '  <raid dpstime="%d" start="%s" dps="%d" comment="%s" lg="%d" dmg="%d" dir="%s">' . "\n",
                100,
                $raidStart*1000 - 8*3600000,
                $raidDPS,
                $self->{name},
                $raidPresence*60000,
                $raidDamage,
                $self->{dirname},
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
        my $dpsTime = $self->{ext}{Activity}->activity( actor => [ $actor, @{ $self->{raid}{$actor}{pets} } ] );
        
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
            
            # Ignored values
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
