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

package Stasis::LogSplit;

use strict;
use warnings;
use POSIX;
use Carp;

# Fingerprints of various boss encounters.
our %fingerprints = (
    
############
# KARAZHAN #
############

"Attumen the Huntsman" => {
    mobStart => [ "Midnight" ],
    mobContinue => [ "Attumen the Huntsman", "Midnight" ],
    mobEnd => [ "Attumen the Huntsman" ],
    timeout => 15,
},

"Moroes" => {
    mobStart => [ "Moroes" ],
    mobContinue => [ "Moroes" ],
    mobEnd => [ "Moroes" ],
    timeout => 20,
},

"Maiden of Virtue" => {
    mobStart => [ "Maiden of Virtue" ],
    mobContinue => [ "Maiden of Virtue" ],
    mobEnd => [ "Maiden of Virtue" ],
    timeout => 20,
},

"Opera (Wizard of Oz)" => {
    mobStart => [ "Dorothee", "Tito", "Strawman", "Tinhead", "Roar" ],
    mobContinue => [ "Dorothee", "Tito", "Strawman", "Tinhead", "Roar" ],
    mobEnd => [ "The Crone" ],
    timeout => 20,
},

# FIXME: Encounter doesn't end properly
"Opera (Romulo and Julianne)" => {
    mobStart => [ "Julianne" ],
    mobContinue => [ "Romulo", "Julianne" ],
    mobEnd => [],
    timeout => 20,
},

"Opera (Red Riding Hood)" => {
    mobStart => [ "The Big Bad Wolf" ],
    mobContinue => [ "The Big Bad Wolf" ],
    mobEnd => [ "The Big Bad Wolf" ],
    timeout => 20,
},

"Nightbane" => {
    mobStart => [ "Nightbane" ],
    mobContinue => [ "Nightbane", "Restless Skeleton" ],
    mobEnd => [ "Nightbane" ],
    timeout => 30,
},

"The Curator" => {
    mobStart => [ "The Curator" ],
    mobContinue => [ "The Curator" ],
    mobEnd => [ "The Curator" ],
    timeout => 20,
},

"Shade of Aran" => {
    mobStart => [ "Shade of Aran" ],
    mobContinue => [ "Shade of Aran" ],
    mobEnd => [ "Shade of Aran" ],
    timeout => 20,
},

"Terestian Illhoof" => {
    mobStart => [ "Terestian Illhoof" ],
    mobContinue => [ "Terestian Illhoof" ],
    mobEnd => [ "Terestian Illhoof" ],
    timeout => 20,
},

"Netherspite" => {
    mobStart => [ "Netherspite" ],
    mobContinue => [ "Netherspite" ],
    mobEnd => [ "Netherspite" ],
    timeout => 30,
},

"Netherspite" => {
    mobStart => [ "Netherspite" ],
    mobContinue => [ "Netherspite" ],
    mobEnd => [ "Netherspite" ],
    timeout => 45,
},

"Prince Malchezaar" => {
    mobStart => [ "Prince Malchezaar" ],
    mobContinue => [ "Prince Malchezaar" ],
    mobEnd => [ "Prince Malchezaar" ],
    timeout => 20,
},

############
# ZUL'AMAN #
############

"Nalorakk" => {
    mobStart => [ "Nalorakk" ],
    mobContinue => [ "Nalorakk" ],
    mobEnd => [ "Nalorakk" ],
    timeout => 15,
},

"Jan'alai" => {
    mobStart => [ "Jan'alai" ],
    mobContinue => [ "Jan'alai" ],
    mobEnd => [ "Jan'alai" ],
    timeout => 15,
},

"Akil'zon" => {
    mobStart => [ "Akil'zon" ],
    mobContinue => [ "Akil'zon" ],
    mobEnd => [ "Akil'zon" ],
    timeout => 15,
},

"Halazzi" => {
    mobStart => [ "Halazzi" ],
    mobContinue => [ "Halazzi" ],
    mobEnd => [ "Halazzi" ],
    timeout => 15,
},

"Hex Lord Malacrass" => {
    mobStart => [ "Hex Lord Malacrass" ],
    mobContinue => [ "Hex Lord Malacrass" ],
    mobEnd => [ "Hex Lord Malacrass" ],
    timeout => 15,
},

"Zul'jin" => {
    mobStart => [ "Zul'jin" ],
    mobContinue => [ "Zul'jin" ],
    mobEnd => [ "Zul'jin" ],
    timeout => 30,
},

#################
# GRUUL AND MAG #
#################

"High King Maulgar" => {
    mobStart => [ "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobContinue => [ "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobEnd => [ "High King Maulgar" ],
    timeout => 15,
},

"Gruul the Dragonkiller" => {
    mobStart => [ "Gruul the Dragonkiller" ],
    mobContinue => [ "Gruul the Dragonkiller" ],
    mobEnd => [ "Gruul the Dragonkiller" ],
    timeout => 15,
},

"Magtheridon" => {
    mobStart => [ "Hellfire Channeler" ],
    mobContinue => [ "Magtheridon", "Hellfire Channeler" ],
    mobEnd => [ "Magtheridon" ],
    timeout => 15,
},

########################
# SERPENTSHRINE CAVERN #
########################

"Hydross the Unstable" => {
    mobStart => [ "Hydross the Unstable" ],
    mobContinue => [ "Hydross the Unstable" ],
    mobEnd => [ "Hydross the Unstable" ],
    timeout => 15,
},

"The Lurker Below" => {
    mobStart => [ "The Lurker Below" ],
    mobContinue => [ "The Lurker Below" ],
    mobEnd => [ "The Lurker Below" ],
    timeout => 15,
},

"Leotheras the Blind" => {
    mobStart => [ "Greyheart Spellbinder" ],
    mobContinue => [ "Greyheart Spellbinder", "Leotheras the Blind" ],
    mobEnd => [ "Leotheras the Blind" ],
    timeout => 15,
},

"Fathom-Lord Karathress" => {
    mobStart => [ "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobContinue => [ "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobEnd => [ "Fathom-Lord Karathress" ],
    timeout => 15,
},

"Morogrim Tidewalker" => {
    mobStart => [ "Morogrim Tidewalker" ],
    mobContinue => [ "Morogrim Tidewalker" ],
    mobEnd => [ "Morogrim Tidewalker" ],
    timeout => 15,
},

"Lady Vashj" => {
    mobStart => [ "Lady Vashj" ],
    mobContinue => [ "Lady Vashj", "Enchanted Elemental", "Tainted Elemental", "Coilfang Strider", "Coilfang Elite" ],
    mobEnd => [ "Lady Vashj" ],
    timeout => 15,
},

################
# TEMPEST KEEP #
################

"Al'ar" => {
    mobStart => [ "Al'ar" ],
    mobContinue => [ "Al'ar" ],
    mobEnd => [ "Al'ar" ],
    timeout => 30,
},

"Void Reaver" => {
    mobStart => [ "Void Reaver" ],
    mobContinue => [ "Void Reaver" ],
    mobEnd => [ "Void Reaver" ],
    timeout => 15,
},

"High Astromancer Solarian" => {
    mobStart => [ "High Astromancer Solarian" ],
    mobContinue => [ "High Astromancer Solarian", "Solarium Priest", "Solarium Agent" ],
    mobEnd => [ "High Astromancer Solarian" ],
    timeout => 15,
},

"Kael'thas Sunstrider" => {
    mobStart => [ "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser" ],
    mobContinue => [ "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser", "Kael'thas Sunstrider", "Phoenix", "Phoenix Egg", "Master Engineer Telonicus", "Grand Astromancer Capernian", "Thaladred the Darkener", "Lord Sanguinar" ],
    mobEnd => [ "Kael'thas Sunstrider" ],
    timeout => 15,
},

#########
# HYJAL #
#########

"Rage Winterchill" => {
    mobStart => [ "Rage Winterchill" ],
    mobContinue => [ "Rage Winterchill" ],
    mobEnd => [ "Rage Winterchill" ],
    timeout => 10,
},

"Anetheron" => {
    mobStart => [ "Anetheron" ],
    mobContinue => [ "Anetheron" ],
    mobEnd => [ "Anetheron" ],
    timeout => 10,
},

"Kaz'rogal" => {
    mobStart => [ "Kaz'rogal" ],
    mobContinue => [ "Kaz'rogal" ],
    mobEnd => [ "Kaz'rogal" ],
    timeout => 10,
},

"Azgalor" => {
    mobStart => [ "Azgalor" ],
    mobContinue => [ "Azgalor" ],
    mobEnd => [ "Azgalor" ],
    timeout => 10,
},

"Archimonde" => {
    mobStart => [ "Archimonde" ],
    mobContinue => [ "Archimonde" ],
    mobEnd => [ "Archimonde" ],
    timeout => 30,
},

################
# BLACK TEMPLE #
################

"High Warlord Naj'entus" => {
    mobStart => [ "High Warlord Naj'entus" ],
    mobContinue => [ "High Warlord Naj'entus" ],
    mobEnd => [ "High Warlord Naj'entus" ],
    timeout => 15,
},

"Supremus" => {
    mobStart => [ "Supremus" ],
    mobContinue => [ "Supremus" ],
    mobEnd => [ "Supremus" ],
    timeout => 15,
},

"Shade of Akama" => {
    mobStart => [ "Ashtongue Channeler", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue" ],
    mobContinue => [ "Ashtongue Channeler", "Ashtongue Defender", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue", "Shade of Akama", "Akama" ],
    mobEnd => [ "Shade of Akama" ],
    timeout => 15,
},

"Teron Gorefiend" => {
    mobStart => [ "Teron Gorefiend" ],
    mobContinue => [ "Teron Gorefiend" ],
    mobEnd => [ "Teron Gorefiend" ],
    timeout => 15,
},

"Gurtogg Bloodboil" => {
    mobStart => [ "Gurtogg Bloodboil" ],
    mobContinue => [ "Gurtogg Bloodboil" ],
    mobEnd => [ "Gurtogg Bloodboil" ],
    timeout => 15,
},

"Reliquary of Souls" => {
    mobStart => [ "Essence of Suffering" ],
    mobContinue => [ "Essence of Suffering", "Essence of Desire", "Essence of Anger", "Enslaved Soul" ],
    mobEnd => [ "Essence of Anger" ],
    timeout => 30,
},

"Mother Shahraz" => {
    mobStart => [ "Mother Shahraz" ],
    mobContinue => [ "Mother Shahraz" ],
    mobEnd => [ "Mother Shahraz" ],
    timeout => 15,
},

"Illidari Council" => {
    mobStart => [ "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobContinue => [ "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobEnd => [ "The Illidari Council" ],
    timeout => 30,
},

"Illidan Stormrage" => {
    mobStart => [ "Illidan Stormrage" ],
    mobContinue => [ "Illidan Stormrage", "Flame of Azzinoth" ],
    mobEnd => [ "Illidan Stormrage" ],
    timeout => 45,
},

###########
# SUNWELL #
###########

"Kalecgos" => {
    mobStart => [ "Kalecgos" ],
    mobContinue => [ "Kalecgos", "Sathrovarr the Corruptor" ],
    mobEnd => [ "Kalecgos", "Sathrovarr the Corruptor" ],
    timeout => 30,
},

"Brutallus" => {
    mobStart => [ "Brutallus" ],
    mobContinue => [ "Brutallus" ],
    mobEnd => [ "Brutallus" ],
    timeout => 30,
},

"Felmyst" => {
    mobStart => [ "Felmyst" ],
    mobContinue => [ "Felmyst" ],
    mobEnd => [ "Felmyst" ],
    timeout => 30,
},

"M'uru" => {
    mobStart => [ "M'uru" ],
    mobContinue => [ "M'uru", "Entropius" ],
    mobEnd => [ "M'uru" ],
    timeout => 30,
}

);

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{scratch} = {};
    $params{splits} = {};
    $params{nlog} = -1;
    
    bless \%params, $class;
}

sub process {
    my $self = shift;
    my $entry = shift;
    
    $self->{nlog} ++;
    return unless $entry->{action};
    
    # Continuously test for all fingerprints.
    while( my ($boss, $print) = each (%fingerprints) ) {
        # If we are currently in an encounter with this boss then see what we should do.
        if( $self->{scratch}{$boss}{start} ) {
            if( $entry->{t} > $self->{scratch}{$boss}{end} + $print->{timeout} ) {
                # This fingerprint timed out without ending.
                # Record it as an attempt, but disallow zero-length splits.
                
                $self->{scratch}{$boss}{attempt} ||= 0;
                $self->{scratch}{$boss}{attempt} ++;
                
                my $splitname = $boss . " try " . $self->{scratch}{$boss}{attempt};
                $self->{splits}{$splitname} = { start => $self->{scratch}{$boss}{start}, end => $self->{scratch}{$boss}{end}, startLine => $self->{scratch}{$boss}{startLine}, endLine => $self->{scratch}{$boss}{endLine}, kill => 0 } if $self->{scratch}{$boss}{end} && $self->{scratch}{$boss}{start} && $self->{scratch}{$boss}{end} - $self->{scratch}{$boss}{start} > 0;
                
                # Reset the start/end times for this fingerprint.
                $self->{scratch}{$boss}{start} = 0;
                $self->{scratch}{$boss}{end} = 0;
                
                # Maybe this is the start of a new encounter with this boss.
                my $shouldStart;
                foreach my $mobStart (@{ $print->{mobStart} }) {
                    if( (grep $entry->{action} eq $_, qw(SPELL_DAMAGE SPELL_DAMAGE_PERIODIC SPELL_MISS SWING_DAMAGE SWING_MISS)) && ($entry->{actor_name} eq $mobStart || $entry->{target_name} eq $mobStart) ) {
                        $shouldStart ++;
                    }
                }

                if( $shouldStart ) {
                    $self->{scratch}{$boss}{start} = $entry->{t};
                    $self->{scratch}{$boss}{end} = $entry->{t};
                    $self->{scratch}{$boss}{startLine} = $self->{nlog};
                    $self->{scratch}{$boss}{endLine} = $self->{nlog};
                }
            } else {
                # This fingerprint hasn't yet timed out. Possibly continue it.
                my $shouldContinue;
                foreach my $mobContinue (@{ $print->{mobContinue} }) {
                    if( $entry->{actor_name} eq $mobContinue || $entry->{target_name} eq $mobContinue ) {
                        $shouldContinue ++;
                    }
                }
                
                # Continue it if we decided to.
                if( $shouldContinue ) {
                    $self->{scratch}{$boss}{end} = $entry->{t};
                    $self->{scratch}{$boss}{endLine} = $self->{nlog};
                }
                
                # Also possibly end it.
                my $shouldEnd;
                foreach my $mobEnd (@{ $print->{mobEnd} }) {
                    if( $entry->{action} eq "UNIT_DIED" && $entry->{target_name} eq $mobEnd ) {
                        $shouldEnd ++;
                    }
                }
                
                # End it if we decided to.
                if( $shouldEnd ) {
                    $self->{splits}{$boss} = { start => $self->{scratch}{$boss}{start}, end => $self->{scratch}{$boss}{end}, startLine => $self->{scratch}{$boss}{startLine}, endLine => $self->{scratch}{$boss}{endLine}, kill => 1 };

                    # Reset the start/end times for this print.
                    $self->{scratch}{$boss}{start} = 0;
                    $self->{scratch}{$boss}{end} = 0;
                }
            }
        } else {
            # We aren't currently in an encounter with this boss. Maybe we should start one.
            my $shouldStart;
            foreach my $mobStart (@{ $print->{mobStart} }) {
                if( ($entry->{actor_name} eq $mobStart || $entry->{target_name} eq $mobStart) && (grep $entry->{action} eq $_, qw(SPELL_DAMAGE SPELL_DAMAGE_PERIODIC SPELL_MISS SWING_DAMAGE SWING_MISS)) ) {
                    $shouldStart ++;
                }
            }
            
            if( $shouldStart ) {
                $self->{scratch}{$boss}{start} = $entry->{t};
                $self->{scratch}{$boss}{end} = $entry->{t};
                $self->{scratch}{$boss}{startLine} = $self->{nlog};
                $self->{scratch}{$boss}{endLine} = $self->{nlog};
            }
        }
    }
}

sub finish {
    my $self = shift;
    
    # End of the log file -- close up any open bosses.
    while( my ($boss, $print) = each (%fingerprints) ) {
        if( $self->{scratch}{$boss}{start} ) {
            # Increment the attempt count.
            $self->{scratch}{$boss}{attempt} ||= 0;
            $self->{scratch}{$boss}{attempt} ++;
            
            # Record the attempt.
            my $splitname = $boss . " try " . $self->{scratch}{$boss}{attempt};
            
            if( $self->{scratch}{$boss}{end} && $self->{scratch}{$boss}{start} && $self->{scratch}{$boss}{end} - $self->{scratch}{$boss}{start} > 0 ) {
                $self->{splits}{$splitname} = { start => $self->{scratch}{$boss}{start}, end => $self->{scratch}{$boss}{end}, startLine => $self->{scratch}{$boss}{startLine}, endLine => $self->{scratch}{$boss}{endLine}, kill => 0 };
            }
        }
    }
    
    return %{$self->{splits}};
}

1;
