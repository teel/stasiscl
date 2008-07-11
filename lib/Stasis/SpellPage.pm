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

package Stasis::SpellPage;

use strict;
use warnings;
use POSIX;
use HTML::Entities;
use Stasis::PageMaker;
use Stasis::ActorPage;
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
    
    bless \%params, $class;
}

sub page {
    my $self = shift;
    my $SPELL = shift;
    
    return unless $SPELL;
    
    my $PAGE;
    my $pm = $self->{pm};
    
    ###############
    # PAGE HEADER #
    ###############
    
    my $displayName = HTML::Entities::encode_entities($self->{ext}{Index}->spellname($SPELL));
    my ($raidStart, $raidEnd, $raidPresence) = $self->{ext}{Presence}->presence();
    $PAGE .= $pm->pageHeader($self->{name}, $displayName, $raidStart);
    $PAGE .= sprintf "<h3 class=\"colorMob\">%s</h3>", $displayName;
    
    my @summaryRows;
    
    # Wowhead link
    if( $SPELL =~ /^\d+$/ ) {
        push @summaryRows, "Wowhead link" => sprintf "<a href=\"http://www.wowhead.com/?spell=%s\" target=\"swswh_%s\">%s &#187;</a>", $SPELL, $SPELL, $displayName;
    }
    
    $PAGE .= $pm->vertBox( "Spell summary", @summaryRows );
    
    my $defaultTab;
    
    $PAGE .= "<br />";
    $PAGE .= $pm->tabBar( "Damage", "Healing", "Casts and Gains" );
    
    ##############
    # DAMAGE OUT #
    ##############
    
    $PAGE .= $pm->tabStart("Damage");
    $PAGE .= $pm->tableStart;
    
    # Get the in/out rows.
    my ($rows_dmgin, $rows_dmgout) = $self->_damageOrHealingRows( $self->{ext}{Damage}, $SPELL );
    my ($rows_healin, $rows_healout) = $self->_damageOrHealingRows( $self->{ext}{Healing}, $SPELL );
    
    {
        my @header = (
            "Source",
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
        
        
        # Sort @rows.
        my @rows = @$rows_dmgout;
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $defaultTab ||= "Damage";
            
            $PAGE .= $pm->tableHeader("Damage Out", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => Stasis::ActorPage->_rowDamage( $row->{row}, $pm->actorLink( $row->{key} ), "Source" ),
                    type => "master",
                    name => "dmgout_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => Stasis::ActorPage->_rowDamage( $slave->{row}, $pm->actorLink( $slave->{key} ), "Source" ),
                        type => "slave",
                        name => "dmgout_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("dmgout_$id");
            }
        }
    }
    
    #############
    # DAMAGE IN #
    #############
    
    {
        my @header = (
            "Target",
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
        
        # Sort @rows.
        my @rows = @$rows_dmgin;
        @rows = sort { $b->{row}{total} <=> $a->{row}{total} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{total} <=> $a->{row}{total} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $defaultTab ||= "Damage";
            
            $PAGE .= $pm->tableHeader("Damage In", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => Stasis::ActorPage->_rowDamage( $row->{row}, $pm->actorLink( $row->{key} ), "Target" ),
                    type => "master",
                    name => "dmgin_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => Stasis::ActorPage->_rowDamage( $slave->{row}, $pm->actorLink( $slave->{key} ), "Target" ),
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
    
    ###############
    # HEALING OUT #
    ###############
    
    $PAGE .= $pm->tabStart("Healing");
    $PAGE .= $pm->tableStart;
    
    {
        my @header = (
            "Source",
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
        
        # Sort @rows.
        my @rows = @$rows_healout;
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $defaultTab ||= "Healing";
        
            $PAGE .= $pm->tableHeader("Healing Out", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => Stasis::ActorPage->_rowHealing( $row->{row}, $pm->actorLink( $row->{key} ), "Source" ),
                    type => "master",
                    name => "healout_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => Stasis::ActorPage->_rowHealing( $slave->{row}, $pm->actorLink( $slave->{key} ), "Source" ),
                        type => "slave",
                        name => "healout_$id",
                    );
                }
                
                # JavaScript close
                $PAGE .= $pm->jsClose("healout_$id");
            }
        }
    }
    
    ##############
    # HEALING IN #
    ##############
    
    {
        my @header = (
            "Target",
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
        
        # Sort @rows.
        my @rows = @$rows_healin;
        @rows = sort { $b->{row}{effective} <=> $a->{row}{effective} } @rows;
        
        # Sort slaves.
        foreach my $row (@rows) {
            $row->{slaves} = [ sort { $b->{row}{effective} <=> $a->{row}{effective} } @{$row->{slaves}} ]; 
        }
        
        # Print @rows.
        if( @rows ) {
            $defaultTab ||= "Healing";
        
        
            $PAGE .= $pm->tableHeader("Healing In", @header);
            foreach my $row (@rows) {
                # JavaScript ID
                my $id = $pm->tameText( $row->{key} );
                
                # Master row
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => Stasis::ActorPage->_rowHealing( $row->{row}, $pm->actorLink( $row->{key} ), "Target" ),
                    type => "master",
                    name => "healin_$id",
                );
                
                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => Stasis::ActorPage->_rowHealing( $slave->{row}, $pm->actorLink( $slave->{key} ), "Target" ),
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
    
    #############
    # CASTS OUT #
    #############
    
    {
        my @header = (
            "Source",
            "R-Casts Out",
            "",
            "",
            "",
            "",
        );
        
        # Group by ability.
        my @rows = $self->_castOrGainRows( $self->{ext}{Cast}, $SPELL );
        
        if( @rows ) {
            $defaultTab ||= "Casts and Gains";
        
        
            $PAGE .= $pm->tableHeader("Casts Out", @header);
            foreach my $row (@rows) {
                my $id = lc $row->{key};
                $id = $pm->tameText($id);

                # Print row.
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Source" => $pm->actorLink( $row->{key} ),
                        "R-Casts Out" => $row->{row}{count},
                    },
                    type => "master",
                    name => "castout_$id",
                );

                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Source" => $pm->actorLink( $slave->{key} ),
                            "R-Casts Out" => $slave->{row}{count},
                        },
                        type => "slave",
                        name => "castout_$id",
                    );
                }

                # JavaScript close
                $PAGE .= $pm->jsClose("castout_$id");
            }
        }
    }
    
    ############
    # CASTS IN #
    ############
    
    {
        my @header = (
            "Target",
            "R-Casts In",
            "",
            "",
            "",
            "",
        );
        
        # Group by ability.
        my @rows = $self->_castOrGainRows( $self->{ext}{Cast}, $SPELL, 1 );
        
        if( @rows ) {
            $defaultTab ||= "Casts and Gains";
        
        
            $PAGE .= $pm->tableHeader("Casts In", @header);
            foreach my $row (@rows) {
                my $id = lc $row->{key};
                $id = $pm->tameText($id);

                # Print row.
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Target" => $pm->actorLink( $row->{key} ),
                        "R-Casts In" => $row->{row}{count},
                    },
                    type => "master",
                    name => "castin_$id",
                );

                # Slave rows
                foreach my $slave (@{ $row->{slaves} }) {
                    $PAGE .= $pm->tableRow( 
                        header => \@header,
                        data => {
                            "Target" => $pm->actorLink( $slave->{key} ),
                            "R-Casts In" => $slave->{row}{count},
                        },
                        type => "slave",
                        name => "castin_$id",
                    );
                }

                # JavaScript close
                $PAGE .= $pm->jsClose("castin_$id");
            }
        }
    }
    
    #########
    # POWER #
    #########
    
    my $powerHeaderPrinted;
    
    {
        my @header = (
            "Name",
            "R-Gained",
            "R-Ticks",
            "R-Avg",
            "R-Per 5",
            "",
        );
        
        # Group by ability.
        my @rows = $self->_castOrGainRows( $self->{ext}{Power}, $SPELL );
        
        if( @rows ) {
            $defaultTab ||= "Casts and Gains";
            $powerHeaderPrinted = 1;
        
            $PAGE .= $pm->tableHeader("Power Gains", @header);
            foreach my $row (@rows) {
                my $id = lc $row->{key};
                $id = $pm->tameText($id);
                
                my $ptime = $self->{ext}{Presence}->presence( $row->{key} );

                # Print row.
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Name" => $pm->actorLink( $row->{key} ),
                        "R-Targets" => scalar @{$row->{slaves}},
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
                            "R-Targets" => "",
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
    }
    
    #################
    # EXTRA ATTACKS #
    #################
    
    {
        my @header = (
            "Name",
            "R-Gained",
            "R-Ticks",
            "R-Avg",
            "R-Per 5",
            "",
        );
        
        # Group by ability.
        my @rows = $self->_castOrGainRows( $self->{ext}{ExtraAttack}, $SPELL );
        
        if( @rows ) {
            $defaultTab ||= "Casts and Gains";
        
            $PAGE .= $pm->tableHeader("Power Gains", @header) unless $powerHeaderPrinted;
            foreach my $row (@rows) {
                my $id = lc $row->{key};
                $id = $pm->tameText($id);
                
                my $ptime = $self->{ext}{Presence}->presence( $row->{key} );

                # Print row.
                $PAGE .= $pm->tableRow( 
                    header => \@header,
                    data => {
                        "Name" => $pm->actorLink( $row->{key} ),
                        "R-Targets" => scalar @{$row->{slaves}},
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
                            "R-Targets" => "",
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
    }
    
    #########
    # AURAS #
    #########
    
    {
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
        
        while( my ($kactor, $vactor) = each(%{ $self->{ext}{Aura}{actors}}) ) {
            while( my ($kspell, $vspell) = each(%$vactor) ) {
                # Focus on our spell.
                next unless $kspell eq $SPELL;

                push @rows, {
                    key => $kactor,
                    row => $vspell,
                };
            }
        }
        
        @rows = sort { $a->{row}{type} cmp $b->{row}{type} || $b->{row}{time} <=> $a->{row}{time} } @rows;
        
        if( @rows ) {
            $defaultTab ||= "Casts and Gains";
            
            $PAGE .= $pm->tableHeader("Buffs and Debuffs", @auraHeader);
            foreach my $row (@rows) {
                my $id = lc $row->{key};
                $id = $pm->tameText($id);
                
                my $ptime = $self->{ext}{Presence}->presence($row->{key});

                $PAGE .= $pm->tableRow( 
                    header => \@auraHeader,
                    data => {
                        "Name" => $pm->actorLink( $row->{key}, 1 ),
                        "Type" => ($row->{row}{type} && lc $row->{row}{type}) || "unknown",
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
    
    $PAGE .= $pm->jsTab($defaultTab||"Damage");
    $PAGE .= $pm->tabBarEnd;
    
    $PAGE .= $pm->pageFooter;
    
    return $PAGE;
}

sub _addDamageOrHealingRow {
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
        Stasis::ActorPage->_sum( $row->{row}, $vtarget );
        
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
            Stasis::ActorPage->_sum( $slave->{row}, $vtarget );
        } else {
            # Create a new slave.
            push @{$row->{slaves}}, {
                key => $skey,
                row => Stasis::ActorPage->_copy( $vtarget ),
            }
        }
    } else {
        # Create a new row.
        push @$rows, {
            key => $mkey,
            row => Stasis::ActorPage->_copy( $vtarget ),
            slaves => [
                {
                    key => $skey,
                    row => Stasis::ActorPage->_copy( $vtarget ),
                }
            ]
        }
    }
}

sub _damageOrHealingRows {
    my $self = shift;
    my $ext = shift;
    my $spell = shift;
    my $in = shift;
    
    # Groups of rows.
    my @rows_in;
    my @rows_out;
    
    while( my ($kactor, $vactor) = each(%{ $ext->{actors}}) ) {
        my $gactor;
        my $kactor_use;
        
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Focus on our spell.
            next unless $kspell eq $spell;
            
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                if( !$kactor_use ) {
                    $gactor = $self->{grouper}->group($kactor);
                    $kactor_use = $gactor ? $self->{grouper}->captain($gactor) : $kactor;
                }
                
                # Figure out the key for this target.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;
                
                $self->_addDamageOrHealingRow( \@rows_in, $ktarget_use, $kactor_use, $vtarget );
                $self->_addDamageOrHealingRow( \@rows_out, $kactor_use, $ktarget_use, $vtarget );
            }
        }
    }
    
    return (\@rows_in, \@rows_out);
}

sub _castOrGainRows {
    my $self = shift;
    my $ext = shift;
    my $spell = shift;
    my $in = shift;

    my @rows;
    
    while( my ($kactor, $vactor) = each(%{ $ext->{actors}}) ) {
        my $gactor;
        my $kactor_use;
        
        while( my ($kspell, $vspell) = each(%$vactor) ) {
            # Focus on our spell.
            next unless $kspell eq $spell;
            
            while( my ($ktarget, $vtarget) = each(%$vspell) ) {
                # Figure out the key for this actor.
                if( !$kactor_use ) {
                    $gactor = $self->{grouper}->group($kactor);
                    $kactor_use = $gactor ? $self->{grouper}->captain($gactor) : $kactor;
                }
                
                # Figure out what the key for this target is.
                my $gtarget = $self->{grouper}->group($ktarget);
                my $ktarget_use = $gtarget ? $self->{grouper}->captain($gtarget) : $ktarget;
                
                # Figure out which key to use for the master row and the slave row.
                my $mkey = $in ? $ktarget_use : $kactor_use;
                my $skey = $in ? $kactor_use : $ktarget_use;
                
                # Figure out which row to add this to, or create a new one if appropriate.
                my $row;

                foreach (@rows) {
                    if( $_->{key} eq $mkey ) {
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
                        if( $_->{key} eq $skey ) {
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
                            key => $skey,
                            row => Stasis::ActorPage->_copy($vtarget),
                        }
                    }
                } else {
                    # Create a new row.
                    push @rows, {
                        key => $mkey,
                        row => Stasis::ActorPage->_copy($vtarget),
                        slaves => [
                            {
                                key => $skey,
                                row => Stasis::ActorPage->_copy($vtarget),
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

1;
