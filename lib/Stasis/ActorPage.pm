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
use Stasis::Extension qw(ext_sum ext_copy);

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
    $params{meta} ||= 0;
    
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
    
    my $dpsTime = $self->{ext}{Activity}->activity( actor => \@playpet );
    
    # Total damage, and damage from/to enemies (not enemies of the raid, this means enemies of the actor)
    my $dmg_from_all;
    my $dmg_from_enemies;
    
    my $dmg_to_all;
    my $dmg_to_enemies;
    
    {
        my @raiders = map { $self->{raid}{$_}{class} ? ( $_ ) : () } keys %{$self->{raid}};
        
        my $deInAll = $self->{ext}{Damage}->sum( target => \@PLAYER );
        my $deInFriends = $self->{ext}{Damage}->sum( actor => \@raiders, target => \@PLAYER );
        my $deOutAll = $self->{ext}{Damage}->sum( actor => \@PLAYER );
        my $deOutFriends = $self->{ext}{Damage}->sum( actor => \@PLAYER, target => \@raiders );
        
        $dmg_from_all = $deInAll->{total} || 0;
        $dmg_from_enemies = $dmg_from_all - ($deInFriends->{total} || 0);
        $dmg_to_all = $deOutAll->{total} || 0;
        $dmg_to_enemies = $dmg_to_all - ($deOutFriends->{total} || 0);
    }    
    
    ###############
    # PAGE HEADER #
    ###############
    
    my $displayName = sprintf "%s%s", HTML::Entities::encode_entities($self->{ext}{Index}->actorname($MOB)), @PLAYER > 1 ? " (group)" : "";
    $displayName ||= "Actor";
    $PAGE .= $pm->pageHeader($self->{name}, $displayName, $raidStart);
    $PAGE .= sprintf "<h3 class=\"color%s\">%s</h3>", $self->{raid}{$MOB}{class} || "Mob", $displayName;
    
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
    
    # Pet info
    if( $self->{raid}{$MOB} && $self->{raid}{$MOB}{class} && $self->{raid}{$MOB}{class} eq "Pet" ) {
        foreach my $raider (keys %{$self->{raid}}) {
            if( grep $_ eq $MOB, @{$self->{raid}{$raider}{pets}}) {
                push @summaryRows, "Owner" => $pm->actorLink($raider);
                last;
            }
        }
    }
    
    # Damage Info
    if( $dmg_to_all ) {
        push @summaryRows, (
            "Damage in" => $dmg_from_all . ( $dmg_from_all - $dmg_from_enemies ? " (" . ($dmg_from_all - $dmg_from_enemies) . " was friendly fire)" : "" ),
            "Damage out" => $dmg_to_all . ( $dmg_to_all - $dmg_to_enemies ? " (" . ($dmg_to_all - $dmg_to_enemies) . " was friendly fire)" : "" ),
        );
    }
    
    # DPS Info
    if( $ptime && $dmg_to_enemies && $dpsTime ) {
        push @summaryRows, (
            "DPS activity" => sprintf
            (
                "%02d:%02d (%0.1f%% of presence)",
                $dpsTime/60, 
                $dpsTime%60, 
                $dpsTime/$ptime*100, 
            ),
            "DPS (over presence)" => sprintf( "%d", $dmg_to_enemies/$ptime ),
            "DPS (over activity)" => sprintf( "%d", $dmg_to_enemies/$dpsTime ),
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
    
    my @tabs = ( "Damage", "Healing", "Casts and Gains", "Dispels and Interrupts" );
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
            "R-Crits",
            "R-Ticks",
            "R-Avg Hit",
            "R-Avg Crit",
            "R-Avg Tick",
            "R-CriCruGla %",
            "MDPBARI %",
        );
        
        # Group by ability.
        my @rows = $self->_abilityRows( $self->{ext}{Damage}, @playpet );
        
        # Sort @rows.
        @rows = sort { ($b->{row}{total}||0) <=> ($a->{row}{total}||0) } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { ($b->{row}{total}||0) <=> ($a->{row}{total}||0) } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Damage Out by Ability", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0]->{key}, $pm, @PLAYER);
                    return $self->_rowDamage( $_[0]->{row}, $spellname );
                },
                slave => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[1]->{key}, $pm, @PLAYER);
                    return $self->_rowDamage( $_[0]->{row}, $pm->actorLink( $_[0]->{key} ) );
                }
            );
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
            "R-Crits",
            "R-Ticks",
            "R-DPS",
            "R-Time",
            "",
            "R-CriCruGla %",
            "MDPBARI %",
        );
        
        # Group by target.
        my @rows = $self->_targetRowsOut( $self->{ext}{Damage}, @playpet );
        
        # Sort @rows.
        @rows = sort { ($b->{row}{total}||0) <=> ($a->{row}{total}||0) } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { ($b->{row}{total}||0) <=> ($a->{row}{total}||0) } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Damage Out by Target", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    my $group = $self->{grouper}->group( $_[0]->{key} );
                    my $dpsTime = $self->{ext}{Activity}->activity( actor => \@playpet, target => [ $group ? @{$group->{members}} : ($_[0]->{key}) ] );
                    
                    return $self->_rowDamage( $_[0]->{row}, $pm->actorLink( $_[0]->{key} ), "Target", $dpsTime );
                },
                slave => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0]->{key}, $pm, @PLAYER);
                    return $self->_rowDamage( $_[0]->{row}, $spellname, "Target" );
                }
            );
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
            "R-Crits",
            "R-Ticks",
            "R-DPS",
            "R-Time",
            "",
            "R-CriCruGla %",
            "MDPBARI %",
        );
        
        # Group by source.
        my @rows = $self->_targetRowsIn( $self->{ext}{Damage}, @PLAYER );
        
        # Sort @rows.
        @rows = sort { ($b->{row}{total}||0) <=> ($a->{row}{total}||0) } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { ($b->{row}{total}||0) <=> ($a->{row}{total}||0) } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Damage In by Source", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    my $group = $self->{grouper}->group( $_[0]->{key} );
                    my $dpsTime = $self->{ext}{Activity}->activity( target => \@PLAYER, actor => [ $group ? @{$group->{members}} : ($_[0]->{key}) ] );
                    
                    return $self->_rowDamage( $_[0]->{row}, $pm->actorLink( $_[0]->{key} ), "Source", $dpsTime );
                },
                slave => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0]->{key}, $pm, @PLAYER);
                    return $self->_rowDamage( $_[0]->{row}, $spellname, "Source" );
                }
            );
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
            "R-Crits",
            "R-Ticks",
            "R-Avg Hit",
            "R-Avg Crit",
            "R-Avg Tick",
            "R-Crit %",
            "R-Overheal %",
        );
        
        # Group by ability.
        my @rows = $self->_abilityRows( $self->{ext}{Healing}, @playpet );
        
        # Sort @rows.
        @rows = sort { ($b->{row}{effective}||0) <=> ($a->{row}{effective}||0) } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { ($b->{row}{effective}||0) <=> ($a->{row}{effective}||0) } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Healing Out by Ability", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0]->{key}, $pm, @PLAYER);
                    return $self->_rowHealing( $_[0]->{row}, $spellname );
                },
                slave => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[1]->{key}, $pm, @PLAYER);
                    return $self->_rowHealing( $_[0]->{row}, $pm->actorLink( $_[0]->{key} ) );
                }
            );
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
        my @rows = $self->_targetRowsOut( $self->{ext}{Healing}, @playpet );
        
        # Sum up all effective healing.
        my $eff_on_others;
        
        # Sort @rows.
        @rows = sort { ($b->{row}{effective}||0) <=> ($a->{row}{effective}||0) } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { ($b->{row}{effective}||0) <=> ($a->{row}{effective}||0) } @{$row->{slaves}} ]; 
            $eff_on_others += $row->{row}{effective}||0;
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Healing Out by Target", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    return {
                        "Target" => $pm->actorLink( $_[0]->{key} ),
                        "R-Eff. Heal" => $_[0]->{row}{effective}||0,
                        "R-Count" => $_[0]->{row}{count}||0,
                        "R-Overheal %" => $_[0]->{row}{total} && sprintf( "%0.1f%%", ( $_[0]->{row}{total} - ($_[0]->{row}{effective}||0) ) / $_[0]->{row}{total} * 100 ),
                        "R-Eff. Out %" => $eff_on_others && sprintf( "%0.1f%%", ($_[0]->{row}{effective}||0) / $eff_on_others * 100 ),
                    };
                },
                slave => sub {
                    my ($spellactor, $spellname, $spellid) = $self->_decodespell($_[0]->{key}, $pm, @PLAYER);
                    
                    return {
                        "Target" => $spellname,
                        "R-Eff. Heal" => $_[0]->{row}{effective}||0,
                        "R-Count" => $_[0]->{row}{count}||0,
                        "R-Overheal %" => $_[0]->{row}{total} && sprintf( "%0.1f%%", ( $_[0]->{row}{total} - ($_[0]->{row}{effective}||0) ) / $_[0]->{row}{total} * 100 ),
                        "R-Eff. Out %" => $_[1]->{row}{total} && sprintf( "%0.1f%%", ($_[0]->{row}{effective}||0) / $_[1]->{row}{total} * 100 ),
                    };
                }
            );
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
        my @rows = $self->_targetRowsIn( $self->{ext}{Healing}, @PLAYER );
        
        # Sum up all effective healing.
        my $eff_on_me;
        
        # Sort @rows.
        @rows = sort { ($b->{row}{effective}||0) <=> ($a->{row}{effective}||0) } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { ($b->{row}{effective}||0) <=> ($a->{row}{effective}||0) } @{$row->{slaves}} ];
            $eff_on_me += $row->{row}{effective}||0;
        }
        
        # Print @rows.
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Healing In by Source", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    return {
                        "Source" => $pm->actorLink( $_[0]->{key} ),
                        "R-Eff. Heal" => $_[0]->{row}{effective},
                        "R-Count" => $_[0]->{row}{count},
                        "R-Overheal %" => $_[0]->{row}{total} && sprintf( "%0.1f%%", ( $_[0]->{row}{total} - ($_[0]->{row}{effective}||0) ) / $_[0]->{row}{total} * 100 ),
                        "R-Eff. In %" => $eff_on_me && sprintf( "%0.1f%%", ($_[0]->{row}{effective}||0) / $eff_on_me * 100 ),
                    };
                },
                slave => sub {
                    return {
                        "Source" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname( $_[0]->{key} ) ),
                        "R-Eff. Heal" => $_[0]->{row}{effective},
                        "R-Count" => $_[0]->{row}{count},
                        "R-Overheal %" => $_[0]->{row}{total} && sprintf( "%0.1f%%", ( $_[0]->{row}{total} - ($_[0]->{row}{effective}||0) ) / $_[0]->{row}{total} * 100 ),
                        "R-Eff. In %" => $_[1]->{row}{total} && sprintf( "%0.1f%%", ($_[0]->{row}{effective}||0) / $_[1]->{row}{total} * 100 ),
                    };
                }
            );
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
        my @rows = $self->_castRowsOut( $self->{ext}{Cast}, @PLAYER );
        
        $PAGE .= $pm->tableHeader("Casts", @header);
        $PAGE .= $pm->tableRows(
            header => \@header,
            rows => \@rows,
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) ),
                    "R-Targets" => scalar @{$_[0]->{slaves}},
                    "R-Casts" => $_[0]->{row}{count},
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0]->{key} ),
                    "R-Targets" => "",
                    "R-Casts" => $_[0]->{row}{count},
                };
            }
        );
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
        
        my @rows = $self->_castRowsOut( $self->{ext}{Power}, @PLAYER );
        
        $PAGE .= $pm->tableHeader("Power Gains", @header);
        $PAGE .= $pm->tableRows(
            header => \@header,
            rows => \@rows,
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) . " (" . Stasis::Parser->_powerName( $_[0]->{row}{type} ) . ")" ),
                    "R-Sources" => scalar @{$_[0]->{slaves}},
                    "R-Gained" => $_[0]->{row}{amount},
                    "R-Ticks" => $_[0]->{row}{count},
                    "R-Avg" => $_[0]->{row}{count} && sprintf( "%d", $_[0]->{row}{amount} / $_[0]->{row}{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[0]->{row}{amount} / $ptime * 5 ),
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0]->{key} ),
                    "R-Gained" => $_[0]->{row}{amount},
                    "R-Ticks" => $_[0]->{row}{count},
                    "R-Avg" => $_[0]->{row}{count} && sprintf( "%d", $_[0]->{row}{amount} / $_[0]->{row}{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[0]->{row}{amount} / $ptime * 5 ),
                };
            }
        );
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
        
        my @rows = $self->_castRowsOut( $self->{ext}{ExtraAttack}, @PLAYER );
        
        $PAGE .= $pm->tableHeader("Power Gains", @header) unless $self->_keyExists( $self->{ext}{Power}{actors}, @PLAYER );
        $PAGE .= $pm->tableRows(
            header => \@header,
            rows => \@rows,
            master => sub {
                return {
                    "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) . " (extra attacks)" ),
                    "R-Sources" => scalar @{$_[0]->{slaves}},
                    "R-Gained" => $_[0]->{row}{amount},
                    "R-Ticks" => $_[0]->{row}{count},
                    "R-Avg" => $_[0]->{row}{count} && sprintf( "%d", $_[0]->{row}{amount} / $_[0]->{row}{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[0]->{row}{amount} / $ptime * 5 ),
                };
            },
            slave => sub {
                return {
                    "Name" => $pm->actorLink( $_[0]->{key} ),
                    "R-Gained" => $_[0]->{row}{amount},
                    "R-Ticks" => $_[0]->{row}{count},
                    "R-Avg" => $_[0]->{row}{count} && sprintf( "%d", $_[0]->{row}{amount} / $_[0]->{row}{count} ),
                    "R-Per 5" => $ptime && sprintf( "%0.1f", $_[0]->{row}{amount} / $ptime * 5 ),
                };
            }
        );
    }
    
    #########
    # AURAS #
    #########
    
    if( !$do_group ) {
        my @auraHeader = (
            "Name",
            "Type",
            "R-Uptime",
            "R-%",
            "R-Gained",
            "R-Faded",
        );
        
        # Get aura rows.
        my @rows;
        
        # Get presence for $MOB.
        # my ($mpstart, $mpend, $mptime) = $self->{ext}{Presence}->presence($MOB);
        
        # Get the auras.
        my $auras = $self->{ext}{Aura}->aura( p => $self->{ext}{Presence}{actors}, actor => [$MOB], expand => ["aura"] );
        while( my ($kspell, $vspell) = each(%$auras) ) {
            push @rows, {
                key => $kspell,
                row => $vspell,
            };
        }
        
        # if( $self->{meta} ) {
        #     # Add meta auras.
        #     my %meta = (
        #         "+25% Armor" => [ 16237, 15359 ],
        #         "Faerie Fire" => [ 26993, 27011 ],
        #         "Mangle" => [ 33987, 33983 ],
        #     );
        #     
        #     while( my ($kmeta, $vmeta) = each(%meta) ) {
        #         if( my $atime = $self->{ext}{Aura}->aura( start => $pstart, end => $pend, actor => [$MOB], aura => $vmeta ) ) {
        #             my $n = 0;
        #             my $row = {
        #                 gains => 0,
        #                 fades => 0,
        #                 time => $atime,
        #                 meta => 1,
        #             };
        #             
        #             foreach my $id (@$vmeta) {
        #                 if( my $vaura = $self->{ext}{Aura}{actors}{$MOB}{$id} ) {
        #                     $n ++;
        #                     $row->{gains} += $vaura->{gains};
        #                     $row->{fades} += $vaura->{fades};
        #                     $row->{type} = $vaura->{type};
        #                 }
        #             }
        #             
        #             push @rows, {
        #                 key => $kmeta,
        #                 row => $row,
        #             } if $n > 1;
        #         }
        #         
        #     }
        # }
        
        @rows = sort { $a->{row}{type} cmp $b->{row}{type} || $b->{row}{time} <=> $a->{row}{time} } @rows;
        
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Buffs and Debuffs", @auraHeader);
            foreach my $row (@rows) {
                my $id = lc $row->{key};
                $id = $pm->tameText($id);

                $PAGE .= $pm->tableRow( 
                    header => \@auraHeader,
                    data => {
                        "Name" => ( $row->{row}{meta} ? $row->{key} : $pm->spellLink( $row->{key}, $self->{ext}{Index}->spellname( $row->{key} ) ) ),
                        "Type" => (($row->{row}{type} && lc $row->{row}{type}) || "unknown") . ( $row->{row}{meta} ? " (meta)" : "" ),
                        "R-Gained" => $row->{row}{gains},
                        "R-Faded" => $row->{row}{fades},
                        "R-%" => $ptime && sprintf( "%0.1f%%", $row->{row}{time} / $ptime * 100 ),
                        "R-Uptime" => $row->{row}{time} && sprintf( "%02d:%02d", $row->{row}{time}/60, $row->{row}{time}%60 ),
                    },
                    type => "",
                    name => "aura_$id",
                );
            }
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
    $PAGE .= $pm->tabStart("Dispels and Interrupts");
    $PAGE .= $pm->tableStart;
    
    ###############
    # DISPELS OUT #
    ###############
    
    {
        my @header = (
            "Name",
            "R-Casts",
            "R-Resists",
        );
        
        my @rows = $self->_dispelRowsOut( $self->{ext}{Dispel}, @PLAYER );
        
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Dispels Out", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    return {
                        "Name" => $pm->actorLink( $_[0]->{key} ),
                        "R-Casts" => $_[0]->{row}{count},
                        "R-Resists" => $_[0]->{row}{resist},
                    };
                },
                slave => sub {
                    return {
                        "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) ),
                        "R-Casts" => $_[0]->{row}{count},
                        "R-Resists" => $_[0]->{row}{resist},
                    };
                }
            );
        }
    }
    
    ##############
    # DISPELS IN #
    ##############
    
    {
        my @header = (
            "Name",
            "R-Casts",
            "R-Resists",
        );
        
        my @rows = $self->_dispelRowsIn( $self->{ext}{Dispel}, @PLAYER );
        
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Dispels In", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    return {
                        "Name" => $pm->actorLink( $_[0]->{key} ),
                        "R-Casts" => $_[0]->{row}{count},
                        "R-Resists" => $_[0]->{row}{resist},
                    };
                },
                slave => sub {
                    return {
                        "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) ),
                        "R-Casts" => $_[0]->{row}{count},
                        "R-Resists" => $_[0]->{row}{resist},
                    };
                }
            );
        }
    }
    
    ##################
    # INTERRUPTS OUT #
    ##################
    
    {
        my @header = (
            "Name",
            "R-Interrupts",
            "",
        );
        
        my @rows = $self->_dispelRowsOut( $self->{ext}{Interrupt}, @PLAYER );
        
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Interrupts Out", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    return {
                        "Name" => $pm->actorLink( $_[0]->{key} ),
                        "R-Interrupts" => $_[0]->{row}{count},
                    };
                },
                slave => sub {
                    return {
                        "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) ),
                        "R-Interrupts" => $_[0]->{row}{count},
                    };
                }
            );
        }
    }
    
    #################
    # INTERRUPTS IN #
    #################
    
    {
        my @header = (
            "Name",
            "R-Interrupts",
            "",
        );
        
        my @rows = $self->_dispelRowsIn( $self->{ext}{Interrupt}, @PLAYER );
        
        if( @rows ) {
            $PAGE .= $pm->tableHeader("Interrupts In", @header);
            $PAGE .= $pm->tableRows(
                header => \@header,
                rows => \@rows,
                master => sub {
                    return {
                        "Name" => $pm->actorLink( $_[0]->{key} ),
                        "R-Interrupts" => $_[0]->{row}{count},
                    };
                },
                slave => sub {
                    return {
                        "Name" => $pm->spellLink( $_[0]->{key}, $self->{ext}{Index}->spellname($_[0]->{key}) ),
                        "R-Interrupts" => $_[0]->{row}{count},
                    };
                }
            );
        }
    }
    
    $PAGE .= $pm->tableEnd;
    $PAGE .= $pm->tabEnd;
    
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
                
                my $text = $lastline->{text}||"";
                $text =~ s/\[\[([^\[\]]+?)\]\]/ $pm->actorLink($1, 1) /eg;
                $text =~ s/\{\{([^\{\}]+?)\}\}/ $pm->spellLink($1, $self->{ext}{Index}->spellname($1)) /eg;
                
                my $t = $death->{t} - $raidStart;
                $PAGE .= $pm->tableRow(
                        header => \@header,
                        data => {
                            "Death Time" => $death->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                            "R-Health" => $lastline->{hp} || "",
                            "Event" => $text,
                        },
                        type => "master",
                        name => "death_$id",
                    );

                # Print subsequent rows.
                foreach my $line (@{$death->{autopsy}}) {
                    my $t = ($line->{t}||0) - $raidStart;
                    
                    my $text = $line->{text}||"";
                    $text =~ s/\[\[([^\[\]]+?)\]\]/ $pm->actorLink($1, 1) /eg;
                    $text =~ s/\{\{([^\{\}]+?)\}\}/ $pm->spellLink($1, $self->{ext}{Index}->spellname($1)) /eg;

                    $PAGE .= $pm->tableRow(
                            header => \@header,
                            data => {
                                "Death Time" => $line->{t} && sprintf( "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 ),
                                "R-Health" => $line->{hp} || "",
                                "Event" => $text,
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

sub _targetRowsIn {
    my $self = shift;
    my $ext = shift;
    
    # Get a report.
    my $de = $ext->sum( target => [@_], expand => [ "actor", "spell" ] );

    # Group by ability.
    my @rows;

    while( my ($kactor, $vactor) = each(%$de) ) {
        my $gactor = $self->{grouper}->group($kactor);
        my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;

        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Add the row.
            $self->_rowadd( \@rows, $kactor_use, $kspell, $vspell );
        }
    }

    return @rows;
}

sub _targetRowsOut {
    my $self = shift;
    my $ext = shift;
    
    # Get a report.
    my $de = $ext->sum( actor => [@_], expand => [ "actor", "spell", "target" ] );

    # Group by ability.
    my @rows;

    while( my ($kactor, $vactor) = each(%$de) ) {
        my $gactor = $self->{grouper}->group($kactor);
        my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;

        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Encoded spell name.
            my $espell = "$kactor_use: $kspell";

            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;

                # Add the row.
                $self->_rowadd( \@rows, $ktarget_use, $espell, $vtarget );
            }
        }
    }

    return @rows;
}

sub _abilityRows {
    my $self = shift;
    my $ext = shift;
    
    # Get a report.
    my $de = $ext->sum( actor => [@_], expand => [ "actor", "spell", "target" ] );

    # Group by ability.
    my @rows;

    while( my ($kactor, $vactor) = each(%$de) ) {
        my $gactor = $self->{grouper}->group($kactor);
        my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;

        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Encoded spell name.
            my $espell = "$kactor_use: $kspell";

            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;

                # Add the row.
                $self->_rowadd( \@rows, $espell, $ktarget_use, $vtarget );
            }
        }
    }

    return @rows;
}

sub _castRowsIn {
    my $self = shift;
    my $ext = shift;

    my @rows;
    
    while( my ($kactor, $vactor) = each(%{ $ext->{actors} } ) ) {
        # Actor keys.
        my $gactor = $self->{grouper}->group($kactor);
        my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;
        
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                next unless grep $_ eq $ktarget, @_;

                # Add the row.
                $self->_rowadd( \@rows, $kspell, $kactor_use, $vtarget );
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

sub _castRowsOut {
    my $self = shift;
    my $ext = shift;

    my @rows;
    
    foreach my $kactor (@_) {
        while( my ($kspell, $vspell) = each(%{ $ext->{actors}{$kactor} } ) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;

                # Add the row.
                $self->_rowadd( \@rows, $kspell, $ktarget_use, $vtarget );
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

sub _dispelRowsIn {
    my $self = shift;
    my $ext = shift;

    my @rows;
    
    while( my ($kactor, $vactor) = each(%{ $ext->{actors} } ) ) {
        # Actor keys.
        my $gactor = $self->{grouper}->group($kactor);
        my $kactor_use = $gactor && $_[0] ne $kactor ? $self->{grouper}->captain($gactor) : $kactor;
        
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # Skip targets other than us.
                next unless grep $_ eq $ktarget, @_;
                
                while( my ($kextraspell, $vextraspell) = each (%$vtarget) ) {
                    # Add the row.
                    $self->_rowadd( \@rows, $kactor_use, $kextraspell, $vextraspell );
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

sub _dispelRowsOut {
    my $self = shift;
    my $ext = shift;

    my @rows;
    
    foreach my $kactor (@_) {
        while( my ($kspell, $vspell) = each(%{ $ext->{actors}{$kactor} } ) ) {
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # $vtarget is a spell hash.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;

                while( my ($kextraspell, $vextraspell) = each (%$vtarget) ) {
                    # Add the row.
                    $self->_rowadd( \@rows, $ktarget_use, $kextraspell, $vextraspell );
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
    my $time = shift;
    
    # We're printing a row based on $sdata.
    my $swings = ($sdata->{count}||0) - ($sdata->{tickCount}||0);
    
    return {
        ($header || "Ability") => $title,
        "R-Total" => $sdata->{total},
        "R-DPS" => $sdata->{total} && $time && sprintf( "%d", $sdata->{total}/$time ),
        "R-Time" => $time && sprintf( "%02d:%02d", $time/60, $time%60 ),
        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
        "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{hitMin}, $sdata->{hitMax}, $sdata->{hitTotal} / $sdata->{hitCount} ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{tickMin}, $sdata->{tickMax}, $sdata->{tickTotal} / $sdata->{tickCount} ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{critMin}, $sdata->{critMax}, $sdata->{critTotal} / $sdata->{critCount} ),
        "R-CriCruGla %" => $swings && sprintf( "%s/%s/%s", $self->_tidypct( ($sdata->{critCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{crushing}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{glancing}||0) / $swings * 100 ) ),
        "MDPBARI %" => $swings && sprintf( "%s/%s/%s/%s/%s/%s/%s", $self->_tidypct( ($sdata->{missCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{dodgeCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{parryCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{blockCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{absorbCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{resistCount}||0) / $swings * 100 ), $self->_tidypct( ($sdata->{immuneCount}||0) / $swings * 100 ) ),
    };
}

sub _rowHealing {
    my $self = shift;
    my $sdata = shift;
    my $title = shift;
    my $header = shift;
    
    # We're printing a row based on $sdata.
    
    return {
        ($header || "Ability") => $title,
        "R-Eff. Heal" => $sdata->{effective}||0,
        "R-Overheal %" => $sdata->{total} && sprintf( "%0.1f%%", ($sdata->{total} - ($sdata->{effective}||0) ) / $sdata->{total} * 100 ),
        "R-Hits" => $sdata->{hitCount} && sprintf( "%d", $sdata->{hitCount} ),
        "R-Avg Hit" => $sdata->{hitCount} && $sdata->{hitTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{hitMin}, $sdata->{hitMax}, $sdata->{hitTotal} / $sdata->{hitCount} ),
        "R-Ticks" => $sdata->{tickCount} && sprintf( "%d", $sdata->{tickCount} ),
        "R-Avg Tick" => $sdata->{tickCount} && $sdata->{tickTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{tickMin}, $sdata->{tickMax}, $sdata->{tickTotal} / $sdata->{tickCount} ),
        "R-Crits" => $sdata->{critCount} && sprintf( "%d", $sdata->{critCount} ),
        "R-Avg Crit" => $sdata->{critCount} && $sdata->{critTotal} && sprintf( "<span class=\"tip\" title=\"Range: %d&ndash;%d\">%d</span>", $sdata->{critMin}, $sdata->{critMax}, $sdata->{critTotal} / $sdata->{critCount} ),
        "R-Crit %" => $sdata->{count} && $sdata->{tickCount} && ($sdata->{count} - $sdata->{tickCount} > 0) && sprintf( "%0.1f%%", ($sdata->{critCount}||0) / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
    };
}

sub _rowadd {
    my ($self, $rows, $mkey, $skey, $vtarget) = @_;
    
    # Figure out which row to add this to, or create a new one if appropriate.
    my $row;
    
    foreach (@$rows) {
        if( $_->{key} eq $mkey ) {
            $row = $_;
            last;
        }
    }
    
    if( $row ) {
        # Add to an existing row.
        ext_sum( $row->{row}, $vtarget );
        
        # Either add to an existing slave, or create a new one.
        my $slave;
        foreach (@{$row->{slaves}}) {
            if( $_->{key} eq $skey ) {
                $slave = $_;
                last;
            }
        }
        
        if( $slave ) {
            # Add to an existing slave.
            ext_sum( $slave->{row}, $vtarget );
        } else {
            # Create a new slave.
            push @{$row->{slaves}}, {
                key => $skey,
                row => ext_copy( $vtarget ),
            }
        }
    } else {
        # Create a new row.
        push @$rows, {
            key => $mkey,
            row => ext_copy( $vtarget ),
            slaves => [
                {
                    key => $skey,
                    row => ext_copy( $vtarget ),
                }
            ]
        }
    }
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
