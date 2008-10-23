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
use Stasis::Parser;
use Stasis::PageMaker;
use Stasis::ActorGroup;
use Stasis::Extension qw(span_sum);

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
    $params{server} ||= "";
    
    bless \%params, $class;
}

sub page {
    my ($self, $MOB, $do_group) = @_;
    my $MOB_GROUP = $self->{grouper}->group($MOB);
    my @PLAYER = $do_group && $MOB_GROUP ? @{ $MOB_GROUP->{members} } : ($MOB);
    return unless @PLAYER;
    
    my $PAGE;
    my $pm = $self->{pm};
    
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
    
    ################
    # INFO WE NEED #
    ################
    
    my $keyActor = sub { $self->{grouper}->captain_for($_[0]) };
    
    my $dpsTime = span_sum( $self->{ext}{Activity}->sum( actor => \@playpet )->{spans} );
    
    my $deOut = $self->{ext}{Damage}->sum( 
        actor => \@playpet, 
        expand => [ "actor", "spell", "target" ],
        keyActor => $keyActor,
    );

    my $deIn = $self->{ext}{Damage}->sum( 
        target => \@PLAYER, 
        expand => [ "actor", "spell" ],
        keyActor => $keyActor,
    );
    
    my $heOut = $self->{ext}{Healing}->sum( 
        actor => \@playpet, 
        expand => [ "actor", "spell", "target" ],
        keyActor => $keyActor,
    );
    
    my $heIn = $self->{ext}{Healing}->sum( 
        target => \@PLAYER, 
        expand => [ "actor", "spell" ],
        keyActor => $keyActor,
    );
    
    my $castsOut = $self->{ext}{Cast}->sum( 
        actor => \@PLAYER, 
        expand => [ "spell", "target" ], 
        keyActor => $keyActor,
    );

    my $powerIn = $self->{ext}{Power}->sum( 
        target => \@PLAYER, 
        expand => [ "spell", "actor" ], 
        keyActor => $keyActor,
    );
    
    my $powerOut = $self->{ext}{Power}->sum( 
        actor => \@PLAYER, 
        -target => \@PLAYER,
        expand => [ "spell", "target" ], 
        keyActor => $keyActor,
    );

    my $eaIn = $self->{ext}{ExtraAttack}->sum( 
        target => \@PLAYER, 
        expand => [ "spell", "actor" ], 
        keyActor => $keyActor,
    );
    
    my $interruptOut = $self->{ext}{Interrupt}->sum( 
        actor => \@PLAYER, 
        expand => [ "extraspell", "target" ], 
        keyActor => $keyActor,
    );
    
    my $dispelOut = $self->{ext}{Dispel}->sum( 
        actor => \@PLAYER, 
        expand => [ "extraspell", "target" ], 
        keyActor => $keyActor,
    );
    
    my $interruptIn = $self->{ext}{Interrupt}->sum( 
        target => \@PLAYER, 
        expand => [ "extraspell", "actor" ], 
        keyActor => $keyActor,
    );
    
    my $dispelIn = $self->{ext}{Dispel}->sum( 
        target => \@PLAYER, 
        expand => [ "extraspell", "actor" ], 
        keyActor => $keyActor,
    );
    
    my ($auraIn, $auraOut);
    if( ! $do_group ) {
        $auraIn = $self->{ext}{Aura}->sum( 
            target => [ $MOB ], 
            expand => [ "spell", "actor" ], 
            keyActor => $keyActor,
        );

        $auraOut = $self->{ext}{Aura}->sum( 
            actor => [ $MOB ], 
            -target => [ $MOB ],
            expand => [ "spell", "target" ], 
            keyActor => $keyActor,
        );
    }
    
    ###########################
    # DAMAGE AND HEALING SUMS #
    ###########################
    
    # Total damage, and damage from/to mobs
    my $dmg_from_all = 0;
    my $dmg_from_mobs = 0;
    
    my $dmg_to_all = 0;
    my $dmg_to_mobs = 0;
    
    while( my ($kactor, $vactor) = each(%$deOut) ) {
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                $dmg_to_all += $vtarget->{total} || 0;
                $dmg_to_mobs += $vtarget->{total} || 0 if !$self->{raid}{$ktarget} || !$self->{raid}{$ktarget}{class};
            }
        }
    }
    
    while( my ($kactor, $vactor) = each(%$deIn) ) {
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            $dmg_from_all += $vspell->{total} || 0;
            $dmg_from_mobs += $vspell->{total} || 0 if !$self->{raid}{$kactor} || !$self->{raid}{$kactor}{class};
        }
    }
    
    ###############
    # PAGE HEADER #
    ###############
    
    my $displayName = sprintf "%s%s", HTML::Entities::encode_entities($self->{ext}{Index}->actorname($MOB)), @PLAYER > 1 ? " (group)" : "";
    $displayName ||= "Actor";
    $PAGE .= $pm->pageHeader($self->{name}, $displayName, $raidStart);
    $PAGE .= sprintf "<h3 class=\"color%s\">%s%s</h3>", $self->{raid}{$MOB}{class} || "Mob", $pm->actorLink($MOB, @PLAYER == 1 ? 1 : 0 ), @PLAYER > 1 ? " (group)" : "";
    
    my @summaryRows;
    
    # Type info
    push @summaryRows, "Class" => $self->{raid}{$MOB}{class} || "Mob";
    
    if( $self->{server} && $self->{raid}{$MOB}{class} && $self->{raid}{$MOB}{class} ne "Pet" ) {
        my $r = $self->{server};
        my $n = $self->{ext}{Index}->actorname($MOB);
        $r =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
        $n =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
        push @summaryRows, "Armory" => "<a href=\"http://www.wowarmory.com/character-sheet.xml?r=$r&n=$n\" target=\"swsar_$n\">$displayName &#187;</a>";
    }
    
    # Presence
    push @summaryRows, "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 );
    
    # Owner info
    if( $self->{raid}{$MOB} && $self->{raid}{$MOB}{class} && $self->{raid}{$MOB}{class} eq "Pet" ) {
        foreach my $raider (keys %{$self->{raid}}) {
            if( grep $_ eq $MOB, @{$self->{raid}{$raider}{pets}}) {
                push @summaryRows, "Owner" => $pm->actorLink($raider);
                last;
            }
        }
    }
    
    # Pet info
    {
        my %pets;
        foreach my $p (@PLAYER) {
            if( exists $self->{raid}{$p} && exists $self->{raid}{$p}{pets} ) {
                $pets{ $keyActor->($_) } = 1 foreach ( grep { $self->{ext}{Presence}->presence($_) } @{$self->{raid}{$p}{pets}} );
            }
        }
        
        if( %pets ) {
            push @summaryRows, "Pets" => join "<br />", map { $pm->actorLink($_) } sort { $self->{ext}{Index}->actorname($a) cmp $self->{ext}{Index}->actorname($b) } keys %pets;
        }
    }
    
    # Damage Info
    if( $dmg_to_all ) {
        push @summaryRows, (
            "Damage in" => $dmg_from_all . ( $dmg_from_all - $dmg_from_mobs ? " (" . ($dmg_from_all - $dmg_from_mobs) . " was from players)" : "" ),
            "Damage out" => $dmg_to_all . ( $dmg_to_all - $dmg_to_mobs ? " (" . ($dmg_to_all - $dmg_to_mobs) . " was to players)" : "" ),
        );
    }
    
    # DPS Info
    if( $ptime && $dmg_to_mobs && $dpsTime ) {
        push @summaryRows, (
            "DPS activity" => sprintf
            (
                "%02d:%02d (%0.1f%% of presence)",
                $dpsTime/60, 
                $dpsTime%60, 
                $dpsTime/$ptime*100, 
            ),
            "DPS (over presence)" => sprintf( "%d", $dmg_to_mobs/$ptime ),
            "DPS (over activity)" => sprintf( "%d", $dmg_to_mobs/$dpsTime ),
        );
    }
    
    $PAGE .= $pm->vertBox( "Actor summary", @summaryRows );
    $PAGE .= "<br />";
    
    if( $MOB_GROUP ) {
        # Group information
        my $group_text = "<div align=\"left\">This is a group composed of " . @{$MOB_GROUP->{members}} . " mobs.<br />";
        
        $group_text .= "<br /><b>Group Link</b></br />";
        $group_text .= sprintf "%s%s<br />", $pm->actorLink($MOB), ( $do_group ? " (currently viewing)" : "" );
        
        $group_text .= "<br /><b>Member Links</b></br />";

        if( $self->{collapse} ) {
            $group_text .= "Member links are disabled for this group."
        } else {
            foreach (@{$MOB_GROUP->{members}}) {
                $group_text .= sprintf "%s%s<br />", $pm->actorLink($_, 1), ( !$do_group && $_ eq $MOB ? " (currently viewing)" : "" );
            }
        }
        
        $group_text .= "</div>";
        
        $PAGE .= $pm->textBox( $group_text, "Group Information" );
        $PAGE .= "<br />";
    }
    
    my @tabs;
    push @tabs, "Damage" if %$deOut || %$deIn;
    push @tabs, "Healing" if %$heOut || %$heIn;
    push @tabs, "Auras" if ($auraIn && %$auraIn) || ($auraOut && %$auraOut);
    push @tabs, "Casts and Power" if %$castsOut || %$powerIn || %$eaIn || %$powerOut;
    push @tabs, "Dispels and Interrupts" if %$interruptIn || %$interruptOut || %$dispelIn || %$dispelOut;
    push @tabs, "Deaths" if (!$do_group || !$self->{collapse} ) && $self->_keyExists( $self->{ext}{Death}{actors}, @PLAYER );
    
    $PAGE .= $pm->tabBar(@tabs);
    
    ##########
    # DAMAGE #
    ##########
    
    if( %$deOut || %$deIn ) {
        $PAGE .= $pm->tabStart("Damage");
        $PAGE .= $pm->tableStart;
        
        ########################
        # DAMAGE OUT ABILITIES #
        ########################
        
        $PAGE .= $pm->tableRows(
            title => "Damage Out by Ability",
            header => [ "Ability", "R-Total", "R-%", "", "", "R-Hits", "R-Crits", "R-Ticks", "R-AvHit", "R-AvCrit", "R-AvTick", "R-% Crit", "R-Avoid", ],
            data => $self->_abilityRows($deOut),
            sort => sub ($$) { ($_[1]->{total}||0) <=> ($_[0]->{total}||0) },
            master => sub {
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0], $pm, "Damage", @PLAYER);
                return $self->_rowDamage( $_[1], $dmg_to_all, "Ability", $spellname );
            },
            slave => sub {
                return $self->_rowDamage( $_[1], $_[3]->{total}, "Ability", $pm->actorLink( $_[0] ) );
            }
        ) if %$deOut;

        ######################
        # DAMAGE OUT TARGETS #
        ######################
        
        $PAGE .= $pm->tableRows(
            title => "Damage Out by Target",
            header => [ "Target", "R-Total", "R-%", "R-DPS", "R-Time", "R-Hits", "R-Crits", "R-Ticks", "R-AvHit", "R-AvCrit", "R-AvTick", "R-% Crit", "R-Avoid", ],
            data => $self->_targetRows($deOut),
            sort => sub ($$) { ($_[1]->{total}||0) <=> ($_[0]->{total}||0) },
            master => sub {
                my $dpsTime = span_sum(
                    $self->{ext}{Activity}->sum( 
                        actor => \@playpet, 
                        target => [ $self->{grouper}->expand($_[0]) ],
                    )->{spans}
                );
                return $self->_rowDamage( $_[1], $dmg_to_all, "Target", $pm->actorLink( $_[0] ), $dpsTime );
            },
            slave => sub {
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0], $pm, "Damage", @PLAYER);
                return $self->_rowDamage( $_[1], $_[3]->{total}, "Target", $spellname );
            }
        ) if %$deOut;

        #####################
        # DAMAGE IN SOURCES #
        #####################

        $PAGE .= $pm->tableRows(
            title => "Damage In by Source",
            header => [ "Source", "R-Total", "R-%", "R-DPS", "R-Time", "R-Hits", "R-Crits", "R-Ticks", "R-AvHit", "R-AvCrit", "R-AvTick", "R-% Crit", "R-Avoid", ],
            data => $deIn,
            sort => sub ($$) { ($_[1]->{total}||0) <=> ($_[0]->{total}||0) },
            master => sub {
                my $dpsTime = span_sum(
                    $self->{ext}{Activity}->sum( 
                        actor => [ $self->{grouper}->expand($_[0]) ],
                        target => \@PLAYER, 
                    )->{spans}
                );

                return $self->_rowDamage( $_[1], $dmg_from_all, "Source", $pm->actorLink( $_[0] ), $dpsTime );
            },
            slave => sub {
                return $self->_rowDamage( $_[1], $_[3]->{total}, "Source", $pm->spellLink( $_[0], "Damage" ) );
            }
        ) if %$deIn;
        
        $PAGE .= $pm->tableEnd;
        $PAGE .= $pm->tabEnd;
    }
    
    ###########
    # HEALING #
    ###########
    
    my ($eff_on_others, $eff_on_me);
    if( %$heIn || %$heOut ) {
        $PAGE .= $pm->tabStart("Healing");
        $PAGE .= $pm->tableStart;
        
        #########################
        # HEALING OUT ABILITIES #
        #########################
        
        $PAGE .= $pm->tableRows(
            title => "Healing Out by Ability",
            header => [ "Ability", "R-Eff. Heal", "R-%", "R-Hits", "R-Crits", "R-Ticks", "R-AvHit", "R-AvCrit", "R-AvTick", "R-% Crit", "R-Overheal", ],
            data => $self->_abilityRows($heOut),
            sort => sub ($$) { ($_[1]->{effective}||0) <=> ($_[0]->{effective}||0) },
            preprocess => sub { $eff_on_others += ($_[1]->{effective}||0) if( @_ == 2 ) },
            master => sub {
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0], $pm, "Healing", @PLAYER);
                return $self->_rowHealing( $_[1], $eff_on_others, "Ability", $spellname );
            },
            slave => sub {
                return $self->_rowHealing( $_[1], $_[3]->{effective}, "Ability", $pm->actorLink( $_[0] ) );
            }
        ) if %$heOut;

        #######################
        # HEALING OUT TARGETS #
        #######################
        
        $PAGE .= $pm->tableRows(
            title => "Healing Out by Target",
            header => [ "Target", "R-Eff. Heal", "R-%", "R-Hits", "R-Crits", "R-Ticks", "R-AvHit", "R-AvCrit", "R-AvTick", "R-% Crit", "R-Overheal", ],
            data => $self->_targetRows($heOut),
            sort => sub ($$) { ($_[1]->{effective}||0) <=> ($_[0]->{effective}||0) },
            master => sub {
                return $self->_rowHealing( $_[1], $eff_on_others, "Target", $pm->actorLink($_[0]) );
            },
            slave => sub {
                my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0], $pm, "Healing", @PLAYER);
                return $self->_rowHealing( $_[1], $_[3]->{effective}, "Target", $spellname );
            }
        ) if %$heOut;

        ######################
        # HEALING IN SOURCES #
        ######################

        $PAGE .= $pm->tableRows(
            title => "Healing In by Source",
            header => [ "Source", "R-Eff. Heal", "R-%", "R-Hits", "R-Crits", "R-Ticks", "R-AvHit", "R-AvCrit", "R-AvTick", "R-% Crit", "R-Overheal", ],
            data => $heIn,
            sort => sub ($$) { ($_[1]->{effective}||0) <=> ($_[0]->{effective}||0) },
            preprocess => sub { $eff_on_me += ($_[1]->{effective}||0) if( @_ == 2 ) },
            master => sub {
                return $self->_rowHealing( $_[1], $eff_on_me, "Source", $pm->actorLink($_[0]) );
            },
            slave => sub {
                return $self->_rowHealing( $_[1], $_[3]->{effective}, "Source", $pm->spellLink($_[0], "Healing") );
            }
        ) if %$heIn;

        $PAGE .= $pm->tableEnd;
        $PAGE .= $pm->tabEnd;
    }
    
    ###################
    # CASTS AND POWER #
    ###################
    
    if( %$castsOut || %$powerIn || %$eaIn || %$powerOut ) {
        $PAGE .= $pm->tabStart("Casts and Power");
        $PAGE .= $pm->tableStart;

        #########
        # CASTS #
        #########

        $PAGE .= $pm->tableRows(
            title => "Casts",
            header => [ "Name", "R-Targets", "R-Casts", "", "", "", ],
            data => $castsOut,
            sort => sub ($$) { $_[1]->{count} <=> $_[0]->{count} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Casts and Power" ),
                    "R-Targets" => scalar keys %{$castsOut->{$_[0]}},
                    "R-Casts" => $_[1]->{count},
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Targets" => "",
                    "R-Casts" => $_[1]->{count},
                };
            },
        ) if %$castsOut;

        ###########################
        # POWER and EXTRA ATTACKS #
        ###########################

        $PAGE .= $pm->tableRows(
            title => "Power Gains",
            header => [ "Name", "R-Sources", "R-Gained", "R-Ticks", "R-Avg", "R-Per 5", ],
            data => $powerIn,
            sort => sub ($$) { $_[1]->{amount} <=> $_[0]->{amount} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Casts and Power" ) . " (" . Stasis::Parser->_powerName( $_[1]->{type} ) . ")",
                    "R-Sources" => scalar keys %{$powerIn->{$_[0]}},
                    "R-Gained" => $_[1]->{amount},
                    "R-Ticks" => $_[1]->{count},
                    "R-Avg" => $_[1]->{count} && sprintf( "%d", $_[1]->{amount} / $_[1]->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[1]->{amount} / $ptime * 5 ),
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Gained" => $_[1]->{amount},
                    "R-Ticks" => $_[1]->{count},
                    "R-Avg" => $_[1]->{count} && sprintf( "%d", $_[1]->{amount} / $_[1]->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[1]->{amount} / $ptime * 5 ),
                };
            },
        ) if %$powerIn;

        $PAGE .= $pm->tableRows(
            title => %$powerIn ? "" : "Power Gains",
            header => [ "Name", "R-Sources", "R-Gained", "R-Ticks", "R-Avg", "R-Per 5", ],
            data => $eaIn,
            sort => sub ($$) { $_[1]->{amount} <=> $_[0]->{amount} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Casts and Power" ) . " (extra attacks)",
                    "R-Sources" => scalar keys %{$eaIn->{$_[0]}},
                    "R-Gained" => $_[1]->{amount},
                    "R-Ticks" => $_[1]->{count},
                    "R-Avg" => $_[1]->{count} && sprintf( "%d", $_[1]->{amount} / $_[1]->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[1]->{amount} / $ptime * 5 ),
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Gained" => $_[1]->{amount},
                    "R-Ticks" => $_[1]->{count},
                    "R-Avg" => $_[1]->{count} && sprintf( "%d", $_[1]->{amount} / $_[1]->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[1]->{amount} / $ptime * 5 ),
                };
            },
        ) if %$eaIn;
        
        #############
        # POWER OUT #
        #############
        
        $PAGE .= $pm->tableRows(
            title => "Power Given to Others",
            header => [ "Name", "R-Targets", "R-Given", "R-Ticks", "R-Avg", "R-Per 5", ],
            data => $powerOut,
            sort => sub ($$) { $_[1]->{amount} <=> $_[0]->{amount} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Casts and Power" ) . " (" . Stasis::Parser->_powerName( $_[1]->{type} ) . ")",
                    "R-Targets" => scalar keys %{$powerOut->{$_[0]}},
                    "R-Given" => $_[1]->{amount},
                    "R-Ticks" => $_[1]->{count},
                    "R-Avg" => $_[1]->{count} && sprintf( "%d", $_[1]->{amount} / $_[1]->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[1]->{amount} / $ptime * 5 ),
                };
            },
            slave => sub {
                my $slave_ptime = $self->{ext}{Presence}->presence( $self->{grouper}->expand($_[0]) );
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Given" => $_[1]->{amount},
                    "R-Ticks" => $_[1]->{count},
                    "R-Avg" => $_[1]->{count} && sprintf( "%d", $_[1]->{amount} / $_[1]->{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[1]->{amount} / $slave_ptime * 5 ),
                };
            },
        ) if %$powerOut;
                
        $PAGE .= $pm->tableEnd;
        $PAGE .= $pm->tabEnd;
    }
    
    #########
    # AURAS #
    #########

    if( ($auraIn && %$auraIn) || ($auraOut && %$auraOut) ) {
        $PAGE .= $pm->tabStart("Auras");
        $PAGE .= $pm->tableStart;

        if( !$do_group ) {
            $PAGE .= $pm->tableRows(
                title => "Auras Gained",
                header => [ "Name", "Type", "R-Uptime", "R-%", "R-Gained", "R-Faded", ],
                data => $auraIn,
                preprocess => sub { $_[1]->{time} = span_sum( $_[1]->{spans}, $pstart, $pend ) },
                sort => sub ($$) { $_[0]->{type} cmp $_[1]->{type} || $_[1]->{time} <=> $_[0]->{time} },
                master => sub {
                    return {
                        "Name" => $pm->spellLink( $_[0], "Auras" ),
                        "Type" => (($_[1]->{type} && lc $_[1]->{type}) || "unknown"),
                        "R-Gained" => $_[1]->{gains},
                        "R-Faded" => $_[1]->{fades},
                        "R-%" => $ptime && sprintf( "%0.1f%%", $_[1]->{time} / $ptime * 100 ),
                        "R-Uptime" => $_[1]->{time} && sprintf( "%02d:%02d", $_[1]->{time}/60, $_[1]->{time}%60 ),
                    };
                },
                slave => sub {
                    return {
                        "Name" => $pm->actorLink( $_[0] ),
                        "Type" => (($_[1]->{type} && lc $_[1]->{type}) || "unknown"),
                        "R-Gained" => $_[1]->{gains},
                        "R-Faded" => $_[1]->{fades},
                        "R-%" => $ptime && sprintf( "%0.1f%%", $_[1]->{time} / $ptime * 100 ),
                        "R-Uptime" => $_[1]->{time} && sprintf( "%02d:%02d", $_[1]->{time}/60, $_[1]->{time}%60 ),
                    };
                }
            ) if %$auraIn;

            $PAGE .= $pm->tableRows(
                title => "Auras Applied to Others",
                header => [ "Name", "Type", "R-Uptime", "R-%", "R-Gained", "R-Faded", ],
                data => $auraOut,
                preprocess => sub {
                    if( @_ == 4 ) {
                        # Slave row
                        $_[1]->{time} = span_sum( $_[1]->{spans}, $self->{ext}{Presence}->presence( $self->{grouper}->expand($_[0]) ) );
                    } else {
                        # Master row.
                        $_[1]->{time} = span_sum( $_[1]->{spans}, $pstart, $pend );
                    }
                },
                sort => sub ($$) { $_[0]->{type} cmp $_[1]->{type} || $_[1]->{time} <=> $_[0]->{time} },
                master => sub {
                    return {
                        "Name" => $pm->spellLink( $_[0], "Auras" ),
                        "Type" => (($_[1]->{type} && lc $_[1]->{type}) || "unknown"),
                        "R-Gained" => $_[1]->{gains},
                        "R-Faded" => $_[1]->{fades},
                        "R-%" => $ptime && sprintf( "%0.1f%%", $_[1]->{time} / $ptime * 100 ),
                        "R-Uptime" => $_[1]->{time} && sprintf( "%02d:%02d", $_[1]->{time}/60, $_[1]->{time}%60 ),
                    };
                },
                slave => sub {
                    my $slave_ptime = $self->{ext}{Presence}->presence( $self->{grouper}->expand($_[0]) );

                    return {
                        "Name" => $pm->actorLink( $_[0] ),
                        "Type" => (($_[1]->{type} && lc $_[1]->{type}) || "unknown"),
                        "R-Gained" => $_[1]->{gains},
                        "R-Faded" => $_[1]->{fades},
                        "R-%" => $slave_ptime && sprintf( "%0.1f%%", $_[1]->{time} / $slave_ptime * 100 ),
                        "R-Uptime" => $_[1]->{time} && sprintf( "%02d:%02d", $_[1]->{time}/60, $_[1]->{time}%60 ),
                    };
                }
            ) if %$auraOut;
        }

        $PAGE .= $pm->tableEnd;
        $PAGE .= $pm->tabEnd;
    }
    
    ##########################
    # DISPELS AND INTERRUPTS #
    ##########################
    
    if( %$interruptIn || %$interruptOut || %$dispelIn || %$dispelOut ) {
        $PAGE .= $pm->tabStart("Dispels and Interrupts");
        $PAGE .= $pm->tableStart;

        ###############
        # DISPELS OUT #
        ###############

        $PAGE .= $pm->tableRows(
            title => "Auras Dispelled on Others",
            header => [ "Name", "R-Targets", "R-Casts", "R-Resists", ],
            data => $dispelOut,
            sort => sub ($$) { $_[1]->{count} <=> $_[0]->{count} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Dispels and Interrupts" ),
                    "R-Targets" => scalar keys %{$dispelOut->{$_[0]}},
                    "R-Casts" => $_[1]->{count},
                    "R-Resists" => $_[1]->{resist},
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Casts" => $_[1]->{count},
                    "R-Resists" => $_[1]->{resist},
                };
            },
        ) if %$dispelOut;
        
        ##############
        # DISPELS IN #
        ##############

        $PAGE .= $pm->tableRows(
            title => "Auras Dispelled by Others",
            header => [ "Name", "R-Sources", "R-Casts", "R-Resists", ],
            data => $dispelIn,
            sort => sub ($$) { $_[1]->{count} <=> $_[0]->{count} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Dispels and Interrupts" ),
                    "R-Sources" => scalar keys %{$dispelIn->{$_[0]}},
                    "R-Casts" => $_[1]->{count},
                    "R-Resists" => $_[1]->{resist},
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Casts" => $_[1]->{count},
                    "R-Resists" => $_[1]->{resist},
                };
            },
        ) if %$dispelIn;
        
        ##################
        # INTERRUPTS OUT #
        ##################

        $PAGE .= $pm->tableRows(
            title => "Casts Interrupted on Others",
            header => [ "Name", "R-Targets", "R-Casts", "", ],
            data => $interruptOut,
            sort => sub ($$) { $_[1]->{count} <=> $_[0]->{count} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Dispels and Interrupts" ),
                    "R-Targets" => scalar keys %{$interruptOut->{$_[0]}},
                    "R-Casts" => $_[1]->{count},
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Casts" => $_[1]->{count},
                };
            },
        ) if %$interruptOut;
        
        #################
        # INTERRUPTS IN #
        #################

        $PAGE .= $pm->tableRows(
            title => "Casts Interrupted by Others",
            header => [ "Name", "R-Sources", "R-Casts", "", ],
            data => $interruptIn,
            sort => sub ($$) { $_[1]->{count} <=> $_[0]->{count} },
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0], "Dispels and Interrupts" ),
                    "R-Sources" => scalar keys %{$interruptIn->{$_[0]}},
                    "R-Casts" => $_[1]->{count},
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0] ),
                    "R-Casts" => $_[1]->{count},
                };
            },
        ) if %$interruptIn;

        $PAGE .= $pm->tableEnd;
        $PAGE .= $pm->tabEnd;
    }
    
    ##########
    # DEATHS #
    ##########

    if( (!$do_group || !$self->{collapse} ) && $self->_keyExists( $self->{ext}{Death}{actors}, @PLAYER ) ) {
        my @header = (
            "Death Time",
            "R-Health",
            "Event",
        );

        # Loop through all deaths.
        my $n = 0;
        my %dnum;
        
        foreach my $player (@PLAYER) {
            foreach my $death (@{$self->{ext}{Death}{actors}{$player}}) {
                my $id = lc $death->{actor};
                $id = $self->{pm}->tameText($id);
                
                if( !$n++ ) {
                    $PAGE .= $pm->tabStart("Deaths");
                    $PAGE .= $pm->tableStart;
                    $PAGE .= $pm->tableHeader("Deaths", @header);
                }
                
                # Get the last line of the autopsy.
                my $lastline = $death->{autopsy}->[-1];
                my $text = Stasis::Parser->toString( 
                    $lastline->{entry}, 
                    sub { $self->{pm}->actorLink( $_[0], 1 ) }, 
                    sub { $self->{pm}->spellLink( $_[0] ) } 
                );

                my $t = $death->{t} - $raidStart;
                $PAGE .= $pm->tableRow(
                    header => \@header,
                    data => {
                        "Death Time" => $death->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                        "R-Health" => $lastline->{hp} || "",
                        "Event" => $text,
                    },
                    type => "master",
                    url => sprintf( "death_%s_%d.html", $id, ++$dnum{ $death->{actor} } ),
                );

                # Print subsequent rows.
                foreach my $line (@{$death->{autopsy}}) {
                    $PAGE .= $pm->tableRow(
                        header => \@header,
                        data => {},
                        type => "slave",
                    );
                }
            }
        }

        if( $n ) {
            $PAGE .= $pm->tableEnd;
            $PAGE .= $pm->tabEnd;
        }
    }
    
    $PAGE .= $pm->jsTab( $eff_on_others && $eff_on_others > 2 * ($dmg_to_all||0) ? "Healing" : $tabs[0]) if @tabs;
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
    my $tab = shift;
    my @PLAYER = @_;
    
    my $spellactor;
    my $spellname;
    my $spellid;

    if( $encoded_spellid =~ /^([A-Za-z0-9]+): (.+)$/ ) {
        if( ! grep $_ eq $1, @PLAYER ) {
            $spellactor = $1;
            $spellname = sprintf( "%s: %s", $pm->actorLink( $1 ), $pm->spellLink( $2, $tab ) );
            $spellid = $2;
        } else {
            $spellactor = $1;
            $spellname = $pm->spellLink( $2, $tab );
            $spellid = $2;
        }
    } else {
        $spellactor = $PLAYER[0];
        $spellname = $pm->spellLink( $encoded_spellid, $tab );
        $spellid = $encoded_spellid;
    }
    
    return ($spellactor, $spellname, $spellid);
}

sub _tidypct {
    my $n = pop;
    
    if( $n ) {
        if( floor($n) == $n ) {
            return sprintf "%d", $n;
        } else {
            return sprintf "%0.1f", $n;
        }
    } else {
        return 0;
    }
}

sub _abilityRows {
    my $self = shift;
    my $eOut = shift;
    
    # We want to make this a two-dimensional spell + target hash
    my %ret;
    
    while( my ($kactor, $vactor) = each(%$eOut) ) {
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Encoded spell name.
            my $espell = "$kactor: $kspell";
            
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # Add a reference to this leaf.
                $ret{ $espell }{ $ktarget } = $vtarget;
            }
        }
    }
    
    return \%ret;
}

sub _targetRows {
    my $self = shift;
    my $eOut = shift;

    # We want to make this a two-dimensional target + spell hash
    my %ret;

    while( my ($kactor, $vactor) = each(%$eOut) ) {
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Encoded spell name.
            my $espell = "$kactor: $kspell";
            
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # Add a reference to this leaf.
                $ret{ $ktarget }{ $espell } = $vtarget;
            }
        }
    }

    return \%ret;
}

sub _cricruglaText {
    my $sdata = pop;
    
    my $swings = ($sdata->{count}||0) - ($sdata->{tickCount}||0);
    return unless $swings;
    
    my $pct = _tidypct(($sdata->{critCount}||0) / $swings * 100 );
    $pct &&= "$pct%";
    
    my @text;
    my @atype = qw(crushing glancing);
    foreach my $type (@atype) {
        push @text, _tidypct( $sdata->{$type} / $swings * 100 ) . "% $type" if $sdata->{$type};
    }
    
    if( @text ) {
        $pct ||= "0%";
    }
    
    return ($pct, @text ? join( ";", @text ) : undef );
}

sub _avoidanceText {
    my $sdata = pop;
    
    my $swings = ($sdata->{count}||0) - ($sdata->{tickCount}||0);
    return unless $swings;
    
    my $pct = _tidypct( 100 - ( ($sdata->{hitCount}||0) + ($sdata->{critCount}||0) ) / $swings * 100 );
    $pct &&= "$pct%";
    
    my @text;
    my @atype = qw(miss dodge parry block absorb resist immune);
    
    foreach my $type (@atype) {
        push @text, _tidypct( $sdata->{$type . "Count"} / $swings * 100 ) . "% total $type" if $sdata->{$type . "Count"};
    }
    
    my $f = 1;
    my @ptype = qw(block resist absorb);
    foreach (@ptype) {
        my $type = $_;
        $type =~ s/^(\w)/"partial" . uc $1/e;
        push @text, "" if $sdata->{$type . "Count"} && @text && $f++ == 1;
        push @text, _tidypct( $sdata->{$type . "Count"} / $sdata->{count} * 100 ) . "% partial ${_} (avg " . int($sdata->{$type . "Total"}/$sdata->{$type . "Count"}) . ")" if $sdata->{$type . "Count"};
    }
    
    if( @text ) {
        $pct ||= "0%";
    }
    
    return ($pct, @text ? join( ";", @text ) : undef );
}

sub _rowDamage {
    my ($self, $sdata, $mnum, $header, $title, $time) = @_;
    
    # We're printing a row based on $sdata.
    my $swings = ($sdata->{count}||0) - ($sdata->{tickCount}||0);
    
    return {
        ($header || "Ability") => $title,
        "R-Total" => $sdata->{total},
        "R-%" => $sdata->{total} && $mnum && _tidypct( $sdata->{total} / $mnum * 100 ),
        "R-DPS" => $sdata->{total} && $time && sprintf( "%d", $sdata->{total}/$time ),
        "R-Time" => $time && sprintf( "%02d:%02d", $time/60, $time%60 ),
        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
        "R-AvHit" => $sdata->{hitCount} && $sdata->{hitTotal} && $self->{pm}->tip( int($sdata->{hitTotal} / $sdata->{hitCount}), sprintf( "Range: %d&ndash;%d", $sdata->{hitMin}, $sdata->{hitMax} ) ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-AvTick" => $sdata->{tickCount} && $sdata->{tickTotal} && $self->{pm}->tip( int($sdata->{tickTotal} / $sdata->{tickCount}), sprintf( "Range: %d&ndash;%d", $sdata->{tickMin}, $sdata->{tickMax} ) ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-AvCrit" => $sdata->{critCount} && $sdata->{critTotal} && $self->{pm}->tip( int($sdata->{critTotal} / $sdata->{critCount}), sprintf( "Range: %d&ndash;%d", $sdata->{critMin}, $sdata->{critMax} ) ),
        "R-% Crit" => $self->{pm}->tip( _cricruglaText($sdata) ),
        "R-Avoid" => $self->{pm}->tip( _avoidanceText($sdata) ),
    };
}

sub _rowHealing {
    my ($self, $sdata, $mnum, $header, $title) = @_;
    
    # We're printing a row based on $sdata.
    return {
        ($header || "Ability") => $title,
        "R-Eff. Heal" => $sdata->{effective}||0,
        "R-%" => $sdata->{effective} && $mnum && _tidypct( $sdata->{effective} / $mnum * 100 ),
        "R-Overheal" => $sdata->{total} && sprintf( "%0.1f%%", ($sdata->{total} - ($sdata->{effective}||0) ) / $sdata->{total} * 100 ),
        "R-Count" => $_[1]->{count}||0,
        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
        "R-AvHit" => $sdata->{hitCount} && $sdata->{hitTotal} && $self->{pm}->tip( int($sdata->{hitTotal} / $sdata->{hitCount}), sprintf( "Range: %d&ndash;%d", $sdata->{hitMin}, $sdata->{hitMax} ) ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-AvTick" => $sdata->{tickCount} && $sdata->{tickTotal} && $self->{pm}->tip( int($sdata->{tickTotal} / $sdata->{tickCount}), sprintf( "Range: %d&ndash;%d", $sdata->{tickMin}, $sdata->{tickMax} ) ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-AvCrit" => $sdata->{critCount} && $sdata->{critTotal} && $self->{pm}->tip( int($sdata->{critTotal} / $sdata->{critCount}), sprintf( "Range: %d&ndash;%d", $sdata->{critMin}, $sdata->{critMax} ) ),
        "R-% Crit" => $sdata->{count} && $sdata->{critCount} && ($sdata->{count} - ($sdata->{tickCount}||0)) && sprintf( "%0.1f%%", ($sdata->{critCount}||0) / ($sdata->{count} - ($sdata->{tickCount}||0)) * 100 ),
    };
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
