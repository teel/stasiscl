package Stasis::ActorPage;

use strict;
use warnings;
use POSIX;
use Stasis::PageMaker;
use Data::Dumper;
use Storable qw(dclone);
use Carp;

sub new {
    my $class = shift;
    
    my $actors = shift;
    my $raid = shift;
    my $actions = shift;
    my $boss = shift;
    
    bless {
        actors => dclone($actors),
        raid => dclone($raid),
        actions => $actions,
        boss => $boss,
    }, $class;
}

sub page {
    my $PAGE;
    
    my $self = shift;
    my $PLAYER = shift;
    my %actors = %{$self->{actors}};
    my %raid = %{$self->{raid}};
    my @actions = @{$self->{actions}};
    
    $self->_mergePets($PLAYER);
    
    my %damtot = $self->_damageSpells($PLAYER);
    my %healtot = $self->_healingSpells($PLAYER);
    my %powtot = $self->_powerGains($PLAYER);
    my %casttot = $self->_mCasts($PLAYER);
    
    my $page = Stasis::PageMaker->new;
    
    $PAGE .= $page->pageHeader($self->{boss}, $actions[0]->{t});
    
    my $alldmg;
    foreach my $target (keys %{$actors{$PLAYER}{damage}{targets}}) {
        # skip friendlies
        next if $raid{$target}{class} && $raid{$target}{class} ne "Mob";
        
        foreach my $spell (keys %{$actors{$PLAYER}{damage}{targets}{$target}{spells}}) {
            $alldmg += $actors{$PLAYER}{damage}{targets}{$target}{spells}{$spell}{damage};
        }
    }
    
    $PAGE .= sprintf "<h3 style=\"color: #%s\">%s</h3>", $page->classColor( $raid{$PLAYER}{class} ), $PLAYER;
    
    my $ptime = $actors{$PLAYER}{presence}{end} - $actors{$PLAYER}{presence}{start};
    my $presence_text = sprintf( "Presence: %02d:%02d", $ptime/60, $ptime%60 );
    $presence_text .= sprintf( "<br />DPS time: %02d:%02d (%0.1f%% of presence), %d DPS", $actors{$PLAYER}{damage}{dpstime}/60, $actors{$PLAYER}{damage}{dpstime}%60, $actors{$PLAYER}{damage}{dpstime}/$ptime*100, $alldmg/$actors{$PLAYER}{damage}{dpstime} ) if $actors{$PLAYER}{damage}{dpstime};
    
    $PAGE .= $page->textBox( $presence_text, "Actor Information" );
    
    $PAGE .= "<br />";
    
    $PAGE .= $page->tableStart;
    
    ##########
    # DAMAGE #
    ##########
    
    if( keys %damtot ) {
    
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
                "R-Miss %",
                "M/D/P/B/A/R",
            );
    
        my @spellnames = sort {
            $damtot{$b}{damage} <=> $damtot{$a}{damage}
        } keys %damtot;
    
        $PAGE .= $page->tableHeader(@damageHeader);
        foreach my $spellname (@spellnames) {
            my $id = lc $spellname;
            $id =~ s/[^\w]/_/g;
        
            my $sdata;
            $sdata = $damtot{$spellname};
            
            next unless $sdata->{damage};
            
            my $displayspellname = $spellname;
            if( $displayspellname =~ /^([A-Za-z]+): (.+)$/ ) {
                $displayspellname = sprintf "%s: %s", $page->actorLink( $1, $page->classColor( $raid{$1}{class} )), $2;
            }
            
            $PAGE .= $page->tableRow( 
                header => \@damageHeader,
                data => {
                    "Damaging Ability" => $displayspellname,
                    "R-Total" => $sdata->{damage},
                    "R-Hits" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitCount} : "",
                    "R-Avg Hit" => $sdata->{hitCount} ? sprintf "%d (%d&ndash;%d)", $sdata->{hitDamage} / $sdata->{hitCount}, $sdata->{size}{hitMin}, $sdata->{size}{hitMax} : "",
                    "R-Ticks" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickCount} : "",
                    "R-Avg Tick" => $sdata->{tickCount} ? sprintf "%d (%d&ndash;%d)", $sdata->{tickDamage} / $sdata->{tickCount}, $sdata->{size}{tickMin}, $sdata->{size}{tickMax} : "",
                    "R-Crits" => $sdata->{critCount} ? sprintf "%d", $sdata->{critCount} : "",
                    "R-Avg Crit" => $sdata->{critCount} ? sprintf "%d (%d&ndash;%d)", $sdata->{critDamage} / $sdata->{critCount}, $sdata->{size}{critMin}, $sdata->{size}{critMax} : "",
                    "R-Crit" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                    "R-Glance" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{mods}{glanceCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                    "R-Crush" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{mods}{crushCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                    "R-Miss %" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", ($sdata->{count} - $sdata->{tickCount} - $sdata->{hitCount} - $sdata->{critCount}) / ($sdata->{count} - $sdata->{tickCount}) * 100, $sdata->{missCount} : "",
                    "M/D/P/B/A/R" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%d/%d/%d/%d/%d/%d", $sdata->{missCount}, $sdata->{dodgeCount}, $sdata->{parryCount}, $sdata->{blockCount}, $sdata->{absorbCount}, $sdata->{resistCount} : "",
                },
                type => "master",
                name => "damage_$id",
            );

            foreach my $target (sort { $actors{$PLAYER}{damage}{targets}{$b}{spells}{$spellname}{damage} <=> $actors{$PLAYER}{damage}{targets}{$a}{spells}{$spellname}{damage} } keys %{ $actors{$PLAYER}{damage}{targets} }) {
                $sdata = $actors{$PLAYER}{damage}{targets}{$target}{spells}{$spellname};
                next unless $sdata->{damage};
            
                $PAGE .= $page->tableRow( 
                    header => \@damageHeader,
                    data => {
                        "Damaging Ability" => $page->actorLink( $target, $page->classColor( $raid{$target}{class} ) ),
                        "R-Total" => $sdata->{damage},
                        "R-Hits" => $sdata->{hitCount} ? sprintf "%d", $sdata->{hitCount} : "",
                        "R-Avg Hit" => $sdata->{hitCount} ? sprintf "%d (%d&ndash;%d)", $sdata->{hitDamage} / $sdata->{hitCount}, $sdata->{size}{hitMin}, $sdata->{size}{hitMax} : "",
                        "R-Ticks" => $sdata->{tickCount} ? sprintf "%d", $sdata->{tickCount} : "",
                        "R-Avg Tick" => $sdata->{tickCount} ? sprintf "%d (%d&ndash;%d)", $sdata->{tickDamage} / $sdata->{tickCount}, $sdata->{size}{tickMin}, $sdata->{size}{tickMax} : "",
                        "R-Crits" => $sdata->{critCount} ? sprintf "%d", $sdata->{critCount} : "",
                        "R-Avg Crit" => $sdata->{critCount} ? sprintf "%d (%d&ndash;%d)", $sdata->{critDamage} / $sdata->{critCount}, $sdata->{size}{critMin}, $sdata->{size}{critMax} : "",
                        "R-Crit" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{critCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                        "R-Glance" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{mods}{glanceCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                        "R-Crush" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", $sdata->{mods}{crushCount} / ($sdata->{count} - $sdata->{tickCount}) * 100 : "",
                        "R-Miss %" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%0.1f%%", ($sdata->{count} - $sdata->{tickCount} - $sdata->{hitCount} - $sdata->{critCount}) / ($sdata->{count} - $sdata->{tickCount}) * 100, $sdata->{missCount} : "",
                        "M/D/P/B/A/R" => $sdata->{count} - $sdata->{tickCount} > 0 ? sprintf "%d/%d/%d/%d/%d/%d", $sdata->{missCount}, $sdata->{dodgeCount}, $sdata->{parryCount}, $sdata->{blockCount}, $sdata->{absorbCount}, $sdata->{resistCount} : "",
                    },
                    type => "slave",
                    name => "damage_$id",
                );
            }

            $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('damage_$id');
</script>
END
        }
    
    }
    
    ###########
    # HEALING #
    ###########
    
    if( keys %healtot ) {

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
            $healtot{$b}{effective} <=> $healtot{$a}{effective}
        } keys %healtot;

        $PAGE .= $page->tableHeader(@healingHeader);
        foreach my $spellname (@spellnames) {
            my $id = lc $spellname;
            $id =~ s/[^\w]/_/g;

            my $sdata;
            $sdata = $healtot{$spellname};
            $PAGE .= $page->tableRow( 
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

            foreach my $target (sort { $actors{$PLAYER}{healing}{targets}{$b}{spells}{$spellname}{effective} <=> $actors{$PLAYER}{healing}{targets}{$a}{spells}{$spellname}{effective} } keys %{ $actors{$PLAYER}{healing}{targets} }) {
                $sdata = $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spellname};
                next unless $sdata->{total};

                $PAGE .= $page->tableRow( 
                    header => \@healingHeader,
                    data => {
                        "Healing Ability" => $page->actorLink( $target, $page->classColor( $raid{$target}{class} ) ),
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

            $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('healing_$id');
</script>   

END
        }

    }
    
    $PAGE .= $page->tableEnd;
    
    
    ##########
    # DEATHS #
    ##########

    if( $actors{$PLAYER}{deaths} ) {
        $PAGE .= $page->tableStart;

        my @header = (
                "Death Time",
                "R-Health",
                "Event",
            );

        $PAGE .= $page->tableHeader(@header);

        # Loop through all deaths.
        foreach my $death (@{$actors{$PLAYER}{deaths}}) {
            my $id = $death->{t};
            $id =~ s/[^\w]/_/g;

            # Get the last line of the autopsy.
            my $lastline = pop @{$death->{autopsy}};
            push @{$death->{autopsy}}, $lastline;

            # Print the front row.
            my $t = $death->{t} - $actors{$PLAYER}{presence}{start};
            $PAGE .= $page->tableRow(
                    header => \@header,
                    data => {
                        "Death Time" => $death->{t} ? sprintf "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 : "",
                        "R-Health" => $lastline->{hp} ? $lastline->{hp} : "",
                        "Event" => $lastline->{text} ? $lastline->{text} : "",
                    },
                    type => "master",
                    name => "death_$id",
                );

            # Print subsequent rows.
            foreach my $line (@{$death->{autopsy}}) {
                my $t = $line->{t} - $actors{$PLAYER}{presence}{start};

                $PAGE .= $page->tableRow(
                        header => \@header,
                        data => {
                            "Death Time" => $line->{t} ? sprintf "%02d:%02d.%03d", $t/60, $t%60, ($t-floor($t))*1000 : "",
                            "R-Health" => $line->{hp} ? $line->{hp} : 0,
                            "Event" => $line->{text} ? $line->{text} : "",
                        },
                        type => "slave",
                        name => "death_$id",
                    );
            }

            $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('death_$id');
</script>
END
        }

        $PAGE .= $page->tableEnd;
    }
    
    $PAGE .= $page->tableStart;
    
    #########
    # CASTS #
    #########
    
    if( keys %casttot ) {
        my @castHeader = (
                "Cast Name",
                "Targets",
                "R-Total",
                "",
                "",
                "",
            );
        
        my @castnames = sort keys %casttot;
        
        $PAGE .= $page->tableHeader(@castHeader);
        foreach my $castname (@castnames) {
            my $id = lc $castname;
            $id =~ s/[^\w]/_/g;

            my $sdata;
            $sdata = $casttot{$castname};
            $PAGE .= $page->tableRow( 
                header => \@castHeader,
                data => {
                    "Cast Name" => $castname,
                    "R-Total" => $casttot{$castname},
                    "Targets" => join( ", ", map $page->actorLink( $_, $page->classColor( $raid{$_}{class} ) ), keys %{ $actors{$PLAYER}{casts}{spells}{$castname}{targets} } ),
                },
                type => "",
                name => "cast_$id",
            );
        }
    }
    
    #########
    # POWER #
    #########
    
    if( keys %powtot ) {
        my @powerHeader = (
                "Gain Name",
                "Source",
                "R-Total",
                "R-Ticks",
                "R-Avg",
                "R-Per 5",
            );
        
        my @powernames = sort {
            ($powtot{$a}{type} cmp $powtot{$b}{type}) || ($powtot{$b}{amount} <=> $powtot{$a}{amount})
        } keys %powtot;
        
        $PAGE .= $page->tableHeader(@powerHeader);
        foreach my $powername (@powernames) {
            my $id = lc $powername;
            $id =~ s/[^\w]/_/g;

            my $sdata;
            $sdata = $powtot{$powername};
            $PAGE .= $page->tableRow( 
                header => \@powerHeader,
                data => {
                    "Gain Name" => sprintf( "%s (%s)", $powername, $sdata->{type} ),
                    "R-Total" => $sdata->{amount},
                    "Source" => join( ", ", map $page->actorLink( $_, $page->classColor( $raid{$_}{class} ) ), keys %{ $actors{$PLAYER}{power}{spells}{$powername}{sources} } ),
                    "R-Ticks" => $sdata->{count},
                    "R-Avg" => $sdata->{count} ? sprintf "%d", $sdata->{amount} / $sdata->{count} : "",
                    "R-Per 5" => ( $actors{$PLAYER}{presence}{end} - $actors{$PLAYER}{presence}{start} ) ? sprintf "%0.1f", $sdata->{amount} / ($actors{$PLAYER}{presence}{end}-$actors{$PLAYER}{presence}{start}) * 5 : "",
                },
                type => "",
                name => "power_$id",
            );
        }
    }
    
    #########
    # AURAS #
    #########
    
    if( keys %{$actors{$PLAYER}{auras}} ) {
        my @auraHeader = (
                "Aura Name",
                "Type",
                "R-Uptime",
                "R-%",
                "R-Gained",
                "R-Faded",
            );

        my @auranames = sort {
            ($actors{$PLAYER}{auras}{$a}{type} cmp $actors{$PLAYER}{auras}{$b}{type}) || ($actors{$PLAYER}{auras}{$b}{uptime} <=> $actors{$PLAYER}{auras}{$a}{uptime})
        } keys %{$actors{$PLAYER}{auras}};

        $PAGE .= $page->tableHeader(@auraHeader);
        foreach my $auraname (@auranames) {
            my $id = lc $auraname;
            $id =~ s/[^\w]/_/g;

            my $sdata;
            $sdata = $actors{$PLAYER}{auras}{$auraname};
            $PAGE .= $page->tableRow( 
                header => \@auraHeader,
                data => {
                    "Aura Name" => $auraname,
                    "Type" => $sdata->{type} ? $sdata->{type} : "unknown",
                    "R-Gained" => $sdata->{gains},
                    "R-Faded" => $sdata->{fades},
                    "R-%" => ( $actors{$PLAYER}{presence}{end} - $actors{$PLAYER}{presence}{start} ) ? sprintf "%0.1f%%", $sdata->{uptime} / ($actors{$PLAYER}{presence}{end}-$actors{$PLAYER}{presence}{start}) * 100 : "",
                    "R-Uptime" => $sdata->{uptime} ? sprintf "%02d:%02d", $sdata->{uptime}/60, $sdata->{uptime}%60 : "",
                },
                type => "",
                name => "aura_$id",
            );
        }
    }
    
    $PAGE .= $page->tableEnd;
    
    $PAGE .= $page->tableStart;

    ######################
    # DAMAGE OUT TARGETS #
    ######################
    
    if( keys %{ $actors{$PLAYER}{damage}{targets} } ) {
        my @header = (
                "Damage Out",
                "R-Total",
                "R-DPS",
                "Time",
                "R-Time % (Presence)",
                "R-Time % (DPS Time)",
            );
        
        my %targetdmg;
        foreach my $target (keys %{ $actors{$PLAYER}{damage}{targets} }) {
            foreach my $spell (keys %{ $actors{$PLAYER}{damage}{targets}{$target}{spells} }) {
                $targetdmg{$target} += $actors{$PLAYER}{damage}{targets}{$target}{spells}{$spell}{damage};
            }
        }

        my @targets = sort {
            $targetdmg{$b} <=> $targetdmg{$a}
        } keys %targetdmg;

        if( @targets ) {
            $PAGE .= $page->tableHeader(@header);
            foreach my $target (@targets) {
                my $id = lc $target;
                $id =~ s/[^\w]/_/g;

                my $sdata;
                $sdata = $actors{$PLAYER}{damage}{targets}{$target};
                $PAGE .= $page->tableRow( 
                    header => \@header,
                    data => {
                        "Damage Out" => $page->actorLink( $target, $page->classColor( $raid{$target}{class} ) ),
                        "R-Total" => $targetdmg{$target},
                        "R-DPS" => $sdata->{dpstime} ? sprintf "%d", $targetdmg{$target} / $sdata->{dpstime} : "",
                        "Time" => $sdata->{dpstime} ? sprintf "%02d:%02d", $sdata->{dpstime}/60, $sdata->{dpstime}%60 : "",
                        "R-Time % (Presence)" => ($actors{$PLAYER}{presence}{end} - $actors{$PLAYER}{presence}{start} ) ? sprintf "%0.1f%%", $sdata->{dpstime} / ($actors{$PLAYER}{presence}{end} - $actors{$PLAYER}{presence}{start} ) * 100: "",
                        "R-Time % (DPS Time)" => $actors{$PLAYER}{damage}{dpstime} ? sprintf "%0.1f%%", $sdata->{dpstime} / $actors{$PLAYER}{damage}{dpstime} * 100 : "",
                    },
                    type => "master",
                    name => "dmgout_$id",
                );
            
                my @spellnames = sort {
                    $actors{$PLAYER}{damage}{targets}{$target}{spells}{$b}{damage} <=> $actors{$PLAYER}{damage}{targets}{$target}{spells}{$a}{damage}
                } keys %{$actors{$PLAYER}{damage}{targets}{$target}{spells}};
            
                foreach my $spellname (@spellnames) {
                    $sdata = $actors{$PLAYER}{damage}{targets}{$target}{spells}{$spellname};
                    next unless $sdata->{damage};
                
                    $PAGE .= $page->tableRow( 
                        header => \@header,
                        data => {
                            "Damage Out" => $spellname,
                            "R-Total" => $sdata->{damage},
                        },
                        type => "slave",
                        name => "dmgout_$id",
                    );
                }
            
                $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('dmgout_$id');
</script>
END
            }
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
        foreach my $actor (keys %actors) {
            next unless $actors{$actor}{damage}{targets}{$PLAYER}{spells};

            foreach my $spell (keys %{ $actors{$actor}{damage}{targets}{$PLAYER}{spells} }) {
                $sourcedmg{$actor} += $actors{$actor}{damage}{targets}{$PLAYER}{spells}{$spell}{damage} if $actors{$actor}{damage}{targets}{$PLAYER}{spells}{$spell}{damage};
            }
        }

        my @sources = sort {
            $sourcedmg{$b} <=> $sourcedmg{$a}
        } keys %sourcedmg;

        if( @sources ) {
            $PAGE .= $page->tableHeader(@header);
            foreach my $source (@sources) {
                my $id = lc $source;
                $id =~ s/[^\w]/_/g;

                my $sdata;
                $sdata = $actors{$source}{damage}{targets}{$PLAYER};
                $PAGE .= $page->tableRow( 
                    header => \@header,
                    data => {
                        "Damage In" => $page->actorLink( $source, $page->classColor( $raid{$source}{class} ) ),
                        "R-Total" => $sourcedmg{$source},
                        "R-DPS" => $sdata->{dpstime} ? sprintf "%d", $sourcedmg{$source} / $sdata->{dpstime} : "",
                        "Time" => $sdata->{dpstime} ? sprintf "%02d:%02d", $sdata->{dpstime}/60, $sdata->{dpstime}%60 : "",
                        "R-Time % (Presence)" => ($actors{$source}{presence}{end} - $actors{$source}{presence}{start} ) ? sprintf "%0.1f%%", $sdata->{dpstime} / ($actors{$source}{presence}{end} - $actors{$source}{presence}{start} ) * 100: "",
                        "R-Time % (DPS Time)" => $actors{$source}{damage}{dpstime} ? sprintf "%0.1f%%", $sdata->{dpstime} / $actors{$source}{damage}{dpstime} * 100 : "",
                    },
                    type => "master",
                    name => "dmgin_$id",
                );
            
                my @spellnames = sort {
                    $actors{$source}{damage}{targets}{$PLAYER}{spells}{$b}{damage} <=> $actors{$source}{damage}{targets}{$PLAYER}{spells}{$a}{damage}
                } keys %{$actors{$source}{damage}{targets}{$PLAYER}{spells}};
            
                foreach my $spellname (@spellnames) {
                    $sdata = $actors{$source}{damage}{targets}{$PLAYER}{spells}{$spellname};
                    next unless $sdata->{damage};
                
                    $PAGE .= $page->tableRow( 
                        header => \@header,
                        data => {
                            "Damage In" => $spellname,
                            "R-Total" => $sdata->{damage},
                        },
                        type => "slave",
                        name => "dmgin_$id",
                    );
                }
            
                $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('dmgin_$id');
</script>
END
            }
        }
    }
    
    
    #######################
    # HEALING OUT TARGETS #
    #######################
    
    if( keys %{ $actors{$PLAYER}{healing}{targets} } ) {
        my @header = (
                "Heals Out",
                "R-Eff. Heal",
                "R-Hits",
                "R-Eff. Out %",
                "R-Overheal %",
                "",
            );
        
        my %targetheal;
        my %totalheal;
        foreach my $target (keys %{ $actors{$PLAYER}{healing}{targets} }) {
            foreach my $spell (keys %{ $actors{$PLAYER}{healing}{targets}{$target}{spells} }) {
                $targetheal{$target}{effective} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{effective};
                $targetheal{$target}{total} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{total};
                $targetheal{$target}{hits} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{hitCount};
                $targetheal{$target}{hits} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{critCount};
                $targetheal{$target}{hits} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{tickCount};
                
                $totalheal{effective} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{effective};
                $totalheal{total} += $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spell}{total};
            }
        }

        my @targets = sort {
            $targetheal{$b}{effective} <=> $targetheal{$a}{effective}
        } keys %targetheal;

        if( @targets ) {
            $PAGE .= $page->tableHeader(@header);
            foreach my $target (@targets) {
                my $id = lc $target;
                $id =~ s/[^\w]/_/g;

                my $sdata;
                $sdata = $actors{$PLAYER}{healing}{targets}{$target};
                $PAGE .= $page->tableRow( 
                    header => \@header,
                    data => {
                        "Heals Out" => $page->actorLink( $target, $page->classColor( $raid{$target}{class} ) ),
                        "R-Eff. Heal" => $targetheal{$target}{effective},
                        "R-Hits" => $targetheal{$target}{hits},
                        "R-Overheal %" => $targetheal{$target}{total} ? sprintf "%0.1f%%", ( $targetheal{$target}{total} - $targetheal{$target}{effective} ) / $targetheal{$target}{total} * 100: "",
                        "R-Eff. Out %" => $totalheal{effective} ? sprintf "%0.1f%%", $targetheal{$target}{effective} / $totalheal{effective} * 100: "",
                    },
                    type => "master",
                    name => "healout_$id",
                );
            
                my @spellnames = sort {
                    $actors{$PLAYER}{healing}{targets}{$target}{spells}{$b}{effective} <=> $actors{$PLAYER}{healing}{targets}{$target}{spells}{$a}{effective}
                } keys %{$actors{$PLAYER}{healing}{targets}{$target}{spells}};
            
                foreach my $spellname (@spellnames) {
                    $sdata = $actors{$PLAYER}{healing}{targets}{$target}{spells}{$spellname};
                    next unless $sdata->{total};
                
                    $PAGE .= $page->tableRow( 
                        header => \@header,
                        data => {
                            "Heals Out" => $spellname,
                            "R-Eff. Heal" => $sdata->{effective},
                            "R-Hits" => $sdata->{hitCount} + $sdata->{critCount} + $sdata->{tickCount},
                            "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ( $sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100: "",
                            "R-Eff. Out %" => $targetheal{$target}{effective} ? sprintf "%0.1f%%", $sdata->{effective} / $targetheal{$target}{effective} * 100: "",
                        },
                        type => "slave",
                        name => "healout_$id",
                    );
                }
            
                $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('healout_$id');
</script>
END
            }
        }
    }
    
    ####################
    # HEALS IN SOURCES #
    ####################
    
    if( 1 ) {
        my @header = (
                "Heals In",
                "R-Eff. Heal",
                "R-Hits",
                "R-Eff. In %",
                "R-Overheal %",
                "",
            );
        
        my %sourceheal;
        my %totalheal;
        foreach my $actor (keys %actors) {
            next unless $actors{$actor}{healing}{targets}{$PLAYER}{spells};
            
            foreach my $spell (keys %{ $actors{$actor}{healing}{targets}{$PLAYER}{spells} }) {
                $sourceheal{$actor}{effective} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{effective};
                $sourceheal{$actor}{total} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{total};
                $sourceheal{$actor}{hits} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{hitCount};
                $sourceheal{$actor}{hits} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{critCount};
                $sourceheal{$actor}{hits} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{tickCount};
                
                $totalheal{effective} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{effective};
                $totalheal{total} += $actors{$actor}{healing}{targets}{$PLAYER}{spells}{$spell}{total};
            }
        }

        my @sources = sort {
            $sourceheal{$b}{effective} <=> $sourceheal{$a}{effective}
        } keys %sourceheal;
        
        if( @sources ) {
            $PAGE .= $page->tableHeader(@header);
            foreach my $source (@sources) {
                my $id = lc $source;
                $id =~ s/[^\w]/_/g;

                my $sdata;
                $sdata = $actors{$source}{healing}{targets}{$PLAYER};
                $PAGE .= $page->tableRow( 
                    header => \@header,
                    data => {
                        "Heals In" => $page->actorLink( $source, $page->classColor( $raid{$source}{class} ) ),
                        "R-Eff. Heal" => $sourceheal{$source}{effective},
                        "R-Hits" => $sourceheal{$source}{hits},
                        "R-Overheal %" => $sourceheal{$source}{total} ? sprintf "%0.1f%%", ( $sourceheal{$source}{total} - $sourceheal{$source}{effective} ) / $sourceheal{$source}{total} * 100: "",
                        "R-Eff. In %" => $totalheal{effective} ? sprintf "%0.1f%%", $sourceheal{$source}{effective} / $totalheal{effective} * 100: "",
                    },
                    type => "master",
                    name => "healin_$id",
                );

                my @spellnames = sort {
                    $actors{$source}{healing}{targets}{$PLAYER}{spells}{$b}{effective} <=> $actors{$source}{healing}{targets}{$PLAYER}{spells}{$a}{effective}
                } keys %{$actors{$source}{healing}{targets}{$PLAYER}{spells}};

                foreach my $spellname (@spellnames) {
                    $sdata = $actors{$source}{healing}{targets}{$PLAYER}{spells}{$spellname};
                    next unless $sdata->{total};

                    $PAGE .= $page->tableRow( 
                        header => \@header,
                        data => {
                            "Heals In" => $spellname,
                            "R-Eff. Heal" => $sdata->{effective},
                            "R-Hits" => $sdata->{hitCount} + $sdata->{critCount} + $sdata->{tickCount},
                            "R-Overheal %" => $sdata->{total} ? sprintf "%0.1f%%", ( $sdata->{total} - $sdata->{effective} ) / $sdata->{total} * 100: "",
                            "R-Eff. In %" => $sourceheal{$source}{effective} ? sprintf "%0.1f%%", $sdata->{effective} / $sourceheal{$source}{effective} * 100: "",
                        },
                        type => "slave",
                        name => "healin_$id",
                    );
                }

                $PAGE .= <<END;
<script type="text/javascript">
toggleTableSection('healin_$id');
</script>
END
            }
        }
    }
    
    $PAGE .= $page->tableEnd;
    
    $PAGE .= $page->pageFooter;
}

sub _damageSpells {
    my $self = shift;
    my $PLAYER = shift;
    my %actors = %{ $self->{actors} };

    # build totals for damaging spells (%actors list only has per-target info)
    my %spells;
    foreach my $target (keys %{ $actors{$PLAYER}{damage}{targets} }) {
        my $spellref = $actors{$PLAYER}{damage}{targets}{$target}{spells};
        while( my ($sname, $sdata) = each(%$spellref) ) {
            while( my ($datan, $datav) = each(%$sdata) ) {
                if( $datav =~ /^[0-9]+$/ ) {
                    $spells{$sname}{$datan} += $datav;
                } elsif( $datan eq "mods" ) {
                    while( my ($modn,$modv) = each(%$datav) ) {
                        $spells{$sname}{$datan}{$modn} += $modv;
                    }
                } elsif( $datan eq "size" ) {
                    while( my ($sizen,$sizev) = each(%$datav) ) {
                        $spells{$sname}{$datan}{$sizen} = $sizev if
                            (
                                !$spells{$sname}{$datan}{$sizen} ||
                                $spells{$sname}{$datan}{$sizen} < $sizev
                            ) && $sizen =~ /Max$/;

                        $spells{$sname}{$datan}{$sizen} = $sizev if
                            (
                                !$spells{$sname}{$datan}{$sizen} ||
                                $spells{$sname}{$datan}{$sizen} > $sizev
                            ) && $sizen =~ /Min$/;
                    }
                } elsif( $datav ) {
                    $spells{$sname}{$datan} = $datav;
                }
            }
        }
    }
    
    return %spells;
}

sub _healingSpells {
    my $self = shift;
    my $PLAYER = shift;
    my %actors = %{ $self->{actors} };
    
    # build totals for healing spells (%actors list only has per-target info)
    my %healing;
    foreach my $target (keys %{ $actors{$PLAYER}{healing}{targets} }) {
        my $spellref = $actors{$PLAYER}{healing}{targets}{$target}{spells};
        while( my ($sname, $sdata) = each(%$spellref) ) {
            while( my ($datan, $datav) = each(%$sdata) ) {
                if( $datav =~ /^[0-9]+$/ ) {
                    $healing{$sname}{$datan} += $datav;
                } elsif( $datav ) {
                    $healing{$sname}{$datan} = $datav;
                }
            }
        }
    }
    
    return %healing;
}

sub _powerGains {
    my $self = shift;
    my $PLAYER = shift;
    my %actors = %{ $self->{actors} };
    
    # build totals for power gains (%actors list only has per-target info)
    my %powers;
    foreach my $spell (keys %{ $actors{$PLAYER}{power}{spells} }) {
        my $sourcesref = $actors{$PLAYER}{power}{spells}{$spell}{sources};
        while( my ($sname, $sdata) = each(%$sourcesref) ) {
            while( my ($datan, $datav) = each(%$sdata) ) {
                if( $datav =~ /^[0-9]+$/ ) {
                    $powers{$spell}{$datan} += $datav;
                } elsif( $datav ) {
                    $powers{$spell}{$datan} = $datav;
                }
            }
        }
    }
    
    return %powers;
}

sub _mCasts {
    my $self = shift;
    my $PLAYER = shift;
    my %actors = %{ $self->{actors} };
    
    # build totals for casts (%actors list only has per-target info)
    my %casts;
    foreach my $spell (keys %{ $actors{$PLAYER}{casts}{spells} }) {
        my $targetsref = $actors{$PLAYER}{casts}{spells}{$spell}{targets};
        while( my ($tname, $tdata) = each(%$targetsref) ) {
            $casts{$spell} += $tdata;
        }
    }
    
    return %casts;
}

sub _mergePets {
    my $self = shift;
    my $PLAYER = shift;
    my %actors = %{ $self->{actors} };
    my %raid = %{ $self->{raid} };
    
    foreach my $raider (keys %raid) {
        # Loop through their pets.
        if( $raid{$raider}{pets} ) {
            foreach my $pet ( @{$raid{$raider}{pets}} ) {
                # Loop through pet damage targets
                foreach my $target ( keys %{$actors{$pet}{damage}{targets}} ) {
                    # Loop through pet damage spells for this target
                    foreach my $spell (keys %{$actors{$pet}{damage}{targets}{$target}{spells}}) {
                        # Add it...
                        $actors{$raider}{damage}{targets}{$target}{spells}{"$pet: $spell"} = dclone($actors{$pet}{damage}{targets}{$target}{spells}{$spell});
                    }
                }
            }
        }
    }
}

1;
