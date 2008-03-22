package Stasis::ChartPage;

use strict;
use warnings;
use POSIX;
use Stasis::PageMaker;
use Data::Dumper;
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
    my $XML;
    
    my $self = shift;
    my %actors = %{$self->{actors}};
    my %raid = %{$self->{raid}};
    my @actions = @{$self->{actions}};
    
    $self->_mergePets();
    
    my $page = Stasis::PageMaker->new;
    
    $PAGE .= $page->pageHeader($self->{boss}, $actions[0]->{t});
    
    # Calculate raid DPS
    my %alldmg;
    my $totaldamage;
    foreach my $actor (keys %actors) {
        # Only show raiders
        next unless $raid{$actor}{class} && $raid{$actor}{class} ne "Pet";
        
        foreach my $target (keys %{$actors{$actor}{damage}{targets}}) {
            # skip friendlies
            next if $raid{$target}{class};

            foreach my $spell (keys %{$actors{$actor}{damage}{targets}{$target}{spells}}) {
                $alldmg{$actor} += $actors{$actor}{damage}{targets}{$target}{spells}{$spell}{damage};
                $totaldamage += $actors{$actor}{damage}{targets}{$target}{spells}{$spell}{damage};
            }
        }
    }
    
    # Raid duration
    my $rpresence = $actions[ $#actions ]->{t} - $actions[0]->{t};
    my $rdps = $totaldamage / $rpresence;
    
    #############
    # RAID INFO #
    #############
    
    my $presence_text = sprintf( "Raid duration: %02d:%02d", $rpresence/60, $rpresence%60 );
    $presence_text .= sprintf( "<br />Raid DPS: %d", $totaldamage/$rpresence );
    
    $PAGE .= "<h3>Raid Information</h3>";
    $PAGE .= $page->textBox( $presence_text );
    
    my $bossclean = $self->{boss};
    $bossclean =~ s/[^\w]/_/g;
    my $dname = sprintf "sws-%d", floor($actions[0]->{t});
    $XML .= sprintf( '  <raid dpstime="%d" start="%s" dps="%d" comment="%s" lg="%d" dir="%s">' . "\n",
                100,
                ($actions[0]->{t})*1000 - 8*3600000,
                $rpresence ? $totaldamage/$rpresence : 0,
                $self->{boss},
                $rpresence*60000,
                $dname,
            );
        
    # We will store player keys in here.
    my %xml_keys;
    
    ################
    # DAMAGE CHART #
    ################
    
    $PAGE .= "<h3><a name=\"damage\"></a>Damage</h3>";
    
    $PAGE .= $page->tableStart( "chart" );
    
    my @damageHeader = (
            "Player",
            "Presence",
            "R-Damage Out",
            "R-Dam. %",
            "R-DPS",
            "R-DPS Time",
            " ",
        );
        
    $PAGE .= $page->tableHeader(@damageHeader);
    
    my @damagesort = sort {
        $alldmg{$b} <=> $alldmg{$a}
    } keys %actors;
    
    my $mostdmg = $alldmg{ $damagesort[0] };
    
    foreach my $actor (@damagesort) {
        # Only show raiders
        next unless $raid{$actor}{class} && $raid{$actor}{class} ne "Pet";
        
        my $ptime = $actors{$actor}{presence}{end} - $actors{$actor}{presence}{start};
        
        $PAGE .= $page->tableRow( 
            header => \@damageHeader,
            data => {
                "Player" => $page->actorLink( $actor, $page->classColor( $raid{$actor}{class} ) ),
                "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Dam. %" => $totaldamage ? sprintf "%d%%", ceil($alldmg{$actor} / $totaldamage * 100) : "",
                "R-Damage Out" => $alldmg{$actor},
                " " => $mostdmg ? sprintf "%d", ceil($alldmg{$actor} / $mostdmg * 100) : "",
                "R-DPS" => $actors{$actor}{damage}{dpstime} ? sprintf "%d", $alldmg{$actor} / $actors{$actor}{damage}{dpstime} : "",
                "R-DPS Time" => $ptime ? sprintf "%0.1f%%", $actors{$actor}{damage}{dpstime} / $ptime * 100 : "",
            },
            type => "",
        );
        
        my %classmap = (
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
        
        $xml_keys{$actor}{name} = $actor;
        $xml_keys{$actor}{classe} = $classmap{ $raid{$actor}{class} };
        $xml_keys{$actor}{death} = $actors{$actor}{deaths} ? scalar @{$actors{$actor}{deaths}} : 0;
#        $xml_keys{$actor}{presence} = $rpresence ? ceil($ptime / $rpresence) : 0;
        $xml_keys{$actor}{dps} = $actors{$actor}{damage}{dpstime} ? ceil($alldmg{$actor} / $actors{$actor}{damage}{dpstime}) : 0;
        $xml_keys{$actor}{dpstime} = $ptime ? $actors{$actor}{damage}{dpstime} / $ptime * 100 : 0;
        $xml_keys{$actor}{dmgout} = $totaldamage ? $alldmg{$actor} / $totaldamage * 100 : 0;
    }
    
    $PAGE .= $page->tableEnd;
    
    #################
    # HEALING CHART #
    #################
    
    $PAGE .= "<h3><a name=\"healing\"></a>Healing</h3>";
    
    $PAGE .= $page->tableStart("chart");
    
    my @healHeader = (
            "Player",
            "Presence",
            "R-Eff. Heal",
            "R-%",
            "R-Overheal",
            " ",
        );
        
    $PAGE .= $page->tableHeader(@healHeader);
    
    my %allheal;
    my %allhealtotal;
    my $totalhealing;
    foreach my $actor (keys %actors) {
        # Only show raiders
        next unless $raid{$actor}{class} && $raid{$actor}{class} ne "Pet";
        
        my $allheal;
        foreach my $target (keys %{$actors{$actor}{healing}{targets}}) {
            # skip enemies
            next unless $raid{$target}{class} && $raid{$target}{class} ne "Mob";

            foreach my $spell (keys %{$actors{$actor}{healing}{targets}{$target}{spells}}) {
                $allheal{$actor} += $actors{$actor}{healing}{targets}{$target}{spells}{$spell}{effective};
                $allhealtotal{$actor} += $actors{$actor}{healing}{targets}{$target}{spells}{$spell}{total};
                
                $totalhealing += $actors{$actor}{healing}{targets}{$target}{spells}{$spell}{effective};
            }
        }
    }
    
    my @healsort = sort {
        $allheal{$b} <=> $allheal{$a}
    } keys %actors;
    
    my $mostheal = $allheal{ $healsort[0] };
    
    foreach my $actor (@healsort) {
        # Only show raiders
        next unless $raid{$actor}{class} && $raid{$actor}{class} ne "Pet";
        
        my $ptime = $actors{$actor}{presence}{end} - $actors{$actor}{presence}{start};
        
        $PAGE .= $page->tableRow( 
            header => \@healHeader,
            data => {
                "Player" => $page->actorLink( $actor, $page->classColor( $raid{$actor}{class} ) ),
                "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Eff. Heal" => $allheal{$actor},
                "R-%" => $totalhealing ? sprintf "%d%%", ceil($allheal{$actor} / $totalhealing * 100) : "",
                " " => $mostheal ? sprintf "%d", ceil($allheal{$actor} / $mostheal * 100) : "",
                "R-Overheal" => $allhealtotal{$actor} ? sprintf( "%0.1f%%", ($allhealtotal{$actor}-$allheal{$actor}) / $allhealtotal{$actor} * 100 ) : "",
            },
            type => "",
        );
        
        $xml_keys{$actor}{ovh} = $allhealtotal{$actor} ? ceil( ($allhealtotal{$actor}-$allheal{$actor}) / $allhealtotal{$actor} * 100 ) : 0;
        $xml_keys{$actor}{heal} = $totalhealing ? $allheal{$actor} / $totalhealing * 100 : 0;
    }
    
    $PAGE .= $page->tableEnd;
    
    ###############
    # ACTORS LIST #
    ###############
    
    $PAGE .= "<h3><a name=\"actors\"></a>Raid &amp; Mobs</h3>";
    
    $PAGE .= $page->tableStart("chart");
    
    my @actorHeader = (
            "Actor",
            "Class",
            "Presence",
            "R-Presence %",
        );
        
    $PAGE .= $page->tableHeader(@actorHeader);
    
    foreach my $actor (sort keys %actors) {
        my $ptime = $actors{$actor}{presence}{end} - $actors{$actor}{presence}{start};

        $PAGE .= $page->tableRow( 
            header => \@actorHeader,
            data => {
                "Actor" => $page->actorLink( $actor, $page->classColor( $raid{$actor}{class} ) ),
                "Class" => $raid{$actor}{class} ? $raid{$actor}{class} : "Mob",
                "Presence" => sprintf( "%02d:%02d", $ptime/60, $ptime%60 ),
                "R-Presence %" => $rpresence ? sprintf "%d%%", ceil($ptime/$rpresence*100) : "",
            },
            type => "",
        );
    }
    
    $PAGE .= $page->tableEnd;
    
    # Print out the XML player keys.
    foreach my $xplayer (keys %xml_keys) {
        # Defaults.
        $xml_keys{$xplayer}{decurse} ||= 0;
        $xml_keys{$xplayer}{ovh} ||= 0;
        $xml_keys{$xplayer}{dpstime} ||= 0;
        $xml_keys{$xplayer}{dps} ||= 0;
        $xml_keys{$xplayer}{classe} ||= "war";
        $xml_keys{$xplayer}{heal} ||= 0;
        $xml_keys{$xplayer}{name} ||= "Unknown";
        $xml_keys{$xplayer}{death} ||= 0;
        $xml_keys{$xplayer}{dmgout} ||= 0;
        $xml_keys{$xplayer}{dmgin} ||= 0;
        $xml_keys{$xplayer}{pres} ||= 100;
        
        $XML .= sprintf "    <player %s />\n", join " ", map { sprintf "%s=\"%s\"", $_, $xml_keys{$xplayer}{$_} } (keys %{$xml_keys{$xplayer}});
    }
    
    $XML .= "  </raid>\n";
    $PAGE .= $page->pageFooter;
    
    return ($PAGE,$XML);
}

sub _mergePets {
    my $self = shift;
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
                        $actors{$raider}{damage}{targets}{$target}{spells}{"$pet: $spell"} = ($actors{$pet}{damage}{targets}{$target}{spells}{$spell});
                    }
                }
            }
        }
    }
}

1;
