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
    
    my $allheal;
    if( exists $self->{ext}{Healing}{actors}{$PLAYER} ) {
        foreach my $spell (keys %{$self->{ext}{Healing}{actors}{$PLAYER}}) {;
            foreach my $target (keys %{$self->{ext}{Healing}{actors}{$PLAYER}{$spell}}) {
                foreach my $key (keys %{$self->{ext}{Healing}{actors}{$PLAYER}{$spell}{$target}}) {
                    $healing_spell{$spell}{$key} += $self->{ext}{Healing}{actors}{$PLAYER}{$spell}{$target}{$key};
                    $healing_target{$target}{$key} += $self->{ext}{Healing}{actors}{$PLAYER}{$spell}{$target}{$key};
                    $allheal += $self->{ext}{Healing}{actors}{$PLAYER}{$spell}{$target}{total};
                }
            }
        }
    }
    
    ###############
    # PAGE HEADER #
    ###############
    
    $PAGE .= $pm->pageHeader($self->{name}, $raidStart);
    $PAGE .= sprintf "<h3 style=\"color: #%s\">%s</h3>", $pm->classColor( $self->{raid}{$PLAYER}{class} ), $self->{ext}{Index}->actorname($PLAYER);
    
    my $ptime = $self->{ext}{Presence}{actors}{$PLAYER}{end} - $self->{ext}{Presence}{actors}{$PLAYER}{start};
    my $presence_text = sprintf( "Presence: %02d:%02d", $ptime/60, $ptime%60 );
    $presence_text .= sprintf( "<br />DPS time: %02d:%02d (%0.1f%% of presence), %d DPS", 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}/60, 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}%60, 
        $self->{ext}{Activity}{actors}{$PLAYER}{all}{time}/$ptime*100, 
        $dmg_to_mobs/$self->{ext}{Activity}{actors}{$PLAYER}{all}{time} ) 
            if $ptime && $dmg_to_mobs && $self->{ext}{Activity}{actors}{$PLAYER} && $self->{ext}{Activity}{actors}{$PLAYER}{all}{time};
    
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
                "R-Crit",
                "R-Crush",
                "R-Glance",
                "R-Avoid %",
                "M/D/P/B/A/R/I",
            );
    
        my @spellsort = sort {
            $damage_spell{$b}{total} <=> $damage_spell{$a}{total}
        } keys %damage_spell;
    
        $PAGE .= $pm->tableHeader(@damageHeader);
        foreach my $spellkey (@spellsort) {
            # $id is for javascript
            my $id = lc $spellkey;
            $id =~ s/[^\w]/_/g;
        
            # $sdata is totals for the overall spell
            my $sdata;
            $sdata = $damage_spell{$spellkey};
            next unless $sdata->{total};
            
            # In case this is an encoded pet spell, split it into $spellactor, $spellid, and $spellname
            my $spellactor;
            my $spellid;
            my $spellname;
            
            if( $spellkey =~ /^([A-Za-z0-9]+): (.+)$/ ) {
                $spellactor = $1;
                $spellid = $2;
                $spellname = sprintf( "%s: %s", $pm->actorLink( $1, $self->{ext}{Index}->actorname($1), $pm->classColor( $self->{raid}{$1}{class} ) ), $self->{ext}{Index}->spellname($2) );
            } else {
                $spellactor = $PLAYER;
                $spellid = $spellkey;
                $spellname = $self->{ext}{Index}->spellname($spellkey);
            }
            
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
                    "R-Crit" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                    "R-Glance" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", $sdata->{glancing} / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                    "R-Crush" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", $sdata->{crushing} / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                    "R-Avoid %" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", ($sdata->{count} - $sdata->{tickCount} - $sdata->{hitCount} - $sdata->{critCount}) / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                    "M/D/P/B/A/R/I" => sprintf( "%d/%d/%d/%d/%d/%d/%d", $sdata->{missCount}, $sdata->{dodgeCount}, $sdata->{parryCount}, $sdata->{blockCount}, $sdata->{absorbCount}, $sdata->{resistCount}, $sdata->{immuneCount} ),
                },
                type => "master",
                name => "damage_$id",
            );

            foreach my $target (sort { $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$b}{total} <=> $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$a}{total} } keys %{ $self->{ext}{Damage}{actors}{$spellactor}{$spellid} }) {
                # Reassign $sdata to the per-target breakdown
                $sdata = $self->{ext}{Damage}{actors}{$spellactor}{$spellid}{$target};
                next unless $sdata->{total};
            
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
                        "R-Crit" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                        "R-Glance" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", $sdata->{glancing} / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                        "R-Crush" => ($sdata->{count} - $sdata->{tickCount}) && sprintf( "%0.1f%%", $sdata->{crushing} / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                        "R-Avoid %" => sprintf( "%0.1f%%", ($sdata->{count} - $sdata->{tickCount}) && ($sdata->{count} - $sdata->{tickCount} - $sdata->{hitCount} - $sdata->{critCount}) / ($sdata->{count} - $sdata->{tickCount}) * 100 ),
                        "M/D/P/B/A/R/I" => sprintf( "%d/%d/%d/%d/%d/%d/%d", $sdata->{missCount}, $sdata->{dodgeCount}, $sdata->{parryCount}, $sdata->{blockCount}, $sdata->{absorbCount}, $sdata->{resistCount}, $sdata->{immuneCount} ),
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
                "",
                "",
                "",
            );
        
        my @spellnames = sort {
            $healing_spell{$b}{effective} <=> $healing_spell{$a}{effective}
        } keys %healing_spell;
    
        $PAGE .= $pm->tableHeader(@healingHeader);
        foreach my $spellname (@spellnames) {
            my $id = lc $spellname;
            $id =~ s/[^\w]/_/g;
    
            my $sdata;
            $sdata = $healing_spell{$spellname};
            $PAGE .= $pm->tableRow( 
                header => \@healingHeader,
                data => {
                    "Healing Ability" => $self->{ext}{Index}->spellname($spellname),
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
    
            foreach my $target (sort { $self->{ext}{Healing}{actors}{$PLAYER}{$spellname}{$b}{effective} <=> $self->{ext}{Healing}{actors}{$PLAYER}{$spellname}{$a}{effective} } keys %{ $self->{ext}{Healing}{actors}{$PLAYER}{$spellname} }) {
                $sdata = $self->{ext}{Healing}{actors}{$PLAYER}{$spellname}{$target};
                next unless $sdata->{total};
    
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
    
    
    #########
    # CASTS #
    #########
    
    $PAGE .= $pm->tableStart;
    
    if( exists $self->{ext}{Cast}{actors}{$PLAYER} ) {
        my @castHeader = (
                "Cast Name",
                "Target",
                "R-Total",
                "",
                "",
                "",
            );
        
        $PAGE .= $pm->tableHeader(@castHeader);
        foreach my $spellid (keys %{$self->{ext}{Cast}{actors}{$PLAYER}}) {
            my $id = lc $spellid;
            $id =~ s/[^\w]/_/g;
            
            # Get a count of total casts.
            my $total_casts = 0;
            foreach (values %{$self->{ext}{Cast}{actors}{$PLAYER}{$spellid}}) {
                $total_casts += $_;
            }

            my $sdata;
            $PAGE .= $pm->tableRow( 
                header => \@castHeader,
                data => {
                    "Cast Name" => $self->{ext}{Index}->spellname($spellid),
                    "R-Total" => $total_casts,
                    "Target" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $pm->classColor( $self->{raid}{$_}{class} ) ), keys %{ $self->{ext}{Cast}{actors}{$PLAYER}{$spellid} } ),
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
                "Source",
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
            $id =~ s/[^\w]/_/g;

            my $sdata;
            $sdata = $powtot{$powerid};
            $PAGE .= $pm->tableRow( 
                header => \@powerHeader,
                data => {
                    "Gain Name" => sprintf( "%s (%s)", $self->{ext}{Index}->spellname($powerid), $sdata->{type} ),
                    "R-Total" => $sdata->{amount},
                    "Source" => join( ", ", map $pm->actorLink( $_, $self->{ext}{Index}->actorname($_), $pm->classColor( $self->{raid}{$_}{class} ) ), keys %{ $self->{ext}{Power}{actors}{$PLAYER}{$powerid} } ),
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
            $id =~ s/[^\w]/_/g;

            my $sdata;
            $sdata = $self->{ext}{Aura}{actors}{$PLAYER}{$auraid};
            $PAGE .= $pm->tableRow( 
                header => \@auraHeader,
                data => {
                    "Aura Name" => $self->{ext}{Index}->spellname($auraid),
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
    
    ##########
    # FOOTER #
    ##########
    
    $PAGE .= $pm->pageFooter;
}

1;
