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

package Stasis::ClassGuess;

use strict;
use warnings;
use POSIX;
use Stasis::MobUtil;
use Stasis::SpellUtil;
use Carp;

# Fingerprints of various classes (pre 2.4 only)
my %profiles = (

"Shaman" => {
    "damage" => [
        #"Earth Shock",
        "Flame Shock",
        "Frost Shock",
        "Lightning Bolt",
        "Chain Lightning",
        "Windfury Attack",
        "Stormstrike",
    ],
    
    "healing" => [
        "Healing Wave",
        "Chain Heal",
        "Lesser Healing Wave",
    ],
    
    "casts" => [
        "Mana Spring Totem",
        "Mana Tide Totem",
        "Tranquil Air Totem",
        "Totem of Wrath",
        "Wrath of Air Totem",
        "Windfury Totem",
        "Grace of Air Totem",
        "Strength of Earth Totem",
        "Fire Resistance Totem",
        "Frost Resistance Totem",
        "Nature Resistance Totem",
    ],
    
    "auras" => [
        
    ],
},

"Druid" => {
    "damage" => [
        "Mangle (Cat)",
        "Mangle (Bear)",
        "Maul",
        "Rip",
        "Claw",
        "Rake",
        "Moonfire",
        "Starfire",
        "Wrath",
        "Insect Swarm",
        "Hurricane",
    ],
    
    "healing" => [
        "Healing Touch",
        "Rejuvenation",
        "Regrowth",
        "Tranquility",
        "Swiftmend",
    ],
    
    "casts" => [
        "Rebirth",
    ],
    
    "auras" => [
        "Dire Bear Form",
        "Cat Form",
        "Moonkin Form",
    ],
},

"Mage" => {
    "damage" => [
        "Fireball",
        "Scorch",
        "Fire Blast",
        "Ignite",
        "Flamestrike",
        "Pyroblast",
        "Arcane Explosion",
        "Arcane Blast",
        "Arcane Missiles",
        "Frostbolt",
        "Ice Lance",
        "Blizzard",
        "Frost Nova",
        "Cone of Cold",
    ],
    
    "healing" => [
        
    ],
    
    "casts" => [
        "Spellsteal",
        "Summon Water Elemental"
    ],
    
    "auras" => [
        "Icy Veins",
        "Arcane Blast",
    ]
},

"Priest" => {
    "damage" => [
        "Vampiric Touch",
        "Shadow Word: Pain",
        "Shadow Word: Death",
        "Mind Flay",
        "Mind Blast",
        "Smite",
        "Holy Fire",
    ],
    
    "healing" => [
        "Flash Heal",
        "Greater Heal",
        "Prayer of Healing",
        "Circle of Healing",
        "Renew",
        "Desperate Prayer",
        "Vampiric Embrace",
    ],
    
    "casts" => [
        "Power Word: Shield",
        "Shadowfiend",
    ],
    
    "auras" => [
    
    ],
},

"Warrior" => {
    "damage" => [
        "Mortal Strike",
        "Bloodthirst",
        "Heroic Strike",
        "Cleave",
        "Whirlwind",
        "Slam",
        "Shield Slam",
        "Devastate",
        "Thunder Clap",
        "Deep Wounds",
    ],
    
    "healing" => [
        "Bloodthirst",
        "Second Wind",
    ],
    
    "casts" => [
        
    ],
    
    "auras" => [
        "Recklessness",
        "Sweeping Strikes",
        "Last Stand",
        "Shield Wall",
        "Bloodrage",
    ],
},

"Paladin" => {
    "damage" => [
        "Crusader Strike",
        "Seal of Blood",
        "Seal of Command",
        "Seal of Righteousness",
        "Seal of the Crusader",
        "Holy Shock",
        "Judgement of Righteousness",
        "Judgement of Vengeance",
        "Avenger's Shield",
    ],
    
    "healing" => [
        "Holy Light",
        "Flash of Light",
    ],
    
    "casts" => [
        "Holy Shock",
        "Cleanse",
    ],
    
    "auras" => [
        "Seal of Blood",
        "Seal of Command",
        "Seal of Righteousness",
        "Seal of the Crusader",
        "Divine Favor",
        "Divine Illumination",
        "Divine Shield",
    ],
},

"Hunter" => {
    "damage" => [
        "Auto Shot",
        "Steady Shot",
        "Aimed Shot",
        "Serpent Sting",
        "Multi-Shot",
    ],
    
    "healing" => [
        "Mend Pet",
    ],
    
    "casts" => [
        "Misdirection",
    ],
    
    "auras" => [
        "Rapid Fire",
        "The Beast Within",
    ],
},

"Warlock" => {
    "damage" => [
        "Shadow Bolt",
        "Incinerate",
        "Immolate",
        "Conflagrate",
        "Drain Life",
        "Siphon Life",
        "Curse of Agony",
        "Curse of Doom",
        "Corruption",
        "Death Coil",
    ],
    
    "healing" => [
        "Siphon Life",
        "Drain Life",
    ],
    
    "casts" => [
        "Soulshatter",
        "Life Tap",
        "Demonic Sacrifice",
    ],
    
    "auras" => [
    
    ],
},

"Rogue" => {
    "damage" => [
        "Backstab",
        "Mutilate",
        "Sinister Strike",
        "Hemorrhage",
        "Eviscerate",
        "Envenom",
        "Rupture",
        "Shiv",
        "Deadly Poison VII",
        "Instant Poison VII",
        "Wound Poison V",
    ],
    
    "healing" => [
        
    ],
    
    "casts" => [
        "Vanish",
    ],
    
    "auras" => [
        "Slice and Dice",
        "Blade Flurry",
        "Adrenaline Rush",
    ],
},

);

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{version} = 2 if !$params{version} || $params{version} != 1;
    $params{scratch1} = {};
    $params{totems} = {};
    
    bless \%params, $class;
}

sub process {
    my ($self) = @_;
    return $self->{version} == 1 ? process1(@_) : process2(@_);
}

sub finish {
    my ($self) = @_;
    return $self->{version} == 1 ? finish1(@_) : finish2(@_);
}

sub process1 {
    my ( $self, $entry ) = @_;
    
    # Skip entries with no action.
    return unless $entry && $entry->{action};
    
    # Skip "Unknown"
    return if( $entry->{actor_name} eq "Unknown" || $entry->{target_name} eq "Unknown" );
    
    # Check damage.
    if( ($entry->{action} eq "SPELL_MISS" || $entry->{action} eq "SPELL_DAMAGE" || $entry->{action} eq "SPELL_PERIODIC_MISS" || $entry->{action} eq "SPELL_PERIODIC_DAMAGE") && $entry->{actor_name} !~ /\s/ ) {
        # For each class profile...
        while( my($cname, $cdata) = each(%profiles) ) {
            # Check if this damage matches...
            if( grep $_ eq $entry->{extra}{spellname}, @{$cdata->{damage}} ) {
                # And record if it does.
                $self->{scratch1}{ $entry->{actor} }{class}{ $cname }{damage}{ $entry->{extra}{spellname} } ++;
            }
        }
    }
    
    # Check heals.
    if( ($entry->{action} eq "SPELL_HEAL" || $entry->{action} eq "SPELL_PERIODIC_HEAL") && $entry->{actor_name} !~ /\s/ ) {
        # For each class profile...
        while( my($cname, $cdata) = each(%profiles) ) {
            # Check if this heal matches...
            if( grep $_ eq $entry->{extra}{spellname}, @{$cdata->{healing}} ) {
                # And record if it does.
                $self->{scratch1}{ $entry->{actor} }{class}{ $cname }{healing}{ $entry->{extra}{spellname} } ++;
            }
        }
    }
    
    # Check casts.
    if( $entry->{action} eq "SPELL_CAST_SUCCESS" && $entry->{actor_name} !~ /\s/ ) {
        # For each class profile...
        while( my($cname, $cdata) = each(%profiles) ) {
            # Check if this cast matches...
            if( grep $_ eq $entry->{extra}{spellname}, @{$cdata->{casts}} ) {
                # And record if it does.
                $self->{scratch1}{ $entry->{actor} }{class}{ $cname }{casts}{ $entry->{extra}{spellname} } ++;
            }
        }
    }
    
    # Check auras.
    if( $entry->{action} eq "SPELL_AURA_APPLIED" && $entry->{target_name} !~ /\s/ ) {
        # For each class profile...
        while( my($cname, $cdata) = each(%profiles) ) {
            # Check if this aura matches...
            if( grep $_ eq $entry->{extra}{spellname}, @{$cdata->{auras}} ) {
                # And record if it does.
                $self->{scratch1}{ $entry->{target} }{class}{ $cname }{auras}{ $entry->{extra}{spellname} } ++;
            }
        }
    }
    
    # Check things that signify pet <=> owner relationships.
    
    # Skip unless actor and target are both set.
    return unless $entry->{actor} && $entry->{target};
    
    # Summons
    if( $entry->{action} eq "SPELL_SUMMON" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Mend Pet
    if( $entry->{action} eq "SPELL_PERIODIC_HEAL" && $entry->{extra}{spellname} eq "Mend Pet" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Spirit Bond
    if( $entry->{action} eq "SPELL_PERIODIC_HEAL" && $entry->{extra}{spellname} eq "Spirit Bond" ) {
        $self->{scratch1}{ $entry->{target} }{pets}{ $entry->{actor} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Feed Pet Effect
    if( $entry->{action} =~ /^SPELL(_PERIODIC|)_ENERGIZE$/ && $entry->{extra}{spellname} eq "Feed Pet Effect" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Go for the Throat
    if( $entry->{action} =~ /^SPELL(_PERIODIC|)_ENERGIZE$/ && $entry->{extra}{spellname} eq "Go for the Throat" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Improved Mend Pet
    if( $entry->{action} eq "SPELL_CAST_SUCCESS" && $entry->{extra}{spellname} eq "Improved Mend Pet" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Dark Pact
    if( $entry->{action} =~ /^SPELL(_PERIODIC|)_ENERGIZE$/ && $entry->{extra}{spellname} eq "Dark Pact" ) {
        $self->{scratch1}{ $entry->{target} }{pets}{ $entry->{actor} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Also Dark Pact
    if( $entry->{action} eq "SPELL_LEECH" && $entry->{extra}{spellname} eq "Dark Pact" ) {
        $self->{scratch1}{ $entry->{target} }{pets}{ $entry->{actor} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Demonic Sacrifice
    if( $entry->{action} eq "SPELL_CAST_SUCCESS" && $entry->{extra}{spellname} eq "Demonic Sacrifice" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
    
    # Soul Link
    if( $entry->{action} eq "DAMAGE_SPLIT" && $entry->{extra}{spellname} eq "Soul Link" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }

    # Mana Feed
    if( $entry->{action} eq "SPELL_ENERGIZE" && $entry->{extra}{spellname} eq "Life Tap" ) {
        $self->{scratch1}{ $entry->{actor} }{pets}{ $entry->{target} } ++ if $entry->{target} ne $entry->{actor};
    }
}

sub process2 {
    my ( $self, $entry ) = @_;
    
    # Skip if actor and target are not set.
    return unless $entry->{actor} && $entry->{target};
    
    # Think about classifying the actor.
    if( !$self->{scratch2}{class}{ $entry->{actor} } ) {
        # Get the type.
        my ($atype, $anpc, $aspawn ) = Stasis::MobUtil::splitguid( $entry->{actor} );
        
        # See if this actor is a player.
        if( ($atype & 0x00F0) == 0 && ($entry->{action} eq "SPELL_MISS" || $entry->{action} eq "SPELL_DAMAGE" || $entry->{action} eq "SPELL_PERIODIC_MISS" || $entry->{action} eq "SPELL_PERIODIC_DAMAGE" || $entry->{action} eq "SPELL_HEAL" || $entry->{action} eq "SPELL_PERIODIC_HEAL" || $entry->{action} eq "SPELL_CAST_SUCCESS") )
        {
            my $spell = Stasis::SpellUtil->spell( $entry->{extra}{spellid} );
            if( $spell && $spell->{class} ) {
                $self->{scratch2}{class}{ $entry->{actor} } = $spell->{class};
            }
        }
        
        # See if this actor is a pet. Make sure it wasn't identified in the previous block, though.
        if( !$self->{scratch2}{class}{ $entry->{actor} } && $entry->{target} ne $entry->{actor} ) {
            if( $entry->{action} eq "SPELL_PERIODIC_HEAL" && $entry->{extra}{spellid} == 24529 ) {
                # Spirit Bond
                $self->{scratch2}{class}{ $entry->{actor} } = "Pet";
                $self->{scratch2}{pets}{ $entry->{target} }{ $entry->{actor} } ++;
            }
            
            # Greater Fire and Earth elementals (pre-2.4.3 code)
            if( $anpc == 15438 || $anpc == 15352 ) {
                while( my ($totemid, $shamanid) = each(%{$self->{scratch2}{totems}}) ) {
                    # Associate totem with this elemental by consecutive spawncount.
                    my @totem = Stasis::MobUtil::splitguid( $totemid );
                    my @elemental = Stasis::MobUtil::splitguid( $entry->{actor} );
                    if( $totem[2] + 1 == $elemental[2] ) {
                        $self->{scratch2}{class}{ $entry->{actor} } = "Pet";
                        $self->{scratch2}{pets}{ $shamanid }{ $entry->{actor} } ++;
                    }
                }
            }
        }
    }
    
    # Think about classifying the target as a pet.
    if( !$self->{scratch2}{class}{ $entry->{target} } && $entry->{target} ne $entry->{actor} ) {
        # Summons
        if( $entry->{action} eq "SPELL_SUMMON" ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            
            # Follow the pet chain.
            my $owner = $entry->{actor};
            while( $self->{scratch2}{class}{ $owner } && $self->{scratch2}{class}{ $owner } eq "Pet" ) {
                # Find the pet's owner.
                while( my ($kpet, $vpet) = each(%{$self->{scratch2}{pets}}) ) {
                    if( $vpet->{ $owner } ) {
                        $owner = $kpet;
                        last;
                    }
                }
            }
            
            $self->{scratch2}{pets}{ $owner }{ $entry->{target} } ++;

            # Shaman elemental totems (Fire and Earth respectively)
            if( $entry->{extra}{spellid} == 2894 || $entry->{extra}{spellid} == 2062 ) {
                # Associate totem with shaman by SPELL_SUMMON event.
                $self->{scratch2}{totems}{ $entry->{target} } = $entry->{actor};
            }
        }
        
        # Mend Pet
        elsif( $entry->{action} eq "SPELL_PERIODIC_HEAL" && $entry->{extra}{spellid} == 27046 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }

        # Feed Pet Effect
        elsif( $entry->{action} eq "SPELL_PERIODIC_ENERGIZE" && $entry->{extra}{spellid} == 1539 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }

        # Go for the Throat
        elsif( $entry->{action} eq "SPELL_ENERGIZE" && $entry->{extra}{spellid} == 34953 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }

        # Dark Pact
        elsif( $entry->{action} eq "SPELL_LEECH" && $entry->{extra}{spellid} == 27265 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }

        # Demonic Sacrifice
        elsif( $entry->{action} eq "SPELL_INSTAKILL" && $entry->{extra}{spellid} == 18788 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }

        # Soul Link
        elsif( $entry->{action} eq "DAMAGE_SPLIT" && $entry->{extra}{spellid} == 25228 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }

        # Mana Feed
        elsif( $entry->{action} eq "SPELL_ENERGIZE" && $entry->{extra}{spellid} == 32553 ) {
            $self->{scratch2}{class}{ $entry->{target} } = "Pet";
            $self->{scratch2}{pets}{ $entry->{actor} }{ $entry->{target} } ++;
        }
    }
}

sub finish1 {
    my $self = shift;
    
    # We will eventually return this list of raid members.
    # Keys will be raid member IDs and values will be two element hashes
    # Each hash will have at least two keys: "class" (a string) and "pets" (an array of pet IDs)
    my %raid;
    
    # Prepare the final results for each actor.
    while( my ($aname, $adata) = each(%{$self->{scratch1}}) ) {
        # Skip this bit if the actor has no guessed classes or proper ID.
        next unless $adata->{class} && $aname;
        
        # Check if we should assign a class.
        my %matches;
        
        foreach my $mclass (keys %{ $adata->{class} }) {
            $matches{$mclass} = 0;
            $matches{$mclass} += scalar keys %{$adata->{class}{$mclass}{damage}} if $adata->{class}{$mclass}{damage};
            $matches{$mclass} += scalar keys %{$adata->{class}{$mclass}{healing}} if $adata->{class}{$mclass}{healing};
            $matches{$mclass} += scalar keys %{$adata->{class}{$mclass}{casts}} if $adata->{class}{$mclass}{casts};
            $matches{$mclass} += scalar keys %{$adata->{class}{$mclass}{auras}} if $adata->{class}{$mclass}{auras};
        }
        
        # Sort.
        my @class_names = sort { $matches{$b} <=> $matches{$a} } keys %matches;
        my @class_numbers = map { $matches{$_} } @class_names;
        
        # Make a decision.
        if( @class_names == 1 && $class_numbers[0] > 1 ) {
            # If we only guessed one class, and it had two or more hits, go with it.
            $raid{ $aname }{class} = $class_names[0];
        } elsif( @class_names > 1 && $class_numbers[0] > 3 ) {
            # If we matched more than one class, still use the best match if it had four or more hits.
            $raid{ $aname }{class} = $class_names[0];
        }
        
        # Copy over pets if we guessed a class.
        if( exists $raid{ $aname } && exists $raid{ $aname }{class} ) {
            $adata->{pets} ||= {};
            
            my @pets = keys %{$adata->{pets}};
            $raid{ $aname }{pets} = \@pets;
            
            # Also mark each of those pets as a "Pet"
            foreach (@pets) {
                $raid{$_}{class} = "Pet";
            }
        }
    }
    
    return %raid;
}

sub finish2 {
    my $self = shift;
    
    # We will eventually return this list of raid members.
    # Keys will be raid member IDs and values will be two element hashes
    # Each hash will have at least two keys: "class" (a string) and "pets" (an array of pet IDs)
    my %raid;
    
    while( my ($actorid, $actorclass) = each (%{$self->{scratch2}{class}})) {
        next if $actorclass eq "Pet";
        
        $raid{$actorid} = {
            class => $actorclass,
            pets => [],
        };
    }
    
    while( my ($actorid, $pethash) = each (%{$self->{scratch2}{pets}})) {
        if( exists $raid{$actorid} ) {
            push @{$raid{$actorid}{pets}}, keys %$pethash;
            
            foreach my $petid (keys %$pethash) {
                $raid{$petid}{class} = "Pet";
            }
            
        }
    }
    
    return %raid;
}

1;
