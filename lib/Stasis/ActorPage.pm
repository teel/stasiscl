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
    
    my ($ref_damage_spell, $ref_damage_target, $ref_healing_spell, $ref_healing_target, $alldmg, $allheal, $allheal_eff, $dmg_to_mobs) = $self->_processDamageAndHealing($PLAYER);
    my %damage_spell = %{$ref_damage_spell};
    my %damage_target = %{$ref_damage_target};
    my %healing_spell = %{$ref_healing_spell};
    my %healing_target = %{$ref_healing_target};
    
    ###############
    # PAGE HEADER #
    ###############
    
    $PAGE .= $pm->pageHeader($self->{name}, $raidStart);
    $PAGE .= sprintf "<h3 style=\"color: #%s\">%s</h3>", $pm->classColor( $self->{raid}{$PLAYER}{class} ), HTML::Entities::encode_entities($self->{ext}{Index}->actorname($PLAYER));
    
    my $ptime = $self->{ext}{Presence}{actors}{$PLAYER}{end} - $self->{ext}{Presence}{actors}{$PLAYER}{start};
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
    
    if( $alldmg ) {
        my @damageHeader = (
                "Damaging Ability",
                "R-Total",
                "R-Hits",
                "R-Avg Hit",
                "R-Crits",
                "R-Avg Crit",
                "R-Ticks",
                "R-Avg Tick",
                "R-CriCruGla %",
                #"R-Crush",
                #"R-Glance",
                #"R-Avoid %",
                "MDPBARI %",
            );
    
        my @spellsort = sort {
            $damage_spell{$b}{total} <=> $damage_spell{$a}{total}
        } keys %damage_spell;
    
        $PAGE .= $pm->tableHeader(@damageHeader);
        foreach my $spellkey (@spellsort) {
            # $id is for javascript
            my $id = lc $spellkey;
            $id = Stasis::PageMaker->tameText($id);
        
            # $sdata is totals for the overall spell
            my $sdata;
            $sdata = $damage_spell{$spellkey};
            next unless $sdata->{total};
            
            # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
            my ($spellactor, $spellname, $spellid) = $self->_decodespell($spellkey, $pm, $PLAYER);
            
            my $swings = ($sdata->{count} - $sdata->{tickCount});
            $PAGE .= $pm->tableRow( 
                header => \@damageHeader,
                data => {
                    "Damaging Ability" => $spellname,
                    "R-Total" => $sdata->{total},
                    "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
                    "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{hitTotal} / $sdata->{hitCount}, $sdata->{hitMin}, $sdata->{hitMax} ),
                    "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
                    "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{tickTotal} / $sdata->{tickCount}, $sdata->{tickMin}, $sdata->{tickMax} ),
                    "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
                    "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{critTotal} / $sdata->{critCount}, $sdata->{critMin}, $sdata->{critMax} ),
                    "R-CriCruGla %" => $swings && sprintf( "%s/%s/%s", $self->_tidypct( $sdata->{critCount} / $swings * 100 ), $self->_tidypct( $sdata->{crushing} / $swings * 100 ), $self->_tidypct( $sdata->{glancing} / $swings * 100 ) ),
                    #"R-Crit" => $swings && sprintf( "%s%%", $self->_tidypct( $sdata->{critCount} / $swings * 100 ) ),
                    #"R-Glance" => $swings && sprintf( "%s%%", $self->_tidypct( $sdata->{glancing} / $swings * 100 ) ),
                    #"R-Crush" => $swings && sprintf( "%s%%", $self->_tidypct( $sdata->{crushing} / $swings * 100 ) ),
                    #"R-Avoid %" => sprintf( "%s%%", $swings && ($sdata->{count} - $sdata->{tickCount} - $sdata->{hitCount} - $sdata->{critCount}) / $swings * 100 ),
                    "MDPBARI %" => $swings && sprintf( "%s/%s/%s/%s/%s/%s/%s", $self->_tidypct( $sdata->{missCount} / $swings * 100 ), $self->_tidypct( $sdata->{dodgeCount} / $swings * 100 ), $self->_tidypct( $sdata->{parryCount} / $swings * 100 ), $self->_tidypct( $sdata->{blockCount} / $swings * 100 ), $self->_tidypct( $sdata->{absorbCount} / $swings * 100 ), $self->_tidypct( $sdata->{resistCount} / $swings * 100 ), $self->_tidypct( $sdata->{immuneCount} / $swings * 100 ) ),
                },
                type => "master",
                name => "damage_$id",
            );

            foreach my $target (sort { $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$b}{total} <=> $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$a}{total} } keys %{ $self->{ext}{Damage}{actors}{$spellactor}{$spellid} }) {
                # Reassign $sdata to the per-target breakdown
                $sdata = $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$target};
                next unless $sdata->{count};
                
                my $swings = ($sdata->{count} - $sdata->{tickCount});
                $PAGE .= $pm->tableRow( 
                    header => \@damageHeader,
                    data => {
                        "Damaging Ability" => $pm->actorLink( $target, $self->{ext}{Index}->actorname($target), $pm->classColor( $self->{raid}{$target}{class} ) ),
                        "R-Total" => $sdata->{total},
                        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
                        "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{hitTotal} / $sdata->{hitCount}, $sdata->{hitMin}, $sdata->{hitMax} ),
                        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
                        "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{tickTotal} / $sdata->{tickCount}, $sdata->{tickMin}, $sdata->{tickMax} ),
                        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
                        "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "%d (%d&ndash;%d)", $sdata->{critTotal} / $sdata->{critCount}, $sdata->{critMin}, $sdata->{critMax} ),
                        "R-CriCruGla %" => $swings && sprintf( "%s/%s/%s", $self->_tidypct( $sdata->{critCount} / $swings * 100 ), $self->_tidypct( $sdata->{crushing} / $swings * 100 ), $self->_tidypct( $sdata->{glancing} / $swings * 100 ) ),
                        #"R-Crit" => $swings && sprintf( "%s%%", $self->_tidypct( $sdata->{critCount} / $swings * 100 ) ),
                        #"R-Glance" => $swings && sprintf( "%s%%", $self->_tidypct( $sdata->{glancing} / $swings * 100 ) ),
                        #"R-Crush" => $swings && sprintf( "%s%%", $self->_tidypct( $sdata->{crushing} / $swings * 100 ) ),
                        #"R-Avoid %" => sprintf( "%s%%", $swings && ($sdata->{count} - $sdata->{tickCount} - $sdata->{hitCount} - $sdata->{critCount}) / $swings * 100 ),
                        "MDPBARI %" => $swings && sprintf( "%s/%s/%s/%s/%s/%s/%s", $self->_tidypct( $sdata->{missCount} / $swings * 100 ), $self->_tidypct( $sdata->{dodgeCount} / $swings * 100 ), $self->_tidypct( $sdata->{parryCount} / $swings * 100 ), $self->_tidypct( $sdata->{blockCount} / $swings * 100 ), $self->_tidypct( $sdata->{absorbCount} / $swings * 100 ), $self->_tidypct( $sdata->{resistCount} / $swings * 100 ), $self->_tidypct( $sdata->{immuneCount} / $swings * 100 ) ),
                    },
                    type => "slave",
                    name => "damage_$id",
                );
            }

            $PAGE .= $pm->jsClose("damage_$id");
        }
    
    }
    
    ###########
    # HEALING #
    ###########
    
    if( $allheal ) {
        my @healingHeader = (
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
                #"",
                #"",
                #"",
            );
        
        my @spellnames = sort {
            $healing_spell{$b}{effective} <=> $healing_spell{$a}{effective}
        } keys %healing_spell;
    
        $PAGE .= $pm->tableHeader(@healingHeader);
        foreach my $spellkey (@spellnames) {
            my $id = lc $spellkey;
            $id = Stasis::PageMaker->tameText($id);
    
            my $sdata;
            $sdata = $healing_spell{$spellkey};
            
            # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
            my ($spellactor, $spellname, $spellid) = $self->_decodespell($spellkey, $pm, $PLAYER);
            
            $PAGE .= $pm->tableRow( 
                header => \@healingHeader,
                data => {
                    "Healing Ability" => $spellname,
                    "R-Eff. Heal" => $sdata->{effective},
                    "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ($sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100 : "",
                    "R-Hits" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitCount} : "",
                    "R-Avg Hit" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitTotal} / $sdata->{hitCount} : "",
                    "R-Ticks" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickCount} : "",
                    "R-Avg Tick" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickTotal} / $sdata->{tickCount} : "",
                    "R-Crits" => $sdata->{critCount} ? sprintf "%d", $sdata->{critCount} : "",
                    "R-Avg Crit" => $sdata->{critCount} ? sprintf "%d", $sdata->{critTotal} / $sdata->{critCount} : "",
                    "R-Crit %" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                },
                type => "master",
                name => "healing_$id",
            );
    
            foreach my $target (sort { $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$b}{effective} <=> $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$a}{effective} } keys %{ $self->{ext}{Healing}{actors}{$spellactor}{$spellid} }) {
                $sdata = $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$target};
                next unless $sdata->{count};
    
                $PAGE .= $pm->tableRow( 
                    header => \@healingHeader,
                    data => {
                        "Healing Ability" => $pm->actorLink( $target, $self->{ext}{Index}->actorname($target), $pm->classColor( $self->{raid}{$target}{class} ) ),
                        "R-Eff. Heal" => $sdata->{effective},
                        "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ($sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100 : "",
                        "R-Hits" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitCount} : "",
                        "R-Avg Hit" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitTotal} / $sdata->{hitCount} : "",
                        "R-Ticks" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickCount} : "",
                        "R-Avg Tick" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickTotal} / $sdata->{tickCount} : "",
                        "R-Crits" => $sdata->{critCount} ? sprintf "%d", $sdata->{critCount} : "",
                        "R-Avg Crit" => $sdata->{critCount} ? sprintf "%d", $sdata->{critTotal} / $sdata->{critCount} : "",
                        "R-Crit %" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                    },
                    type => "slave",
                    name => "healing_$id",
                );
            }
    
            $PAGE .= $pm->jsClose("healing_$id");
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
            $id = Stasis::PageMaker->tameText($id);

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
            $id = Stasis::PageMaker->tameText($id);
            
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
                    "Target-W" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $pm->classColor( $self->{raid}{$_}{class} ) ), keys %{ $self->{ext}{Cast}{actors}{$PLAYER}{$spellid} } ),
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
            $id = Stasis::PageMaker->tameText($id);

            my $sdata;
            $sdata = $powtot{$powerid};
            $PAGE .= $pm->tableRow( 
                header => \@powerHeader,
                data => {
                    "Gain Name" => $pm->spellLink( $powerid, sprintf( "%s (%s)", $self->{ext}{Index}->spellname($powerid), $sdata->{type} ) ),
                    "R-Total" => $sdata->{amount},
                    "Source-W" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $pm->classColor( $self->{raid}{$_}{class} ) ), keys %{ $self->{ext}{Power}{actors}{$PLAYER}{$powerid} } ),
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
            $id = Stasis::PageMaker->tameText($id);

            my $sdata;
            $sdata = $powtot{$powerid};
            $PAGE .= $pm->tableRow( 
                header => \@powerHeader,
                data => {
                    "Gain Name" => $pm->spellLink( $powerid, sprintf( "%s (%s)", $self->{ext}{Index}->spellname($powerid), $sdata->{type} ) ),
                    "R-Total" => $sdata->{amount},
                    "Source-W" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $pm->classColor( $self->{raid}{$_}{class} ) ), keys %{ $self->{ext}{ExtraAttack}{actors}{$PLAYER}{$powerid} } ),
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
            $id = Stasis::PageMaker->tameText($id);

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
    
    if( $alldmg ) {
        my @header = (
                "Damage Out",
                "R-Total",
                "R-DPS",
                "Time",
                "R-Time % (Presence)",
                "R-Time % (DPS Time)",
            );

        my @targetsort = sort {
            $damage_target{$b}{total} <=> $damage_target{$a}{total}
        } keys %damage_target;
        
        $PAGE .= $pm->tableHeader(@header);
        
        foreach my $targetid (@targetsort) {
            my $id = lc $targetid;
            $id = Stasis::PageMaker->tameText($id);
            
            my $sdata = $damage_target{$targetid};
            my $dpstime_target = $self->{ext}{Activity}{actors}{$PLAYER}{targets}{$targetid}{time};
            my $dpstime_all = $self->{ext}{Activity}{actors}{$PLAYER}{all}{time};
            $PAGE .= $pm->tableRow( 
                header => \@header,
                data => {
                    "Damage Out" => $pm->actorLink( $targetid, $self->{ext}{Index}->actorname($targetid), $pm->classColor( $self->{raid}{$targetid}{class} ) ),
                    "R-Total" => $sdata->{total},
                    "R-DPS" => $dpstime_target && sprintf( "%d", $damage_target{$targetid}{total} / $dpstime_target ),
                    "Time" => $dpstime_target && sprintf( "%02d:%02d", $dpstime_target/60, $dpstime_target%60 ),
                    "R-Time % (Presence)" => $dpstime_target && $ptime && sprintf( "%0.1f%%", $dpstime_target / $ptime * 100 ),
                    "R-Time % (DPS Time)" => $dpstime_target && $dpstime_all && sprintf( "%0.1f%%", $dpstime_target / $dpstime_all * 100 ),
                },
                type => "master",
                name => "dmgout_$id",
            );
            
            # Check all spells this $PLAYER used against $targetid.
            my %targetid_damage;
            foreach my $encoded_spellid (keys %damage_spell) {
                # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($encoded_spellid, $pm, $PLAYER);
                
                if( exists $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$targetid} ) {
                    $targetid_damage{$encoded_spellid} = $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$targetid};
                }
            }
            
            # Sort
            my @spellsort = sort { 
                $targetid_damage{$b}{total} <=> $targetid_damage{$a}{total} 
            } keys %targetid_damage;
            
            foreach my $encoded_spellid (@spellsort) {
                # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($encoded_spellid, $pm, $PLAYER);
                
                # Make sure this spell was used against this target.
                if( $sdata = $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$targetid} ) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Damage Out" => $spellname,
                            "R-Total" => $sdata->{total},
                        },
                        type => "slave",
                        name => "dmgout_$id",
                    );
                }
            }
            
            $PAGE .= $pm->jsClose("dmgout_$id");
        }
    }
    
    #####################
    # DAMAGE IN SOURCES #
    #####################
    
    if( 1 ) {
        my @header = (
                "Damage In",
                "R-Total",
                "R-DPS",
                "Time",
                "R-Time % (Presence)",
                "R-Time % (DPS Time)",
            );
        
        my %sourcedmg;
        my %sourcedmg_byspell;
        foreach my $actor (keys %{ $self->{ext}{Damage}{actors} }) {
            foreach my $spell (keys %{ $self->{ext}{Damage}{actors}{$actor} }) {
                next unless exists $self->{ext}{Damage}{actors}{$actor}{$spell}{$PLAYER};
                $sourcedmg{$actor} += $self->{ext}{Damage}{actors}{$actor}{$spell}{$PLAYER}{total};
                $sourcedmg_byspell{$actor}{$spell} += $self->{ext}{Damage}{actors}{$actor}{$spell}{$PLAYER}{total};
            }
        }

        my @sources = sort {
            $sourcedmg{$b} <=> $sourcedmg{$a}
        } keys %sourcedmg;
        
        if( @sources ) {
            $PAGE .= $pm->tableHeader(@header);

            foreach my $sourceid (@sources) {
                my $id = lc $sourceid;
                $id = Stasis::PageMaker->tameText($id);

                my $source_ptime = $sourceid && $self->{ext}{Presence}{actors}{$sourceid}{end} - $self->{ext}{Presence}{actors}{$sourceid}{start};
                my $dpstime_target = $self->{ext}{Activity}{actors}{$sourceid}{targets}{$PLAYER}{time};
                my $dpstime_all = $self->{ext}{Activity}{actors}{$sourceid}{all}{time};
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Damage In" => $pm->actorLink( $sourceid, $self->{ext}{Index}->actorname($sourceid), $pm->classColor( $self->{raid}{$sourceid}{class} ) ),
                        "R-Total" => $sourcedmg{$sourceid},
                        "R-DPS" => $dpstime_target && sprintf( "%d", $sourcedmg{$sourceid} / $dpstime_target ),
                        "Time" => $dpstime_target && sprintf( "%02d:%02d", $dpstime_target/60, $dpstime_target%60 ),
                        "R-Time % (Presence)" => $dpstime_target && $source_ptime && sprintf( "%0.1f%%", $dpstime_target / $source_ptime * 100 ),
                        "R-Time % (DPS Time)" => $dpstime_target && $dpstime_all && sprintf( "%0.1f%%", $dpstime_target / $dpstime_all * 100 ),
                    },
                    type => "master",
                    name => "dmgin_$id",
                );
                
                my @spellsort = sort {
                    $sourcedmg_byspell{$sourceid}{$b} <=> $sourcedmg_byspell{$sourceid}{$a}
                } keys %{$sourcedmg_byspell{$sourceid}};
                
                foreach my $spellid (@spellsort) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Damage In" => $pm->spellLink( $spellid, $self->{ext}{Index}->spellname($spellid) ),
                            "R-Total" => $sourcedmg_byspell{$sourceid}{$spellid},
                        },
                        type => "slave",
                        name => "dmgin_$id",
                    );
                }

                $PAGE .= $pm->jsClose("dmgin_$id");
            }
        }
    }
    
    #######################
    # HEALING OUT TARGETS #
    #######################
    
    if( $allheal ) {
        my @header = (
                "Heals Out",
                "R-Eff. Heal",
                "R-Hits",
                "R-Eff. Out %",
                "R-Overheal %",
                "",
            );
        
        my @targets = sort {
            $healing_target{$b}{effective} <=> $healing_target{$a}{effective}
        } keys %healing_target;

        if( @targets ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $targetid (@targets) {
                my $id = lc $targetid;
                $id = Stasis::PageMaker->tameText($id);
                
                my $sdata = $healing_target{$targetid};
                
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Heals Out" => $pm->actorLink( $targetid, $self->{ext}{Index}->actorname($targetid), $pm->classColor( $self->{raid}{$targetid}{class} ) ),
                        "R-Eff. Heal" => $sdata->{effective},
                        "R-Hits" => $sdata->{hitCount} + $sdata->{critCount} + $sdata->{tickCount},
                        "R-Overheal %" => $sdata->{total} && $sdata->{effective} && sprintf( "%0.1f%%", ( $sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100 ),
                        "R-Eff. Out %" => $allheal_eff && $sdata->{effective} && sprintf( "%0.1f%%", $sdata->{effective} / $allheal_eff * 100 ),
                    },
                    type => "master",
                    name => "healout_$id",
                );
                
                # Check all spells this $PLAYER used on $targetid.
                my %targetid_healing;
                my $targetid_alleff = 0;
                foreach my $encoded_spell (keys %healing_spell) {
                    # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($encoded_spell, $pm, $PLAYER);
                    
                    next unless exists $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$targetid};
                    $targetid_healing{$encoded_spell} = $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$targetid}{effective};
                    $targetid_alleff += $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$targetid}{effective};
                }
                
                my @spellsort = sort {
                    $targetid_healing{$b} <=> $targetid_healing{$a}
                } keys %targetid_healing;
            
                foreach my $encoded_spell (@spellsort) {
                    # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($encoded_spell, $pm, $PLAYER);
                    
                    my $sdata = $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$targetid};
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Heals Out" => $spellname,
                            "R-Eff. Heal" => $sdata->{effective},
                            "R-Hits" => $sdata->{hitCount} + $sdata->{critCount} + $sdata->{tickCount},
                            "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ( $sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100: "",
                            "R-Eff. Out %" => $sdata->{effective} ? sprintf "%0.1f%%", $sdata->{effective} / $targetid_alleff * 100: "",
                        },
                        type => "slave",
                        name => "healout_$id",
                    );
                }
            
                $PAGE .= $pm->jsClose("healout_$id");
            }
        }
    }
    
    ######################
    # HEALING IN SOURCES #
    ######################
    
    if( 1 ) {
        my @header = (
                "Heals In",
                "R-Eff. Heal",
                "R-Hits",
                "R-Eff. In %",
                "R-Overheal %",
                "",
            );
        
        my %healin_actors;
        my $eff_on_me = 0;
        foreach my $actor (keys %{ $self->{ext}{Healing}{actors} }) {
            next if $self->_ispet($actor);
            
            my ($ref_damage_spell, $ref_damage_target, $ref_healing_spell, $ref_healing_target, $x_alldmg, $x_allheal, $x_allheal_eff, $x_dmg_to_mobs) = $self->_processDamageAndHealing($actor);
            if( exists $ref_healing_target->{$PLAYER} ) {
                $healin_actors{$actor} = {
                    damage_spell => $ref_damage_spell,
                    damage_target => $ref_damage_target,
                    healing_spell => $ref_healing_spell,
                    healing_target => $ref_healing_target,
                    alldmg => $x_alldmg,
                    allheal => $x_allheal,
                    allheal_eff => $x_allheal_eff,
                    dmg_to_mobs => $x_dmg_to_mobs,
                };
                
                $eff_on_me += $ref_healing_target->{$PLAYER}{effective};
            }
        }

        my @sources = sort {
            $healin_actors{$b}{healing_target}{$PLAYER}{effective} <=> $healin_actors{$a}{healing_target}{$PLAYER}{effective}
        } keys %healin_actors;

        if( @sources ) {
            $PAGE .= $pm->tableHeader(@header);
            foreach my $sourceid (@sources) {
                my $id = lc $sourceid;
                $id = Stasis::PageMaker->tameText($id);
                
                # skip if effective healing is zero
                next unless $healin_actors{$sourceid}{healing_target}{$PLAYER}{effective};
                
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Heals In" => $pm->actorLink( $sourceid, $self->{ext}{Index}->actorname($sourceid), $pm->classColor( $self->{raid}{$sourceid}{class} ) ),
                        "R-Eff. Heal" => $healin_actors{$sourceid}{healing_target}{$PLAYER}{effective},
                        "R-Hits" => $healin_actors{$sourceid}{healing_target}{$PLAYER}{hits},
                        "R-Overheal %" => $healin_actors{$sourceid}{healing_target}{$PLAYER}{total} && sprintf( "%0.1f%%", ( $healin_actors{$sourceid}{healing_target}{$PLAYER}{total} - $healin_actors{$sourceid}{healing_target}{$PLAYER}{effective} ) / $healin_actors{$sourceid}{healing_target}{$PLAYER}{total} * 100 ),
                        "R-Eff. In %" => $eff_on_me && sprintf( "%0.1f%%", $healin_actors{$sourceid}{healing_target}{$PLAYER}{effective} / $eff_on_me * 100 ),
                    },
                    type => "master",
                    name => "healin_$id",
                );
                
                # Check all spells that $sourceid used on $PLAYER.
                my %sourceid_healing;
                my $sourceid_alleff = 0;
                foreach my $encoded_spell (keys %{ $healin_actors{$sourceid}{healing_spell} }) {
                    # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($encoded_spell, $pm, $sourceid);
                    
                    next unless exists $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$PLAYER};
                    $sourceid_healing{$encoded_spell} = $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$PLAYER}{effective};
                    $sourceid_alleff += $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$PLAYER}{effective};
                }
            
                my @spellsort = sort {
                    $sourceid_healing{$b} <=> $sourceid_healing{$a}
                } keys %sourceid_healing;
            
                foreach my $spellkey (@spellsort) {
                    # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($spellkey, $pm, $sourceid);
                        
                    my $sdata = $self->{ext}{Healing}{actors}{$spellactor}{$spellid}{$PLAYER};
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Heals In" => $spellname,
                            "R-Eff. Heal" => $sdata->{effective},
                            "R-Hits" => $sdata->{hitCount} + $sdata->{critCount} + $sdata->{tickCount},
                            "R-Overheal %" => $sdata->{total} && sprintf( "%0.1f%%", ( $sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100 ),
                            "R-Eff. Out %" => $sourceid_alleff && sprintf( "%0.1f%%", $sdata->{effective} / $sourceid_alleff * 100 ),
                        },
                        type => "slave",
                        name => "healin_$id",
                    );
                }
                
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

# Takes an actor name
# Merges in pets
# Returns references to processed lists with encoded spell names (that include pet names)
# broken down by spell and target.
sub _processDamageAndHealing {
    my ($self, $PLAYER) = @_;
    
    #####################
    # TOTAL DAMAGE DONE #
    #####################
    
    # Total up the per-spell per-target keys for each spell (on the side).
    my %damage_spell;
    my %damage_target;
    
    my $alldmg = 0;
    my $dmg_to_mobs = 0;
    foreach my $dmg_actor ( keys %{$self->{ext}{Damage}{actors}} ) {
        # Look at the $PLAYER and pets.
        next unless $dmg_actor eq $PLAYER || ( exists $self->{raid}{$PLAYER} && grep $_ eq $dmg_actor, @{$self->{raid}{$PLAYER}{pets}} );
        
        foreach my $spell (keys %{$self->{ext}{Damage}{actors}{$dmg_actor}}) {;
            # Encode pet damage like this.
            my $encoded_spell = $dmg_actor eq $PLAYER ? $spell : "$dmg_actor: $spell"; 
            
            foreach my $target (keys %{$self->{ext}{Damage}{actors}{$dmg_actor}{$spell}}) {
                # Include all damage in the per-spell and per-target running totals.
                foreach my $key (keys %{$self->{ext}{Damage}{actors}{$dmg_actor}{$spell}{$target}}) {
                    my $keys = $self->{ext}{Damage}{actors}{$dmg_actor}{$spell}{$target};
                    if( $key =~ /([Mm]in|[Mm]ax)$/ ) {
                        # TARGET
                        if( lc $1 eq "min" && (!$damage_target{$target}{$key} || $keys->{$key} < $damage_target{$target}{$key}) ) {
                            $damage_target{$target}{$key} = $keys->{$key};
                        } elsif( lc $1 eq "max" && (!$damage_target{$target}{$key} || $keys->{$key} > $damage_target{$target}{$key}) ) {
                            $damage_target{$target}{$key} = $keys->{$key};
                        }
                        
                        # SPELL
                        if( lc $1 eq "min" && (!$damage_spell{$encoded_spell}{$key} || $keys->{$key} < $damage_spell{$encoded_spell}{$key}) ) {
                            $damage_spell{$encoded_spell}{$key} = $keys->{$key};
                        } elsif( lc $1 eq "max" && (!$damage_spell{$encoded_spell}{$key} || $keys->{$key} > $damage_spell{$encoded_spell}{$key}) ) {
                            $damage_spell{$encoded_spell}{$key} = $keys->{$key};
                        }
                    } else {
                        # TARGET
                        $damage_target{$target}{$key} += $keys->{$key};
                        
                        # SPELL
                        $damage_spell{$encoded_spell}{$key} += $keys->{$key};
                    }
                }
                
                # Add to total damage.
                $alldmg += $self->{ext}{Damage}{actors}{$dmg_actor}{$spell}{$target}{total};
                
                # Skip friendlies when totaling damage to mobs.
                $dmg_to_mobs += $self->{ext}{Damage}{actors}{$dmg_actor}{$spell}{$target}{total} unless $self->{raid}{$target}{class};
            }
        }
    }
    
    ######################
    # TOTAL HEALING DONE #
    ######################
    
    # Total up the per-spell per-target keys for each spell.
    my %healing_spell;
    my %healing_target;
    my $allheal = 0;
    my $allheal_eff = 0;
    
    foreach my $heal_actor ( keys %{$self->{ext}{Healing}{actors}} ) {
        # Look at the $PLAYER and pets.
        next unless $heal_actor eq $PLAYER || ( exists $self->{raid}{$PLAYER} && grep $_ eq $heal_actor, @{$self->{raid}{$PLAYER}{pets}} );
        
        foreach my $spell (keys %{$self->{ext}{Healing}{actors}{$heal_actor}}) {;
            # Encode pet healing like this.
            my $encoded_spell = $heal_actor eq $PLAYER ? $spell : "$heal_actor: $spell"; 
            
            foreach my $target (keys %{$self->{ext}{Healing}{actors}{$heal_actor}{$spell}}) {
                # Include all healing in the per-spell and per-target running totals.
                foreach my $key (keys %{$self->{ext}{Healing}{actors}{$heal_actor}{$spell}{$target}}) {
                    my $keys = $self->{ext}{Healing}{actors}{$heal_actor}{$spell}{$target};
                    $healing_target{$target}{$key} += $keys->{$key};
                    $healing_spell{$encoded_spell}{$key} += $keys->{$key};
                }
                
                # Add to total healing.
                $allheal += $self->{ext}{Healing}{actors}{$heal_actor}{$spell}{$target}{total};
                $allheal_eff += $self->{ext}{Healing}{actors}{$heal_actor}{$spell}{$target}{effective};
            }
        }
    }
    
    return (\%damage_spell, \%damage_target, \%healing_spell, \%healing_target, $alldmg, $allheal, $allheal_eff, $dmg_to_mobs);
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
        $spellactor = $1;
        $spellname = sprintf( "%s: %s", $pm->actorLink( $1, $self->{ext}{Index}->actorname($1), $pm->classColor( $self->{raid}{$1}{class} ) ), $pm->spellLink( $2, $self->{ext}{Index}->spellname($2) ) );
        $spellid = $2;
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

sub _ispet {
    my ($self, $name) = @_;
    
    return $self->{raid}{$name} && $self->{raid}{$name}{class} && $self->{raid}{$name}{class} eq "Pet";
}

1;
