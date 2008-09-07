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
use Stasis::MobUtil;

# Fingerprints of various boss encounters.
my %fingerprints = (

############
# KARAZHAN #
############

"attumen" => {
    long => "Attumen the Huntsman",
    mobStart => [ 16151, "Midnight" ],
    mobContinue => [ 15550, 16151, "Attumen the Huntsman", "Midnight" ],
    mobEnd => [ 15550, "Attumen the Huntsman" ],
    timeout => 15,
},

"moroes" => {
    long => "Moroes",
    mobStart => [ 15687, "Moroes" ],
    mobContinue => [ 15687, "Moroes" ],
    mobEnd => [ 15687, "Moroes" ],
    timeout => 20,
},

"maiden" => {
    long => "Maiden of Virtue",
    mobStart => [ 16457, "Maiden of Virtue" ],
    mobContinue => [ 16457, "Maiden of Virtue" ],
    mobEnd => [ 16457, "Maiden of Virtue" ],
    timeout => 20,
},

"crone" => {
    long => "Opera (Wizard of Oz)",
    mobStart => [ 17535, 17548, 17543, 17547, 17546, "Dorothee", "Tito", "Strawman", "Tinhead", "Roar" ],
    mobContinue => [ 17535, 17548, 17543, 17547, 17546, 18168, "Dorothee", "Tito", "Strawman", "Tinhead", "Roar", "The Crone" ],
    mobEnd => [ 18168, "The Crone" ],
    timeout => 20,
},

"romulo" => {
    long => "Opera (Romulo and Julianne)",
    mobStart => [ 17534, "Julianne" ],
    mobContinue => [ 17533, 17534, "Romulo", "Julianne" ],
    mobEnd => [ 17533, 17534 ],
    endAll => 1,
    timeout => 20,
},

"bbw" => {
    long => "Opera (Red Riding Hood)",
    mobStart => [ 17521, "The Big Bad Wolf" ],
    mobContinue => [ 17521, "The Big Bad Wolf" ],
    mobEnd => [ 17521, "The Big Bad Wolf" ],
    timeout => 20,
},

"nightbane" => {
    long => "Nightbane",
    mobStart => [ 17225, "Nightbane" ],
    mobContinue => [ 17225, 17261, "Nightbane", "Restless Skeleton" ],
    mobEnd => [ 17225, "Nightbane" ],
    timeout => 30,
},

"curator" => {
    long => "The Curator",
    mobStart => [ 15691, "The Curator" ],
    mobContinue => [ 15691, "The Curator" ],
    mobEnd => [ 15691, "The Curator" ],
    timeout => 20,
},

"shade" => {
    long => "Shade of Aran",
    mobStart => [ 16524, "Shade of Aran" ],
    mobContinue => [ 16524, "Shade of Aran" ],
    mobEnd => [ 16524, "Shade of Aran" ],
    timeout => 20,
},

"illhoof" => {
    long => "Terestian Illhoof",
    mobStart => [ 15688, "Terestian Illhoof" ],
    mobContinue => [ 15688, "Terestian Illhoof" ],
    mobEnd => [ 15688, "Terestian Illhoof" ],
    timeout => 20,
},

"netherspite" => {
    long => "Netherspite",
    mobStart => [ 15689, "Netherspite" ],
    mobContinue => [ 15689, "Netherspite" ],
    mobEnd => [ 15689, "Netherspite" ],
    timeout => 45,
},

"prince" => {
    long => "Prince Malchezaar",
    mobStart => [ 15690, "Prince Malchezaar" ],
    mobContinue => [ 15690, "Prince Malchezaar" ],
    mobEnd => [ 15690, "Prince Malchezaar" ],
    timeout => 20,
},

############
# ZUL'AMAN #
############

"nalorakk" => {
    long => "Nalorakk",
    mobStart => [ 23576, "Nalorakk" ],
    mobContinue => [ 23576, "Nalorakk" ],
    mobEnd => [ 23576, "Nalorakk" ],
    timeout => 15,
},

"janalai" => {
    long => "Jan'alai",
    mobStart => [ 23578, "Jan'alai" ],
    mobContinue => [ 23578, "Jan'alai" ],
    mobEnd => [ 23578, "Jan'alai" ],
    timeout => 15,
},

"akilzon" => {
    long => "Akil'zon",
    mobStart => [ 23574, "Akil'zon" ],
    mobContinue => [ 23574, "Akil'zon" ],
    mobEnd => [ 23574, "Akil'zon" ],
    timeout => 15,
},

"halazzi" => {
    long => "Halazzi",
    mobStart => [ 23577, "Halazzi" ],
    mobContinue => [ 23577, "Halazzi" ],
    mobEnd => [ 23577, "Halazzi" ],
    timeout => 15,
},

"hexlord" => {
    long => "Hex Lord Malacrass",
    mobStart => [ 24239, "Hex Lord Malacrass" ],
    mobContinue => [ 24239, "Hex Lord Malacrass" ],
    mobEnd => [ 24239, "Hex Lord Malacrass" ],
    timeout => 15,
},

"zuljin" => {
    long => "Zul'jin",
    mobStart => [ 23863, "Zul'jin" ],
    mobContinue => [ 23863, "Zul'jin" ],
    mobEnd => [ 23863, "Zul'jin" ],
    timeout => 30,
},

#################
# GRUUL AND MAG #
#################

"maulgar" => {
    long => "High King Maulgar",
    mobStart => [ 18831, "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobContinue => [ 18831, "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobEnd => [ 18831, "High King Maulgar" ],
    timeout => 15,
},

"gruul" => {
    long => "Gruul the Dragonkiller",
    mobStart => [ 19044, "Gruul the Dragonkiller" ],
    mobContinue => [ 19044, "Gruul the Dragonkiller" ],
    mobEnd => [ 19044, "Gruul the Dragonkiller" ],
    timeout => 15,
},

"magtheridon" => {
    long => "Magtheridon",
    mobStart => [ 17256, "Hellfire Channeler" ],
    mobContinue => [ 17256, 17257, "Magtheridon", "Hellfire Channeler" ],
    mobEnd => [ 17257, "Magtheridon" ],
    timeout => 15,
},

########################
# SERPENTSHRINE CAVERN #
########################

"hydross" => {
    long => "Hydross the Unstable",
    mobStart => [ 21216, "Hydross the Unstable" ],
    mobContinue => [ 21216, "Hydross the Unstable" ],
    mobEnd => [ 21216, "Hydross the Unstable" ],
    timeout => 15,
},

"lurker" => {
    long => "The Lurker Below",
    mobStart => [ 21217, "The Lurker Below" ],
    mobContinue => [ 21217, 21865, 21873, "The Lurker Below", "Coilfang Ambusher", "Coilfang Guardian" ],
    mobEnd => [ 21217, "The Lurker Below" ],
    timeout => 15,
},

"leotheras" => {
    long => "Leotheras the Blind",
    mobStart => [ 21806, "Greyheart Spellbinder" ],
    mobContinue => [ 21806, 21215, "Greyheart Spellbinder", "Leotheras the Blind" ],
    mobEnd => [ 21215, "Leotheras the Blind" ],
    timeout => 15,
},

"flk" => {
    long => "Fathom-Lord Karathress",
    mobStart => [ 21214, "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobContinue => [ 21214, "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobEnd => [ 21214, "Fathom-Lord Karathress" ],
    timeout => 15,
},

"tidewalker" => {
    long => "Morogrim Tidewalker",
    mobStart => [ 21213, "Morogrim Tidewalker" ],
    mobContinue => [ 21213, "Morogrim Tidewalker" ],
    mobEnd => [ 21213, "Morogrim Tidewalker" ],
    timeout => 15,
},

"vashj" => {
    long => "Lady Vashj",
    mobStart => [ 21212, "Lady Vashj" ],
    mobContinue => [ 21212, 21958, 22056, 22055, 22009, "Lady Vashj", "Enchanted Elemental", "Tainted Elemental", "Coilfang Strider", "Coilfang Elite" ],
    mobEnd => [ 21212, "Lady Vashj" ],
    timeout => 15,
},

################
# TEMPEST KEEP #
################

"alar" => {
    long => "Al'ar",
    mobStart => [ 19514, "Al'ar" ],
    mobContinue => [ 19514, "Al'ar" ],
    mobEnd => [ 19514, "Al'ar" ],
    timeout => 30,
},

"vr" => {
    long => "Void Reaver",
    mobStart => [ 19516, "Void Reaver" ],
    mobContinue => [ 19516, "Void Reaver" ],
    mobEnd => [ 19516, "Void Reaver" ],
    timeout => 15,
},

"solarian" => {
    long => "High Astromancer Solarian",
    mobStart => [ 18805, "High Astromancer Solarian" ],
    mobContinue => [ 18805, 18806, 18925, "High Astromancer Solarian", "Solarium Priest", "Solarium Agent" ],
    mobEnd => [ 18805, "High Astromancer Solarian" ],
    timeout => 15,
},

"kaelthas" => {
    long => "Kael'thas Sunstrider",
    mobStart => [ 21272, 21273, 21269, 21268, 21274, 21271, 21270, "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser" ],
    mobContinue => [ 19622, 21272, 21273, 21269, 21268, 21274, 21271, 21270, 20063, 20062, 20064, 20060, "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser", "Kael'thas Sunstrider", "Phoenix", "Phoenix Egg", "Master Engineer Telonicus", "Grand Astromancer Capernian", "Thaladred the Darkener", "Lord Sanguinar" ],
    mobEnd => [ 19622, "Kael'thas Sunstrider" ],
    timeout => 15,
},

#########
# HYJAL #
#########

"rage" => {
    long => "Rage Winterchill",
    mobStart => [ 17767, "Rage Winterchill" ],
    mobContinue => [ 17767, "Rage Winterchill" ],
    mobEnd => [ 17767, "Rage Winterchill" ],
    timeout => 10,
},

"anetheron" => {
    long => "Anetheron",
    mobStart => [ 17808, "Anetheron" ],
    mobContinue => [ 17808, "Anetheron" ],
    mobEnd => [ 17808, "Anetheron" ],
    timeout => 10,
},

"kazrogal" => {
    long => "Kaz'rogal",
    mobStart => [ 17888, "Kaz'rogal" ],
    mobContinue => [ 17888, "Kaz'rogal" ],
    mobEnd => [ 17888, "Kaz'rogal" ],
    timeout => 10,
},

"azgalor" => {
    long => "Azgalor",
    mobStart => [ 17842, "Azgalor" ],
    mobContinue => [ 17842, "Azgalor" ],
    mobEnd => [ 17842, "Azgalor" ],
    timeout => 10,
},

"archimonde" => {
    long => "Archimonde",
    mobStart => [ 17968, "Archimonde" ],
    mobContinue => [ 17968, "Archimonde" ],
    mobEnd => [ 17968, "Archimonde" ],
    timeout => 30,
},

################
# BLACK TEMPLE #
################

"najentus" => {
    long => "High Warlord Naj'entus",
    mobStart => [ 22887, "High Warlord Naj'entus" ],
    mobContinue => [ 22887, "High Warlord Naj'entus" ],
    mobEnd => [ 22887, "High Warlord Naj'entus" ],
    timeout => 15,
},

"supremus" => {
    long => "Supremus",
    mobStart => [ 22898, "Supremus" ],
    mobContinue => [ 22898, "Supremus" ],
    mobEnd => [ 22898, "Supremus" ],
    timeout => 15,
},

"akama" => {
    long => "Shade of Akama",
    mobStart => [ 23421, 23524, 23523, 23318, "Ashtongue Channeler", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue" ],
    mobContinue => [ 23421, 23524, 23523, 23318, 22841, "Ashtongue Channeler", "Ashtongue Defender", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue", "Shade of Akama" ],
    mobEnd => [ 22841, "Shade of Akama" ],
    timeout => 15,
},

"teron" => {
    long => "Teron Gorefiend",
    mobStart => [ 22871, "Teron Gorefiend" ],
    mobContinue => [ 22871, "Teron Gorefiend" ],
    mobEnd => [ 22871, "Teron Gorefiend" ],
    timeout => 15,
},

"bloodboil" => {
    long => "Gurtogg Bloodboil",
    mobStart => [ 22948, "Gurtogg Bloodboil" ],
    mobContinue => [ 22948, "Gurtogg Bloodboil" ],
    mobEnd => [ 22948, "Gurtogg Bloodboil" ],
    timeout => 15,
},

"ros" => {
    long => "Reliquary of Souls",
    mobStart => [ 23418, "Essence of Suffering" ],
    mobContinue => [ 23418, 23419, 23420, 23469, "Essence of Suffering", "Essence of Desire", "Essence of Anger", "Enslaved Soul" ],
    mobEnd => [ 23420, "Essence of Anger" ],
    timeout => 20,
},

"shahraz" => {
    long => "Mother Shahraz",
    mobStart => [ 22947, "Mother Shahraz" ],
    mobContinue => [ 22947, "Mother Shahraz" ],
    mobEnd => [ 22947, "Mother Shahraz" ],
    timeout => 15,
},

"council" => {
    long => "Illidari Council",
    mobStart => [ 22950, 22952, 22951, 22949, "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobContinue => [ 22950, 22952, 22951, 22949, "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobEnd => [ 22950, 22952, 22951, 22949, 23426, "The Illidari Council" ],
    timeout => 15,
},

"illidan" => {
    long => "Illidan Stormrage",
    mobStart => [ 22917, "Illidan Stormrage" ],
    mobContinue => [ 22917, 22997, "Illidan Stormrage", "Flame of Azzinoth" ],
    mobEnd => [ 22917, "Illidan Stormrage" ],
    timeout => 45,
},

###########
# SUNWELL #
###########

"kalecgos" => {
    long => "Kalecgos",
    mobStart => [ 24850 ],
    mobContinue => [ 24850, 24892 ],
    mobEnd => [ 24892 ],
    timeout => 15,
},

"brutallus" => {
    long => "Brutallus",
    mobStart => [ 24882 ],
    mobContinue => [ 24882 ],
    mobEnd => [ 24882 ],
    timeout => 15,
},

"felmyst" => {
    long => "Felmyst",
    mobStart => [ 25038 ],
    mobContinue => [ 25038, 25268 ],
    mobEnd => [ 25038 ],
    timeout => 15,
},

"twins" => {
    long => "Eredar Twins",
    mobStart => [ 25166, 25165 ],
    mobContinue => [ 25166, 25165 ],
    mobEnd => [ 25166, 25165 ],
    timeout => 15,
    endAll => 1,
},

"muru" => {
    long => "M'uru",
    mobStart => [ 25741 ],
    mobContinue => [ 25741, 25840, 25798, 25799 ],
    mobEnd => [ 25840 ],
    timeout => 15,
},

"kiljaeden" => {
    long => "Kil'jaeden",
    mobStart => [ 25315 ],
    mobContinue => [ 25315 ],
    mobEnd => [ 25315 ],
    timeout => 30,
},

#############
# NAXXRAMAS #
#############

"anubrekhan" => {
    long => "Anub'Rekhan",
    mobStart => [ 15956 ],
    mobContinue => [ 15956 ],
    mobEnd => [ 15956 ],
    timeout => 15,
},

"faerlina" => {
    long => "Grand Widow Faerlina",
    mobStart => [ 15953 ],
    mobContinue => [ 15953 ],
    mobEnd => [ 15953 ],
    timeout => 15,
},

"maexxna" => {
    long => "Maexxna",
    mobStart => [ 15952 ],
    mobContinue => [ 15952 ],
    mobEnd => [ 15952 ],
    timeout => 15,
},

"patchwerk" => {
    long => "Patchwerk",
    mobStart => [ 16028 ],
    mobContinue => [ 16028 ],
    mobEnd => [ 16028 ],
    timeout => 15,
},

"grobbulus" => {
    long => "Grobbulus",
    mobStart => [ 15931 ],
    mobContinue => [ 15931 ],
    mobEnd => [ 15931 ],
    timeout => 15,
},

"gluth" => {
    long => "Gluth",
    mobStart => [ 15932 ],
    mobContinue => [ 15932, 16360 ],
    mobEnd => [ 15932 ],
    timeout => 15,
},

"thaddius" => {
    long => "Thaddius",
    mobStart => [ 15928, 15929, 15930 ],
    mobContinue => [ 15928, 15929, 15930 ],
    mobEnd => [ 15928 ],
    timeout => 15,
},

"razuvious" => {
    long => "Instructor Razuvious",
    mobStart => [ 16061 ],
    mobContinue => [ 16061, 16803 ],
    mobEnd => [ 16061 ],
    timeout => 15,
},

"gothik" => {
    long => "Gothik the Harvester",
    mobStart => [ 16060, 16124, 16125, 16126, 16127, 16148, 16150, 16149 ],
    mobContinue => [ 16060, 16124, 16125, 16126, 16127, 16148, 16150, 16149 ],
    mobEnd => [ 16060 ],
    timeout => 15,
    lockout => 120,
},

"horsemen" => {
    long => "Four Horsemen",
    mobStart => [ 16064, 16065, 30549, 16063 ],
    mobContinue => [ 16064, 16065, 30549, 16063 ],
    mobEnd => [ 16064, 16065, 30549, 16063 ],
    timeout => 15,
    endAll => 1,
},

"noth" => {
    long => "Noth the Plaguebringer",
    mobStart => [ 15954 ],
    mobContinue => [ 15954, 16983, 16981 ],
    mobEnd => [ 15954 ],
    timeout => 15,
},

"heigan" => {
    long => "Heigan the Unclean",
    mobStart => [ 15936 ],
    mobContinue => [ 15936, 16236 ],
    mobEnd => [ 15936 ],
    timeout => 15,
},

"loatheb" => {
    long => "Loatheb",
    mobStart => [ 16011 ],
    mobContinue => [ 16011 ],
    mobEnd => [ 16011 ],
    timeout => 15,
},

"sapphiron" => {
    long => "Sapphiron",
    mobStart => [ 15989 ],
    mobContinue => [ 15989 ],
    mobEnd => [ 15989 ],
    timeout => 15,
},

"kelthuzad" => {
    long => "Kel'thuzad",
    mobStart => [ 15990, 16427, 16428, 16429 ],
    mobContinue => [ 15990, 16427, 16428, 16429, 16441 ],
    mobEnd => [ 15990 ],
    timeout => 15,
},

);

# Invert the %fingerprints hash.
my %fstart;
my %fcontinue;
my %fend;

while( my ($kprint, $vprint) = each %fingerprints ) {
    foreach (@{$vprint->{mobStart}}) {
        $fstart{$_} = $kprint;
    }
    
    foreach (@{$vprint->{mobContinue}}) {
        $fcontinue{$_} = $kprint;
    }
    
    foreach (@{$vprint->{mobEnd}}) {
        $fend{$_} = $kprint;
    }
}

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{scratch} = {};
    $params{splits} = [];
    $params{lastkill} = {};
    
    # Callback args:
    # at split start:   ( $short, $start )
    # at split end:     ( $short, $start, $long, $kill, $end )
    $params{callback} ||= undef;
    
    bless \%params, $class;
}

sub process {
    my ($self, $entry) = @_;
    
    # Figure out what to use for the actor and target identifiers.
    # This will be either the name (version 1) or the NPC part of the ID (version 2)
    
    my ($atype, $anpc, $aspawn ) = Stasis::MobUtil::splitguid( $entry->{actor} );
    my ($ttype, $tnpc, $tspawn ) = Stasis::MobUtil::splitguid( $entry->{target} );
    
    my $actor_id = $anpc || $entry->{actor};
    my $target_id = $tnpc || $entry->{target};
    
    # See if we should end, or continue, an encounter currently in progress.
    while( my ($kboss, $vboss) = each %{$self->{scratch}} ) {
        # If we are currently in an encounter with this boss then see what we should do.
        if( $vboss->{start} ) {
            if( $entry->{t} > $vboss->{end} + $fingerprints{$kboss}{timeout} ) {
                # This fingerprint timed out without ending.
                # Record it as an attempt.
                
                $self->_bend(
                    $kboss,
                    $vboss->{start},
                    $fingerprints{$kboss}{long},
                    0,
                    $vboss->{end},
                );
                
                # Reset this fingerprint.
                delete $self->{scratch}{$kboss};
            } elsif( ($fcontinue{$actor_id} && $fcontinue{$actor_id} eq $kboss) || ($fcontinue{$target_id} && $fcontinue{$target_id} eq $kboss) ) {
                # We should continue this encounter.
                $vboss->{end} = $entry->{t};

                # Also possibly end it.
                if( $entry->{action} eq "UNIT_DIED" && $fend{$target_id} && $fend{$target_id} eq $kboss ) {
                    $vboss->{dead}{$target_id} = 1;
                    
                    if( !$fingerprints{$kboss}{endAll} || ( scalar keys %{$vboss->{dead}} == scalar @{$fingerprints{$kboss}{mobEnd}} ) ) {
                        $self->_bend(
                            $kboss,
                            $vboss->{start},
                            $fingerprints{$kboss}{long},
                            1,
                            $vboss->{end},
                        );

                        # Reset this fingerprint.
                        delete $self->{scratch}{$kboss};
                    }
                }
            }
        }
    }
    
    # See if we should start a new encounter.
    if( !$self->{go} ) {
        if( $fstart{$actor_id} && !$self->{scratch}{$fstart{$actor_id}}{start} && (grep $entry->{action} eq $_, qw(SPELL_DAMAGE SPELL_DAMAGE_PERIODIC SPELL_MISS SWING_DAMAGE SWING_MISS)) ) {
            # Check timeout.
            my $timeout = $fingerprints{$fstart{$actor_id}}{timeout};
            if( !$timeout || !$self->{lastkill}{$fstart{$actor_id}} || $entry->{t} - $self->{lastkill}{$fstart{$actor_id}} >= $timeout ) {
                # The actor should start a new encounter.
                $self->{scratch}{$fstart{$actor_id}}{start} = $entry->{t};
                $self->{scratch}{$fstart{$actor_id}}{end} = $entry->{t};

                my $short = $fingerprints{$fstart{$actor_id}}{short} || lc $fstart{$actor_id};
                $short =~ s/\s+.*$//;
                $short =~ s/[^\w]//g;
                $self->_bstart( $short, $entry->{t} );
            }
        }

        if( $fstart{$target_id} && !$self->{scratch}{$fstart{$target_id}}{start} && (grep $entry->{action} eq $_, qw(SPELL_DAMAGE SPELL_DAMAGE_PERIODIC SPELL_MISS SWING_DAMAGE SWING_MISS)) ) {
            my $timeout = $fingerprints{$fstart{$target_id}}{timeout};
            if( !$timeout || !$self->{lastkill}{$fstart{$target_id}} || $entry->{t} - $self->{lastkill}{$fstart{$target_id}} >= $timeout ) {
                # The target should start a new encounter.
                $self->{scratch}{$fstart{$target_id}}{start} = $entry->{t};
                $self->{scratch}{$fstart{$target_id}}{end} = $entry->{t};

                my $short = $fingerprints{$fstart{$target_id}}{short} || lc $fstart{$target_id};
                $short =~ s/\s+.*$//;
                $short =~ s/[^\w]//g;
                $self->_bstart( $short, $entry->{t} );
            }
        }
    }
}

sub _bstart {
    my ( $self, $short, $start ) = @_;
    
    $self->{go} = 1;
    
    # Callback.
    $self->{callback}->(
        $short, 
        $start
    ) if( $self->{callback} );
}

sub _bend {
    my ( $self, $short, $start, $long, $kill, $end ) = @_;
    
    $self->{go} = 0;
    $self->{lastkill}{$short} = $end if $kill;
    
    push @{$self->{splits}}, {
        short => $short,
        long => $long,
        start => $start,
        kill => $kill,
        end => $end,
    };
    
    # Callback.
    $self->{callback}->(
        $short, 
        $start,
        $long,
        $kill,
        $end,
    ) if( $self->{callback} );
}

sub finish {
    my $self = shift;
    
    # End of the log file -- close up any open bosses.
    while( my ($boss, $print) = each (%fingerprints) ) {
        if( $self->{scratch}{$boss}{start} ) {
            if( $self->{scratch}{$boss}{end} && $self->{scratch}{$boss}{start} ) {
                $self->_bend(
                    $boss,
                    $self->{scratch}{$boss}{start},
                    $fingerprints{$boss}{long},
                    0,
                    $self->{scratch}{$boss}{end},
                );
            }
        }
    }
    
    # Delete scratch.
    delete $self->{scratch};
    
    # Return.
    return @{$self->{splits}};
}

1;
