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
    
    # Player and pets
    my @playpet = ( $PLAYER );
    push @playpet, @{$self->{raid}{$PLAYER}{pets}} if( exists $self->{raid}{$PLAYER} && exists $self->{raid}{$PLAYER}{pets} );
    
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
    
    $PAGE .= $pm->pageHeader($self->{name}, $raidStart);
    $PAGE .= sprintf "<h3 class=\"color%s\">%s</h3>", $self->{raid}{$PLAYER}{class} || "Mob", HTML::Entities::encode_entities($self->{ext}{Index}->actorname($PLAYER));
    
    my $ptime = $PLAYER && ($self->{ext}{Presence}{actors}{$PLAYER}{end} - $self->{ext}{Presence}{actors}{$PLAYER}{start});
    my $presence_text = sprintf( "Presence: %02d:%02d", $ptime/60, $ptime%60 );
    $presence_text .= sprintf( "<br />DPS time: %02d:%02d (%0.1f%% of presence), %d DPS", 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}/60, 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}%60, 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}/$ptime*100, 
        $dmg_to_mobs/$self->{ext}{Activity}{actors}{$PLAYER}{all}{time} ) 
            if $ptime && $dmg_to_mobs && $self->{ext}{Activity}{actors}{$PLAYER} && $self->{ext}{Activity}{actors}{$PLAYER}{all}{time};
    
    my ($atype, $anpc, $aspawn ) = Stasis::MobUtil->splitguid( $PLAYER );
    if( ($atype & 0x00F0) == 0x30 ) {
        $presence_text .= sprintf( "<br />Wowhead: <a href=\"http://www.wowhead.com/?npc=%s\" target=\"swswhnpc_%s\">%s</a>", $anpc, $anpc, HTML::Entities::encode_entities($self->{ext}{Index}->actorname($PLAYER)) );
    }
    
    $PAGE .= $pm->textBox( $presence_text, "Actor Information" );
    
    $PAGE .= "<br />";
    
    ##########
    # DAMAGE #
    ##########
    
    $PAGE .= $pm->tableStart;
    
    {
        my @header = (
            "Damaging Ability",
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
        my @rows;
        
        foreach my $kactor (@playpet) {
            while( my ($kspell, $vspell) = each(%{ $self->{ext}{Damage}{actors}{$kactor} } ) ) {
                # Encoded spell name.
                my $espell = "$kactor: $kspell";
                
                # Spell hash for this ability.
                my %row;
                
                # Spell hashes for subrows (array of hashrefs to spell hashes).
                my @slaves;
                
                # Targets.
                while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                    # $vtarget is a spell hash.
                    $self->_sum( \%row, $vtarget );
                    push @slaves, {
                        key => $ktarget,
                        row => $vtarget,
                    } if $vtarget->{count};
                }
                
                # Add the row and its slaves to the main list.
                push @rows, {
                    key => $espell,
                    row => \%row,
                    slaves => \@slaves,
                };
            }
        }
        
        # Sort @rows.
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Decode spell name
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($row->{key}, $pm, $PLAYER);
                
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
                        data => $self->_rowDamage( $slave->{row}, $pm->actorLink( $slave->{key}, $self->{ext}{Index}->actorname($slave->{key}), $self->{raid}{$slave->{key}} && $self->{raid}{$slave->{key}}{class} ) ),
                        type => "slave",
                        name => "damage_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("damage_$id");
            }
        }
    }
    
    ###########
    # HEALING #
    ###########
    
    {
        my @header = (
            "Healing Ability",
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
        my @rows;
        
        foreach my $kactor (@playpet) {
            while( my ($kspell, $vspell) = each(%{ $self->{ext}{Healing}{actors}{$kactor} } ) ) {
                # Encoded spell name.
                my $espell = "$kactor: $kspell";
                
                # Spell hash for this ability.
                my %row;
                
                # Spell hashes for subrows (array of hashrefs to spell hashes).
                my @slaves;
                
                # Targets.
                while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                    # $vtarget is a spell hash.
                    $self->_sum( \%row, $vtarget );
                    push @slaves, {
                        key => $ktarget,
                        row => $vtarget,
                    } if $vtarget->{count};
                }
                
                # Add the row and its slaves to the main list.
                push @rows, {
                    key => $espell,
                    row => \%row,
                    slaves => \@slaves,
                };
            }
        }
        
        # Sort @rows.
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Decode spell name
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($row->{key}, $pm, $PLAYER);
                
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
                        data => $self->_rowHealing( $slave->{row}, $pm->actorLink( $slave->{key}, $self->{ext}{Index}->actorname($slave->{key}), $self->{raid}{$slave->{key}} && $self->{raid}{$slave->{key}}{class} ) ),
                        type => "slave",
                        name => "healing_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("healing_$id");
            }
        }
    }
    
    $PAGE .= $pm->tableEnd;
    
    ##########
    # DEATHS #
    ##########

    if( exists $self->{ext}{Death}{actors}{$PLAYER} ) {
        $PAGE .= $pm->tableStart;

        my @header = (
                "Death Time",
                "R-Health",
                "Event",
            );

        $PAGE .= $pm->tableHeader(@header);

        # Loop through all deaths.
        foreach my $death (@{$self->{ext}{Death}{actors}{$PLAYER}}) {
            my $id = $death->{t};
            $id = $pm->tameText($id);

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

        $PAGE .= $pm->tableEnd;
    }
    
    #########
    # CASTS #
    #########
    
    $PAGE .= $pm->tableStart;
    
    if( exists $self->{ext}{Cast}{actors}{$PLAYER} ) {
        my @castHeader = (
                "Cast Name",
                "Target-W",
                "R-Total",
                "",
                "",
                "",
            );
        
        $PAGE .= $pm->tableHeader(@castHeader);
        foreach my $spellid (keys %{$self->{ext}{Cast}{actors}{$PLAYER}}) {
            my $id = lc $spellid;
            $id = $pm->tameText($id);
            
            # Get a count of total casts.
            my $total_casts = 0;
            foreach (values %{$self->{ext}{Cast}{actors}{$PLAYER}{$spellid}}) {
                $total_casts += $_;
            }

            my $sdata;
            $PAGE .= $pm->tableRow( 
                header => \@castHeader,
                data => {
                    "Cast Name" => $pm->spellLink( $spellid, $self->{ext}{Index}->spellname($spellid) ),
                    "R-Total" => $total_casts,
                    "Target-W" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $self->{raid}{$_}{class} ), keys %{ $self->{ext}{Cast}{actors}{$PLAYER}{$spellid} } ),
                },
                type => "",
                name => "cast_$id",
            );
        }
    }
    
    #########
    # POWER #
    #########
    
    if( exists $self->{ext}{Power}{actors}{$PLAYER} ) {
        my @powerHeader = (
                "Gain Name",
                "Source-W",
                "R-Total",
                "R-Ticks",
                "R-Avg",
                "R-Per 5",
            );
        
        # Build a list of power gains without the per-source splitting.
        my %powtot;
        while( my ($pname, $psources) = each(%{$self->{ext}{Power}{actors}{$PLAYER}}) ) {
            while( my ($sname, $sdata) = each %$psources ) {
                $powtot{$pname}{type} ||= $sdata->{type};
                $powtot{$pname}{amount} += $sdata->{amount};
                $powtot{$pname}{count} += $sdata->{count};
            }
        }
        
        my @powersort = sort {
            ($powtot{$a}{type} cmp $powtot{$b}{type}) || ($powtot{$b}{amount} <=> $powtot{$a}{amount})
        } keys %powtot;
        
        $PAGE .= $pm->tableHeader(@powerHeader);
        foreach my $powerid (@powersort) {
            my $id = lc $powerid;
            $id = $pm->tameText($id);

            my $sdata;
            $sdata = $powtot{$powerid};
            $PAGE .= $pm->tableRow( 
                header => \@powerHeader,
                data => {
                    "Gain Name" => $pm->spellLink( $powerid, sprintf( "%s (%s)", $self->{ext}{Index}->spellname($powerid), $sdata->{type} ) ),
                    "R-Total" => $sdata->{amount},
                    "Source-W" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $self->{raid}{$_}{class} ), keys %{ $self->{ext}{Power}{actors}{$PLAYER}{$powerid} } ),
                    "R-Ticks" => $sdata->{count},
                    "R-Avg" => $sdata->{count} && sprintf( "%d", $sdata->{amount} / $sdata->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $sdata->{amount} / $ptime * 5 ),
                },
                type => "",
                name => "power_$id",
            );
        }
    }
    
    #################
    # EXTRA ATTACKS #
    #################
    
    if( exists $self->{ext}{ExtraAttack}{actors}{$PLAYER} ) {
        my @powerHeader = (
                "Gain Name",
                "Source-W",
                "R-Total",
                "R-Ticks",
                "R-Avg",
                "R-Per 5",
            );
        
        # Build a list of extra attacks without the per-source splitting.
        my %powtot;
        while( my ($pname, $psources) = each(%{$self->{ext}{ExtraAttack}{actors}{$PLAYER}}) ) {
            while( my ($sname, $sdata) = each %$psources ) {
                $powtot{$pname}{type} = "extra attacks";
                $powtot{$pname}{amount} += $sdata->{amount};
                $powtot{$pname}{count} += $sdata->{count};
            }
        }
        
        my @powersort = sort {
            ($powtot{$a}{type} cmp $powtot{$b}{type}) || ($powtot{$b}{amount} <=> $powtot{$a}{amount})
        } keys %powtot;
        
        $PAGE .= $pm->tableHeader(@powerHeader) unless exists $self->{ext}{Power}{actors}{$PLAYER};
        foreach my $powerid (@powersort) {
            my $id = lc $powerid;
            $id = $pm->tameText($id);

            my $sdata;
            $sdata = $powtot{$powerid};
            $PAGE .= $pm->tableRow( 
                header => \@powerHeader,
                data => {
                    "Gain Name" => $pm->spellLink( $powerid, sprintf( "%s (%s)", $self->{ext}{Index}->spellname($powerid), $sdata->{type} ) ),
                    "R-Total" => $sdata->{amount},
                    "Source-W" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $self->{raid}{$_}{class} ), keys %{ $self->{ext}{ExtraAttack}{actors}{$PLAYER}{$powerid} } ),
                    "R-Ticks" => $sdata->{count},
                    "R-Avg" => $sdata->{count} && sprintf( "%d", $sdata->{amount} / $sdata->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $sdata->{amount} / $ptime * 5 ),
                },
                type => "",
                name => "power_$id",
            );
        }
    }
    
    #########
    # AURAS #
    #########
    
    if( exists $self->{ext}{Aura}{actors}{$PLAYER} ) {
        my @auraHeader = (
                "Aura Name",
                "Type",
                "R-Uptime",
                "R-%",
                "R-Gained",
                "R-Faded",
            );

        my @aurasort = sort {
            ($self->{ext}{Aura}{actors}{$PLAYER}{$a}{type} cmp $self->{ext}{Aura}{actors}{$PLAYER}{$b}{type}) || ($self->{ext}{Aura}{actors}{$PLAYER}{$b}{time} <=> $self->{ext}{Aura}{actors}{$PLAYER}{$a}{time})
        } keys %{$self->{ext}{Aura}{actors}{$PLAYER}};

        $PAGE .= $pm->tableHeader(@auraHeader);
        foreach my $auraid (@aurasort) {
            my $id = lc $auraid;
            $id = $pm->tameText($id);

            my $sdata;
            $sdata = $self->{ext}{Aura}{actors}{$PLAYER}{$auraid};
            $PAGE .= $pm->tableRow( 
                header => \@auraHeader,
                data => {
                    "Aura Name" => $pm->spellLink( $auraid, $self->{ext}{Index}->spellname($auraid) ),
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
    
    $PAGE .= $pm->tableStart;

    ######################
    # DAMAGE OUT TARGETS #
    ######################
    
    {
        my @header = (
            "Damage Out",
            "R-Total",
            "R-DPS",
            "Time",
            "R-Time % (Presence)",
            "R-Time % (DPS Time)",
        );
        
        # Group by target.
        my @rows;
        
        foreach my $kactor (@playpet) {
            while( my ($kspell, $vspell) = each(%{ $self->{ext}{Damage}{actors}{$kactor} } ) ) {
                # Encoded spell name.
                my $espell = "$kactor: $kspell";
                
                # Targets.
                while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                    # Reference to the hash for this target found?
                    my $found;
                    
                    # See if this should properly be added to an existing target.
                    foreach my $row (@rows) {
                        if( $row->{key} eq $ktarget ) {
                            # It exists. Add this data to the existing master row.
                            $self->_sum( $row->{row}, $vtarget );
                            push @{$row->{slaves}}, { key => $espell, row => $vtarget };
                            
                            $found = 1;
                            last;
                        }
                    }
                    
                    if( !$found ) {
                        # It did not exist. Create a new master row.
                        push @rows, {
                            key => $ktarget,
                            row => $self->_copy($vtarget),
                            slaves => [ { key => $espell, row => $vtarget, } ],
                        };
                    }
                }
            }
        }
        
        # Sort @rows.
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                my $dpstime_target = $self->{ext}{Activity}{actors}{$PLAYER}{targets}{ $row->{key} }{time};
                my $dpstime_all = $self->{ext}{Activity}{actors}{$PLAYER}{all}{time};
                
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Damage Out" => $pm->actorLink( $row->{key}, $self->{ext}{Index}->actorname($row->{key}), $self->{raid}{$row->{key}} && $self->{raid}{$row->{key}}{class} ),
                        "R-Total" => $row->{row}{total},
                        "R-DPS" => $dpstime_target && sprintf( "%d", $row->{row}{total} / $dpstime_target ),
                        "Time" => $dpstime_target && sprintf( "%02d:%02d", $dpstime_target/60, $dpstime_target%60 ),
                        "R-Time % (Presence)" => $dpstime_target && $ptime && sprintf( "%0.1f%%", $dpstime_target / $ptime * 100 ),
                        "R-Time % (DPS Time)" => $dpstime_target && $dpstime_all && sprintf( "%0.1f%%", $dpstime_target / $dpstime_all * 100 ),
                    },
                    type => "master",
                    name => "dmgout_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    # Decode spell name
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($slave->{key}, $pm, $PLAYER);
                    
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Damage Out" => $spellname,
                            "R-Total" => $slave->{row}{total},
                        },
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
            "Damage In",
            "R-Total",
            "R-DPS",
            "Time",
            "R-Time % (Presence)",
            "R-Time % (DPS Time)",
        );
        
        # Group by source.
        my @rows;
        
        while( my ($kactor, $vactor) = each(%{$self->{ext}{Damage}{actors}}) ) {
            while( my ($kspell, $vspell) = each(%$vactor ) ) {
                # Only look at damage on us.
                next unless exists $vspell->{$PLAYER};
                
                # Reference to the hash for this source found?
                my $found;
                
                # See if this should properly be added to an existing source.
                foreach my $row (@rows) {
                    if( $row->{key} eq $kactor ) {
                        # It exists. Add this data to the existing master row.
                        $self->_sum( $row->{row}, $vspell->{$PLAYER} );
                        push @{$row->{slaves}}, { key => $kspell, row => $vspell->{$PLAYER} };
                        
                        $found = 1;
                        last;
                    }
                }
                
                if( !$found ) {
                    # It did not exist. Create a new master row.
                    push @rows, {
                        key => $kactor,
                        row => $self->_copy($vspell->{$PLAYER}),
                        slaves => [ { key => $kspell, row => $vspell->{$PLAYER}, } ],
                    };
                }
            }
        }
        
        # Sort @rows.
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                my $dpstime_target = $self->{ext}{Activity}{actors}{$row->{key}}{targets}{$PLAYER}{time};
                my $dpstime_all = $self->{ext}{Activity}{actors}{$row->{key}}{all}{time};
                my $source_ptime = $self->{ext}{Presence}->presence( $row->{key} );
                
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Damage In" => $pm->actorLink( $row->{key}, $self->{ext}{Index}->actorname($row->{key}), $self->{raid}{$row->{key}} && $self->{raid}{$row->{key}}{class} ),
                        "R-Total" => $row->{row}{total},
                        "R-DPS" => $dpstime_target && sprintf( "%d", $row->{row}{total} / $dpstime_target ),
                        "Time" => $dpstime_target && sprintf( "%02d:%02d", $dpstime_target/60, $dpstime_target%60 ),
                        "R-Time % (Presence)" => $dpstime_target && $source_ptime && sprintf( "%0.1f%%", $dpstime_target / $source_ptime * 100 ),
                        "R-Time % (DPS Time)" => $dpstime_target && $dpstime_all && sprintf( "%0.1f%%", $dpstime_target / $dpstime_all * 100 ),
                        
                    },
                    type => "master",
                    name => "dmgin_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Damage In" => $pm->spellLink( $slave->{key}, $self->{ext}{Index}->spellname( $slave->{key} ) ),
                            "R-Total" => $slave->{row}{total},
                        },
                        type => "slave",
                        name => "dmgin_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("dmgin_$id");
            }
        }
    }
    
    #######################
    # HEALING OUT TARGETS #
    #######################
    
    {
        my @header = (
            "Heals Out",
            "R-Eff. Heal",
            "R-Hits",
            "R-Eff. Out %",
            "R-Overheal %",
            "",
        );
        
        # Group by target.
        my @rows;
        
        # Sum up all effective healing.
        my $eff_on_others;
        
        foreach my $kactor (@playpet) {
            while( my ($kspell, $vspell) = each( %{$self->{ext}{Healing}{actors}{$kactor}} ) ) {
                # Encoded spell name.
                my $espell = "$kactor: $kspell";
                
                while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                    # Add to eff_on_others.
                    $eff_on_others += $vtarget->{effective};

                    # Reference to the hash for this target found?
                    my $found;

                    # See if this should properly be added to an existing target.
                    foreach my $row (@rows) {
                        if( $row->{key} eq $ktarget ) {
                            # It exists. Add this data to the existing master row.
                            $self->_sum( $row->{row}, $vtarget );
                            push @{$row->{slaves}}, { key => $espell, row => $vtarget };

                            $found = 1;
                            last;
                        }
                    }

                    if( !$found ) {
                        # It did not exist. Create a new master row.
                        push @rows, {
                            key => $ktarget,
                            row => $self->_copy($vtarget),
                            slaves => [ { key => $espell, row => $vtarget } ],
                        };
                    }
                }
            }
        }
        
        # Sort @rows.
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Heals Out" => $pm->actorLink( $row->{key}, $self->{ext}{Index}->actorname($row->{key}), $self->{raid}{$row->{key}} && $self->{raid}{$row->{key}}{class} ),
                        "R-Eff. Heal" => $row->{row}{effective},
                        "R-Hits" => $row->{row}{count},
                        "R-Overheal %" => $row->{row}{total} && sprintf( "%0.1f%%", ( $row->{row}{total} - $row->{row}{effective} ) / $row->{row}{total} * 100 ),
                        "R-Eff. Out %" => $eff_on_others && sprintf( "%0.1f%%", $row->{row}{effective} / $eff_on_others * 100 ),
                    },
                    type => "master",
                    name => "healout_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    # Decode spell name
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($slave->{key}, $pm, $PLAYER);
                    
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Heals Out" => $spellname,
                            "R-Eff. Heal" => $slave->{row}{effective},
                            "R-Hits" => $slave->{row}{count},
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
            "Heals In",
            "R-Eff. Heal",
            "R-Hits",
            "R-Eff. In %",
            "R-Overheal %",
            "",
        );
        
        # Group by source.
        my @rows;
        
        # Sum up all effective healing.
        my $eff_on_me;
        
        while( my ($kactor, $vactor) = each(%{$self->{ext}{Healing}{actors}}) ) {
            while( my ($kspell, $vspell) = each(%$vactor ) ) {
                # Only look at heals on us.
                next unless exists $vspell->{$PLAYER};
                
                # Add to eff_on_me.
                $eff_on_me += $vspell->{$PLAYER}{effective};
                
                # Reference to the hash for this source found?
                my $found;
                
                # See if this should properly be added to an existing source.
                foreach my $row (@rows) {
                    if( $row->{key} eq $kactor ) {
                        # It exists. Add this data to the existing master row.
                        $self->_sum( $row->{row}, $vspell->{$PLAYER} );
                        push @{$row->{slaves}}, { key => $kspell, row => $vspell->{$PLAYER} };
                        
                        $found = 1;
                        last;
                    }
                }
                
                if( !$found ) {
                    # It did not exist. Create a new master row.
                    push @rows, {
                        key => $kactor,
                        row => $self->_copy($vspell->{$PLAYER}),
                        slaves => [ { key => $kspell, row => $vspell->{$PLAYER}, } ],
                    };
                }
            }
        }
        
        # Sort @rows.
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Heals In" => $pm->actorLink( $row->{key}, $self->{ext}{Index}->actorname($row->{key}), $self->{raid}{$row->{key}} && $self->{raid}{$row->{key}}{class} ),
                        "R-Eff. Heal" => $row->{row}{effective},
                        "R-Hits" => $row->{row}{count},
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
                            "Heals In" => $pm->spellLink( $slave->{key}, $self->{ext}{Index}->spellname( $slave->{key} ) ),
                            "R-Eff. Heal" => $slave->{row}{effective},
                            "R-Hits" => $slave->{row}{count},
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
    
    ##########
    # FOOTER #
    ##########
    
    $PAGE .= $pm->pageFooter;
}

sub _decodespell {
    my $self = shift;
    my $encoded_spellid = shift;
    my $pm = shift;
    my $PLAYER = shift;
    
    my $spellactor;
    my $spellname;
    my $spellid;

    if( $encoded_spellid =~ /^([A-Za-z0-9]+): (.+)$/ ) {
        if( $1 ne $PLAYER ) {
            $spellactor = $1;
            $spellname = sprintf( "%s: %s", $pm->actorLink( $1, $self->{ext}{Index}->actorname($1), $self->{raid}{$1}{class} ), $pm->spellLink( $2, $self->{ext}{Index}->spellname($2) ) );
            $spellid = $2;
        } else {
            $spellactor = $1;
            $spellname = $pm->spellLink( $2, $self->{ext}{Index}->spellname($2) );
            $spellid = $2;
        }
    } else {
        $spellactor = $PLAYER;
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

sub _rowDamage {
    my $self = shift;
    my $sdata = shift;
    my $title = shift;
    
    # We're printing a row based on $sdata.
    my $swings = ($sdata->{count} - $sdata->{tickCount});
    
    return {
        "Damaging Ability" => $title,
        "R-Total" => $sdata->{total},
        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
        "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{hitTotal} / $sdata->{hitCount}, $sdata->{hitMin}, $sdata->{hitMax} ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{tickTotal} / $sdata->{tickCount}, $sdata->{tickMin}, $sdata->{tickMax} ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{critTotal} / $sdata->{critCount}, $sdata->{critMin}, $sdata->{critMax} ),
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
        "Healing Ability" => $title,
        "R-Eff. Heal" => $sdata->{effective},
        "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ($sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100 : "",
        "R-Hits" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitCount} : "",
        "R-Avg Hit" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitTotal} / $sdata->{hitCount} : "",
        "R-Ticks" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickCount} : "",
        "R-Avg Tick" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickTotal} / $sdata->{tickCount} : "",
        "R-Crits" => $sdata->{critCount} ? sprintf "%d", $sdata->{critCount} : "",
        "R-Avg Crit" => $sdata->{critCount} ? sprintf "%d", $sdata->{critTotal} / $sdata->{critCount} : "",
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

1;
