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
use HTML::Entities;
use Stasis::PageMaker;
use Stasis::ActorGroup;

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{ext} ||= {};
    $params{raid} ||= {};
    $params{grouper} = Stasis::ActorGroup->new;
    $params{grouper}->run( $params{raid}, $params{ext} );
    $params{name} ||= "Untitled";
    
    bless \%params, $class;
}

sub page {
    my $self = shift;
    my $MOB = shift;
    my $do_group = shift;
    
    my $MOB_GROUP = $self->{grouper}->group($MOB);
    my @PLAYER = $do_group && $MOB_GROUP ? @{ $MOB_GROUP->{members} } : ($MOB);
    
    return unless @PLAYER;
    
    my $PAGE;
    
    my $pm = Stasis::PageMaker->new( raid => $self->{raid}, ext => $self->{ext}, grouper => $self->{grouper} );
    
    #################
    # RAID DURATION #
    #################
    
    # Determine start time and end times (earliest/latest presence)
    my ($raidStart, $raidEnd, $raidPresence) = $self->{ext}{Presence}->presence();
    my ($pstart, $pend, $ptime) = $self->{ext}{Presence}->presence( @PLAYER );
    
    # Player and pets
    my @playpet = ( @PLAYER );
    foreach (@PLAYER) {
        push @playpet, @{$self->{raid}{$_}{pets}} if( exists $self->{raid}{$_} && exists $self->{raid}{$_}{pets} );
    }
    
    # Damage to mobs
    my $dmg_to_mobs = 0;
    foreach my $kactor (@playpet) {
        while( my ($kspell, $vspell) = each(%{ $self->{ext}{Damage}{actors}{$kactor} } ) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                unless( $self->{raid}{$ktarget} && $self->{raid}{$ktarget}{class} ) {
                    $dmg_to_mobs += $vtarget->{total};
                }
            }
        }
    }
    
    ###############
    # PAGE HEADER #
    ###############
    
    my $displayName = sprintf "%s%s", HTML::Entities::encode_entities($self->{ext}{Index}->actorname($MOB)), @PLAYER > 1 ? " (group)" : "";
    $PAGE .= $pm->pageHeader($self->{name}, $displayName, $raidStart);
    $PAGE .= sprintf "<h3 class=\"color%s\">%s</h3>", $self->{raid}{$MOB}{class} || "Mob", $displayName;
    
    my @summaryRows;
    
    # Type info
    push @summaryRows, "Class" => $self->{raid}{$MOB}{class} || "Mob";
    
    # Presence
    push @summaryRows, "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 );
    
    # Pet info
    if( $self->{raid}{$MOB} && $self->{raid}{$MOB}{class} && $self->{raid}{$MOB}{class} eq "Pet" ) {
        foreach my $raider (keys %{$self->{raid}}) {
            if( grep $_ eq $MOB, @{$self->{raid}{$raider}{pets}}) {
                push @summaryRows, "Owner" => $pm->actorLink($raider);
                last;
            }
        }
    }
    
    # DPS Info
    if( !$do_group && $ptime && $dmg_to_mobs && $self->{ext}{Activity}{actors}{$MOB} && $self->{ext}{Activity}{actors}{$MOB}{time} ) {
        push @summaryRows, (
            "DPS Activity" => sprintf
            (
                "%02d:%02d (%0.1f%% of presence)",
                $self->{ext}{Activity}{actors}{$MOB}{time}/60, 
                $self->{ext}{Activity}{actors}{$MOB}{time}%60, 
                $self->{ext}{Activity}{actors}{$MOB}{time}/$ptime*100, 
            ),
            "DPS (over presence)" => sprintf( "%d", $dmg_to_mobs/$ptime ),
            "DPS (over activity)" => sprintf( "%d", $dmg_to_mobs/$self->{ext}{Activity}{actors}{$MOB}{time} ),
        );
    }
    
    $PAGE .= $pm->vertBox( "Summary", @summaryRows );
    $PAGE .= "<br />";
    
    if( $MOB_GROUP ) {
        # Group information
        my $group_text = "<div align=\"left\">This is a group composed of multiple mobs.<br />";
        
        $group_text .= "<br /><b>Group Link</b></br />";
        $group_text .= sprintf "%s%s<br />", $pm->actorLink($MOB), ( $do_group ? " (currently viewing)" : "" );
        
        $group_text .= "<br /><b>Member Links</b></br />";
        
        foreach (@{$MOB_GROUP->{members}}) {
            $group_text .= sprintf "%s%s<br />", $pm->actorLink($_, 1), ( !$do_group && $_ eq $MOB ? " (currently viewing)" : "" );
        }
        
        
        $group_text .= "</div>";
        
        $PAGE .= $pm->textBox( $group_text, "Group Information" );
        $PAGE .= "<br />";
    }
    
    my @tabs = ( "Damage", "Healing", "Casts and Gains" );
    push @tabs, "Deaths" if $self->_keyExists( $self->{ext}{Death}{actors}, @PLAYER );
    
    $PAGE .= $pm->tabBar(@tabs);
    
    ##########
    # DAMAGE #
    ##########
    
    $PAGE .= $pm->tabStart("Damage");
    $PAGE .= $pm->tableStart;
    
    {
        my @header = (
            "Ability",
            "R-Total",
            "R-Hits",
            "R-Avg Hit",
            "R-Crits",
            "R-Avg Crit",
            "R-Ticks",
            "R-Avg Tick",
            "R-CriCruGla %",
            "MDPBARI %",
        );
        
        # Group by ability.
        my @rows = $self->_abilityRows( $self->{ext}{Damage}, @playpet );
        
        # Sort @rows.
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Damage Out by Ability", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Decode spell name
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($row->{key}, $pm, @PLAYER);
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => $self->_rowDamage( $row->{row}, $spellname ),
                    type => "master",
                    name => "damage_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => $self->_rowDamage( $slave->{row}, $pm->actorLink( $slave->{key} ) ),
                        type => "slave",
                        name => "damage_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("damage_$id");
            }
        }
    }
    
    ######################
    # DAMAGE OUT TARGETS #
    ######################
    
    {
        my @header = (
            "Target",
            "R-Total",
            "R-Hits",
            "R-Avg Hit",
            "R-Crits",
            "R-Avg Crit",
            "R-Ticks",
            "R-Avg Tick",
            "R-CriCruGla %",
            "MDPBARI %",
        );
        
        # Group by target.
        my @rows = $self->_targetRows( $self->{ext}{Damage}, 0, @playpet );
        
        # Sort @rows.
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Damage Out by Target", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => $self->_rowDamage( $row->{row}, $pm->actorLink( $row->{key} ), "Target" ),
                    type => "master",
                    name => "dmgout_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    # Decode spell name
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($slave->{key}, $pm, @PLAYER);
                    
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => $self->_rowDamage( $slave->{row}, $spellname, "Target" ),
                        type => "slave",
                        name => "dmgout_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("dmgout_$id");
            }
        }
    }
    
    #####################
    # DAMAGE IN SOURCES #
    #####################
    
    {
        my @header = (
            "Source",
            "R-Total",
            "R-Hits",
            "R-Avg Hit",
            "R-Crits",
            "R-Avg Crit",
            "R-Ticks",
            "R-Avg Tick",
            "R-CriCruGla %",
            "MDPBARI %",
        );
        
        # Group by source.
        my @rows = $self->_targetRows( $self->{ext}{Damage}, 1, @playpet );
        
        # Sort @rows.
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Damage In by Source", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => $self->_rowDamage( $row->{row}, $pm->actorLink( $row->{key} ), "Source" ),
                    type => "master",
                    name => "dmgin_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    # Decode spell name
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($slave->{key}, $pm, @PLAYER);
                    
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => $self->_rowDamage( $slave->{row}, $spellname, "Source" ),
                        type => "slave",
                        name => "dmgin_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("dmgin_$id");
            }
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;    
    
    $PAGE .= $pm->tabStart("Healing");
    $PAGE .= $pm->tableStart;
    
    ###########
    # HEALING #
    ###########
    
    {
        my @header = (
            "Ability",
            "R-Eff. Heal",
            "R-Hits",
            "R-Avg Hit",
            "R-Crits",
            "R-Avg Crit",
            "R-Ticks",
            "R-Avg Tick",
            "R-Crit %",
            "R-Overheal %",
        );
        
        # Group by ability.
        my @rows = $self->_abilityRows( $self->{ext}{Healing}, @playpet );
        
        # Sort @rows.
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Healing Out by Ability", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Decode spell name
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($row->{key}, $pm, @PLAYER);
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => $self->_rowHealing( $row->{row}, $spellname ),
                    type => "master",
                    name => "healing_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => $self->_rowHealing( $slave->{row}, $pm->actorLink( $slave->{key} ) ),
                        type => "slave",
                        name => "healing_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("healing_$id");
            }
        }
    }
    
    #######################
    # HEALING OUT TARGETS #
    #######################
    
    {
        my @header = (
            "Target",
            "R-Eff. Heal",
            "R-Count",
            "R-Eff. Out %",
            "R-Overheal %",
        );
        
        # Group by target.
        my @rows = $self->_targetRows( $self->{ext}{Healing}, 0, @playpet );
        
        # Sum up all effective healing.
        my $eff_on_others;
        
        # Sort @rows.
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
            $eff_on_others += $row->{row}{effective};
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Healing Out by Target", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Target" => $pm->actorLink( $row->{key} ),
                        "R-Eff. Heal" => $row->{row}{effective},
                        "R-Count" => $row->{row}{count},
                        "R-Overheal %" => $row->{row}{total} && sprintf( "%0.1f%%", ( $row->{row}{total} - $row->{row}{effective} ) / $row->{row}{total} * 100 ),
                        "R-Eff. Out %" => $eff_on_others && sprintf( "%0.1f%%", $row->{row}{effective} / $eff_on_others * 100 ),
                    },
                    type => "master",
                    name => "healout_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    # Decode spell name
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($slave->{key}, $pm, $MOB);
                    
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Target" => $spellname,
                            "R-Eff. Heal" => $slave->{row}{effective},
                            "R-Count" => $slave->{row}{count},
                            "R-Overheal %" => $slave->{row}{total} && sprintf( "%0.1f%%", ( $slave->{row}{total} - $slave->{row}{effective} ) / $slave->{row}{total} * 100 ),
                            "R-Eff. Out %" => $row->{row}{total} && sprintf( "%0.1f%%", $slave->{row}{effective} / $row->{row}{total} * 100 ),
                        },
                        type => "slave",
                        name => "healout_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("healout_$id");
            }
        }
    }
    
    ######################
    # HEALING IN SOURCES #
    ######################
    
    {
        my @header = (
            "Source",
            "R-Eff. Heal",
            "R-Count",
            "R-Eff. In %",
            "R-Overheal %",
        );
        
        # Group by source.
        my @rows = $self->_targetRows( $self->{ext}{Healing}, 1, @playpet );
        
        # Sum up all effective healing.
        my $eff_on_me;
        
        # Sort @rows.
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ];
            $eff_on_me += $row->{row}{effective};
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Healing In by Source", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Source" => $pm->actorLink( $row->{key} ),
                        "R-Eff. Heal" => $row->{row}{effective},
                        "R-Count" => $row->{row}{count},
                        "R-Overheal %" => $row->{row}{total} && sprintf( "%0.1f%%", ( $row->{row}{total} - $row->{row}{effective} ) / $row->{row}{total} * 100 ),
                        "R-Eff. In %" => $eff_on_me && sprintf( "%0.1f%%", $row->{row}{effective} / $eff_on_me * 100 ),
                    },
                    type => "master",
                    name => "healin_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Source" => $pm->spellLink( $slave->{key}, $self->{ext}{Index}->spellname( $slave->{key} ) ),
                            "R-Eff. Heal" => $slave->{row}{effective},
                            "R-Count" => $slave->{row}{count},
                            "R-Overheal %" => $slave->{row}{total} && sprintf( "%0.1f%%", ( $slave->{row}{total} - $slave->{row}{effective} ) / $slave->{row}{total} * 100 ),
                            "R-Eff. In %" => $row->{row}{total} && sprintf( "%0.1f%%", $slave->{row}{effective} / $row->{row}{total} * 100 ),
                        },
                        type => "slave",
                        name => "healin_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("healin_$id");
            }
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    $PAGE .= $pm->tabStart("Casts and Gains");
    $PAGE .= $pm->tableStart;
    
    #########
    # CASTS #
    #########
    
    if( $self->_keyExists( $self->{ext}{Cast}{actors}, @PLAYER ) ) {
        my @header = (
            "Name",
            "R-Targets",
            "R-Casts",
            "",
            "",
            "",
        );
        
        # Group by ability.
        my @rows = $self->_castRows( $self->{ext}{Cast}, @PLAYER );
        
        $PAGE .= $pm->tableHeader("Casts", @header);
        foreach my $row (@rows) {
            my $id = lc $row->{key};
            $id = $pm->tameText($id);

            # Print row.
            $PAGE .= $pm->tableRow( 
                header => \@header,
                data => {
                    "Name" => $pm->spellLink( $row->{key}, $self->{ext}{Index}->spellname($row->{key}) ),
                    "R-Targets" => scalar @{$row->{slaves}},
                    "R-Casts" => $row->{row}{count},
                },
                type => "master",
                name => "cast_$id",
            );
            
            # Slave rows
            foreach my $slave (@{ $row->{slaves} }) {
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Name" => $pm->actorLink( $slave->{key} ),
                        "R-Targets" => "",
                        "R-Casts" => $slave->{row}{count},
                    },
                    type => "slave",
                    name => "cast_$id",
                );
            }
            
            # JavaScript close
            $PAGE .= $pm->jsClose("cast_$id");
        }
    }
    
    #########
    # POWER #
    #########
    
    if( $self->_keyExists( $self->{ext}{Power}{actors}, @PLAYER ) ) {
        my @header = (
            "Name",
            "R-Sources",
            "R-Gained",
            "R-Ticks",
            "R-Avg",
            "R-Per 5",
        );
        
        # Group by ability.
        my @rows = $self->_castRows( $self->{ext}{Power}, @PLAYER );
        
        $PAGE .= $pm->tableHeader("Power Gains", @header);
        foreach my $row (@rows) {
            my $id = lc $row->{key};
            $id = $pm->tameText($id);

            # Print row.
            $PAGE .= $pm->tableRow( 
                header => \@header,
                data => {
                    "Name" => $pm->spellLink( $row->{key}, $self->{ext}{Index}->spellname($row->{key}) . " (" . $row->{row}{type} . ")" ),
                    "R-Sources" => scalar @{$row->{slaves}},
                    "R-Gained" => $row->{row}{amount},
                    "R-Ticks" => $row->{row}{count},
                    "R-Avg" => $row->{row}{count} && sprintf( "%d", $row->{row}{amount} / $row->{row}{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $row->{row}{amount} / $ptime * 5 ),
                },
                type => "master",
                name => "power_$id",
            );
            
            # Slave rows
            foreach my $slave (@{ $row->{slaves} }) {
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Name" => $pm->actorLink( $slave->{key} ),
                        "R-Gained" => $slave->{row}{amount},
                        "R-Ticks" => $slave->{row}{count},
                        "R-Avg" => $slave->{row}{count} && sprintf( "%d", $slave->{row}{amount} / $slave->{row}{count} ),
                        "R-Per 5" => $ptime && sprintf( "%0.1f", $slave->{row}{amount} / $ptime * 5 ),
                    },
                    type => "slave",
                    name => "power_$id",
                );
            }
            
            # JavaScript close
            $PAGE .= $pm->jsClose("power_$id");
        }
    }
    
    #################
    # EXTRA ATTACKS #
    #################
    
    if( $self->_keyExists( $self->{ext}{ExtraAttack}{actors}, @PLAYER ) ) {
        my @header = (
            "Name",
            "R-Sources",
            "R-Gained",
            "R-Ticks",
            "R-Avg",
            "R-Per 5",
        );
        
        # Group by ability.
        my @rows = $self->_castRows( $self->{ext}{ExtraAttack}, @PLAYER );
        
        $PAGE .= $pm->tableHeader("Power Gains", @header) unless $self->_keyExists( $self->{ext}{Power}{actors}, @PLAYER );
        foreach my $row (@rows) {
            my $id = lc $row->{key};
            $id = $pm->tameText($id);

            # Print row.
            $PAGE .= $pm->tableRow( 
                header => \@header,
                data => {
                    "Name" => $pm->spellLink( $row->{key}, $self->{ext}{Index}->spellname($row->{key}) . " (extra attacks)" ),
                    "R-Sources" => scalar @{$row->{slaves}},
                    "R-Gained" => $row->{row}{amount},
                    "R-Ticks" => $row->{row}{count},
                    "R-Avg" => $row->{row}{count} && sprintf( "%d", $row->{row}{amount} / $row->{row}{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $row->{row}{amount} / $ptime * 5 ),
                },
                type => "master",
                name => "ea_$id",
            );
            
            # Slave rows
            foreach my $slave (@{ $row->{slaves} }) {
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Name" => $pm->actorLink( $slave->{key} ),
                        "R-Gained" => $slave->{row}{amount},
                        "R-Ticks" => $slave->{row}{count},
                        "R-Avg" => $slave->{row}{count} && sprintf( "%d", $slave->{row}{amount} / $slave->{row}{count} ),
                        "R-Per 5" => $ptime && sprintf( "%0.1f", $slave->{row}{amount} / $ptime * 5 ),
                    },
                    type => "slave",
                    name => "ea_$id",
                );
            }
            
            # JavaScript close
            $PAGE .= $pm->jsClose("ea_$id");
        }
    }
    
    #########
    # AURAS #
    #########
    
    if( !$do_group && $self->_keyExists( $self->{ext}{Aura}{actors}, @PLAYER ) ) {
        my @auraHeader = (
                "Name",
                "Type",
                "R-Uptime",
                "R-%",
                "R-Gained",
                "R-Faded",
            );

        my @aurasort = sort {
            ($self->{ext}{Aura}{actors}{$MOB}{$a}{type} cmp $self->{ext}{Aura}{actors}{$MOB}{$b}{type}) || ($self->{ext}{Aura}{actors}{$MOB}{$b}{time} <=> $self->{ext}{Aura}{actors}{$MOB}{$a}{time})
        } keys %{$self->{ext}{Aura}{actors}{$MOB}};

        $PAGE .= $pm->tableHeader("Buffs and Debuffs", @auraHeader);
        foreach my $auraid (@aurasort) {
            my $id = lc $auraid;
            $id = $pm->tameText($id);

            my $sdata;
            $sdata = $self->{ext}{Aura}{actors}{$MOB}{$auraid};
            $PAGE .= $pm->tableRow( 
                header => \@auraHeader,
                data => {
                    "Name" => $pm->spellLink( $auraid, $self->{ext}{Index}->spellname($auraid) ),
                    "Type" => ($sdata->{type} && lc $sdata->{type}) || "unknown",
                    "R-Gained" => $sdata->{gains},
                    "R-Faded" => $sdata->{fades},
                    "R-%" => $ptime && sprintf( "%0.1f%%", $sdata->{time} / $ptime * 100 ),
                    "R-Uptime" => $sdata->{time} && sprintf( "%02d:%02d", $sdata->{time}/60, $sdata->{time}%60 ),
                },
                type => "",
                name => "aura_$id",
            );
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    ##########
    # DEATHS #
    ##########

    if( $self->_keyExists( $self->{ext}{Death}{actors}, @PLAYER ) ) {
        my @header = (
                "Death Time",
                "R-Health",
                "Event",
            );

        # Loop through all deaths.
        my $id = 0;
        foreach my $player (@PLAYER) {
            foreach my $death (@{$self->{ext}{Death}{actors}{$player}}) {
                if( !$id ) {
                    $PAGE .= $pm->tabStart("Deaths");
                    $PAGE .= $pm->tableStart;
                    $PAGE .= $pm->tableHeader("Deaths", @header);
                }
                
                $id++;

                # Get the last line of the autopsy.
                my $lastline = pop @{$death->{autopsy}};
                push @{$death->{autopsy}}, $lastline;

                # Print the front row.
                my $t = $death->{t} - $raidStart;
                $PAGE .= $pm->tableRow(
                        header => \@header,
                        data => {
                            "Death Time" => $death->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                            "R-Health" => $lastline->{hp} || "",
                            "Event" => $lastline->{text} || "",
                        },
                        type => "master",
                        name => "death_$id",
                    );

                # Print subsequent rows.
                foreach my $line (@{$death->{autopsy}}) {
                    my $t = ($line->{t}||0) - $raidStart;

                    $PAGE .= $pm->tableRow(
                            header => \@header,
                            data => {
                                "Death Time" => $line->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                                "R-Health" => $line->{hp} || "",
                                "Event" => $line->{text} || "",
                            },
                            type => "slave",
                            name => "death_$id",
                        );
                }

                $PAGE .= $pm->jsClose("death_$id");
            }
        }

        if( $id ) {
            $PAGE .= $pm->tableEnd;
            $PAGE .= $pm->tabEnd;
        }
    }
    
    $PAGE .= $pm->jsTab("damage");
    $PAGE .= $pm->tabBarEnd;
    
    ##########
    # FOOTER #
    ##########
    
    $PAGE .= $pm->pageFooter;
}

sub _decodespell {
    my $self = shift;
    my $encoded_spellid = shift;
    my $pm = shift;
    my @PLAYER = @_;
    
    my $spellactor;
    my $spellname;
    my $spellid;

    if( $encoded_spellid =~ /^([A-Za-z0-9]+): (.+)$/ ) {
        if( ! grep $_ eq $1, @PLAYER ) {
            $spellactor = $1;
            $spellname = sprintf( "%s: %s", $pm->actorLink( $1 ), $pm->spellLink( $2, $self->{ext}{Index}->spellname($2) ) );
            $spellid = $2;
        } else {
            $spellactor = $1;
            $spellname = $pm->spellLink( $2, $self->{ext}{Index}->spellname($2) );
            $spellid = $2;
        }
    } else {
        $spellactor = $PLAYER[0];
        $spellname = $pm->spellLink( $encoded_spellid, $self->{ext}{Index}->spellname($encoded_spellid) );
        $spellid = $encoded_spellid;
    }
    
    return ($spellactor, $spellname, $spellid);
}

sub _tidypct {
    my ($self,$n) = @_;
    
    if( floor($n) == $n ) {
        return sprintf "%d", $n;
    } else {
        return sprintf "%0.1f", $n;
    }
}

sub _targetRows {
    my $self = shift;
    my $ext = shift;
    my $in = shift;
    
    my $group = $self->{grouper}->group($_[0]);
    my @GROUP = $group ? @{$group->{members}} : ($_[0]);
    
    # Group by target.
    my @rows;
    
    while( my ($kactor, $vactor) = each(%{ $ext->{actors}}) ) {
        # If we're doing an out (!$in) then skip other actors.
        next if !$in && !grep $_ eq $kactor, @_;
        
        # Figure out what the key for this actor is.
        my $gactor = $self->{grouper}->group($kactor);
        my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;
        
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Figure out what the key for this spell is.
            my $espell = $in ? $kspell : "$kactor_use: $kspell";
            
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # If we're coming in then skip other actors.
                next if $in && !grep $_ eq $ktarget, @GROUP;
                
                # Figure out the key for this target.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;
                
                # Key
                my $key = $in ? $kactor_use : $ktarget_use;
                
                # Figure out which row to add this to, or create a new one if appropriate.
                my $row;
                
                foreach (@rows) {
                    if( $_->{key} eq $key ) {
                        $row = $_;
                        last;
                    }
                }
                
                if( $row ) {
                    # Add to an existing row.
                    $self->_sum( $row->{row}, $vtarget );
                    
                    # Either add to an existing slave, or create a new one.
                    my $slave;
                    foreach (@{$row->{slaves}}) {
                        if( $_->{key} eq $espell ) {
                            $slave = $_;
                            last;
                        }
                    }
                    
                    if( $slave ) {
                        # Add to an existing slave.
                        $self->_sum( $slave->{row}, $vtarget );
                    } else {
                        # Create a new slave.
                        push @{$row->{slaves}}, {
                            key => $espell,
                            row => $self->_copy( $vtarget ),
                        }
                    }
                } else {
                    # Create a new row.
                    push @rows, {
                        key => $key,
                        row => $self->_copy( $vtarget ),
                        slaves => [
                            {
                                key => $espell,
                                row => $self->_copy( $vtarget ),
                            }
                        ]
                    }
                }
            }
        }
    }
    
    return @rows;
}

sub _abilityRows {
    my $self = shift;
    my $ext = shift;
    
    # Group by ability.
    my @rows;
    
    foreach my $kactor (@_) {
        while( my ($kspell, $vspell) = each(%{ $ext->{actors}{$kactor} } ) ) {
            # Encoded spell name.
            my $gactor = $self->{grouper}->group($kactor);
            my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;
            
            my $espell = "$kactor_use: $kspell";
            
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;
                
                # Figure out which row to add this to, or create a new one if appropriate.
                my $row;
                
                foreach (@rows) {
                    if( $_->{key} eq $espell ) {
                        $row = $_;
                        last;
                    }
                }
                
                if( $row ) {
                    # Add to an existing row.
                    $self->_sum( $row->{row}, $vtarget );
                    
                    # Either add to an existing slave, or create a new one.
                    my $slave;
                    foreach (@{$row->{slaves}}) {
                        if( $_->{key} eq $ktarget_use ) {
                            $slave = $_;
                            last;
                        }
                    }
                    
                    if( $slave ) {
                        # Add to an existing slave.
                        $self->_sum( $slave->{row}, $vtarget );
                    } else {
                        # Create a new slave.
                        push @{$row->{slaves}}, {
                            key => $ktarget_use,
                            row => $self->_copy( $vtarget ),
                        }
                    }
                } else {
                    # Create a new row.
                    push @rows, {
                        key => $espell,
                        row => $self->_copy( $vtarget ),
                        slaves => [
                            {
                                key => $ktarget_use,
                                row => $self->_copy( $vtarget ),
                            }
                        ]
                    }
                }
            }
        }
    }
    
    return @rows;
}

sub _castRows {
    my $self = shift;
    my $ext = shift;

    my @rows;
    
    foreach my $kactor (@_) {
        while( my ($kspell, $vspell) = each(%{ $ext->{actors}{$kactor} } ) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;

                # Figure out which row to add this to, or create a new one if appropriate.
                my $row;

                foreach (@rows) {
                    if( $_->{key} eq $kspell ) {
                        $row = $_;
                        last;
                    }
                }
            
                if( $row ) {
                    # Add to an existing row.
                    $row->{row}{amount} += $vtarget->{amount} if $vtarget->{amount};
                    $row->{row}{count} += $vtarget->{count} if $vtarget->{count};
                
                    # Either add to an existing slave, or create a new one.
                    my $slave;
                    foreach (@{$row->{slaves}}) {
                        if( $_->{key} eq $ktarget_use ) {
                            $slave = $_;
                            last;
                        }
                    }
                
                    if( $slave ) {
                        # Add to an existing slave.
                        $slave->{row}{amount} += $vtarget->{amount} if $vtarget->{amount};
                        $slave->{row}{count} += $vtarget->{count} if $vtarget->{count};
                    } else {
                        # Create a new slave.
                        push @{$row->{slaves}}, {
                            key => $ktarget_use,
                            row => $self->_copy($vtarget),
                        }
                    }
                } else {
                    # Create a new row.
                    push @rows, {
                        key => $kspell,
                        row => $self->_copy($vtarget),
                        slaves => [
                            {
                                key => $ktarget_use,
                                row => $self->_copy($vtarget),
                            }
                        ],
                    }
                }
            }
        }
    }
    
    # Sort @rows.
    @rows = sort { $b->{row}{count} <=> $a->{row}{count} } @rows;
    
    # Sort slaves.
    foreach my $row (@rows) {
        $row->{slaves} = [ sort { $b->{row}{count} <=> $a->{row}{count} } @{$row->{slaves}} ]; 
    }
    
    return @rows;
}

sub _rowDamage {
    my $self = shift;
    my $sdata = shift;
    my $title = shift;
    my $header = shift;
    
    # We're printing a row based on $sdata.
    my $swings = ($sdata->{count} - $sdata->{tickCount});
    
    return {
        ($header || "Ability") => $title,
        "R-Total" => $sdata->{total},
        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
        "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{hitMin}, $sdata->{hitMax}, $sdata->{hitTotal} / $sdata->{hitCount} ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{tickMin}, $sdata->{tickMax}, $sdata->{tickTotal} / $sdata->{tickCount} ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{critMin}, $sdata->{critMax}, $sdata->{critTotal} / $sdata->{critCount} ),
        "R-CriCruGla %" => $swings && sprintf( "%s/%s/%s", $self->_tidypct( $sdata->{critCount} / $swings * 100 ), $self->_tidypct( $sdata->{crushing} / $swings * 100 ), $self->_tidypct( $sdata->{glancing} / $swings * 100 ) ),
        "MDPBARI %" => $swings && sprintf( "%s/%s/%s/%s/%s/%s/%s", $self->_tidypct( $sdata->{missCount} / $swings * 100 ), $self->_tidypct( $sdata->{dodgeCount} / $swings * 100 ), $self->_tidypct( $sdata->{parryCount} / $swings * 100 ), $self->_tidypct( $sdata->{blockCount} / $swings * 100 ), $self->_tidypct( $sdata->{absorbCount} / $swings * 100 ), $self->_tidypct( $sdata->{resistCount} / $swings * 100 ), $self->_tidypct( $sdata->{immuneCount} / $swings * 100 ) ),
    };
}

sub _rowHealing {
    my $self = shift;
    my $sdata = shift;
    my $title = shift;
    
    # We're printing a row based on $sdata.
    
    return {
        "Ability" => $title,
        "R-Eff. Heal" => $sdata->{effective},
        "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ($sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100 : "",
        "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{hitMin}, $sdata->{hitMax}, $sdata->{hitTotal} / $sdata->{hitCount} ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{tickMin}, $sdata->{tickMax}, $sdata->{tickTotal} / $sdata->{tickCount} ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{critMin}, $sdata->{critMax}, $sdata->{critTotal} / $sdata->{critCount} ),
        "R-Crit %" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
    };
}

sub _sum {
    my $self = shift;
    my $sd1 = shift;
    
    # Merge the rest of @_ into $sd1.
    foreach my $sd2 (@_) {
        while( my ($key, $val) = each (%$sd2) ) {
            $sd1->{$key} ||= 0;
            
            if( $key =~ /([Mm]in|[Mm]ax)$/ ) {
                # Minimum or maximum
                if( lc $1 eq "min" && (!$sd1->{$key} || $val < $sd1->{$key}) ) {
                    $sd1->{$key} = $val;
                } elsif( lc $1 eq "max" && (!$sd1->{$key} || $val > $sd1->{$key}) ) {
                    $sd1->{$key} = $val;
                }
            } else {
                # Total
                $sd1->{$key} += $val;
            }
        }
    }
    
    # Return $sd1.
    return $sd1;
}

sub _copy {
    my $self = shift;
    my $ref = shift;
    
    # Shallow copy hashref $ref into $copy.
    my %copy;
    while( my ($key, $val) = each (%$ref) ) {
        $copy{$key} = $val;
    }
    
    return \%copy;
}

sub _keyExists {
    my $self = shift;
    my $ext = shift;
    my @PLAYER = @_;
    
    foreach (@PLAYER) {
        if( exists $ext->{$_} ) {
            return 1;
        }
    }
    
    return 0;
}

1;
