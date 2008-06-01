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

"Attumen the Huntsman" => {
    mobStart => [ "16151", "Midnight" ],
    mobContinue => [ "15550", "16151", "Attumen the Huntsman", "Midnight" ],
    mobEnd => [ "15550", "Attumen the Huntsman" ],
    timeout => 15,
},

"Moroes" => {
    mobStart => [ "15687", "Moroes" ],
    mobContinue => [ "15687", "Moroes" ],
    mobEnd => [ "15687", "Moroes" ],
    timeout => 20,
},

"Maiden of Virtue" => {
    mobStart => [ "16457", "Maiden of Virtue" ],
    mobContinue => [ "16457", "Maiden of Virtue" ],
    mobEnd => [ "16457", "Maiden of Virtue" ],
    timeout => 20,
},

"Opera (Wizard of Oz)" => {
    mobStart => [ "17535", "17548", "17543", "17547", "17546", "Dorothee", "Tito", "Strawman", "Tinhead", "Roar" ],
    mobContinue => [ "17535", "17548", "17543", "17547", "17546", "18168", "Dorothee", "Tito", "Strawman", "Tinhead", "Roar", "The Crone" ],
    mobEnd => [ "18168", "The Crone" ],
    timeout => 20,
},

# FIXME: Encounter doesn't end properly
"Opera (Romulo and Julianne)" => {
    mobStart => [ "17534", "Julianne" ],
    mobContinue => [ "17533", "17534", "Romulo", "Julianne" ],
    mobEnd => [],
    timeout => 20,
},

"Opera (Red Riding Hood)" => {
    mobStart => [ "17521", "The Big Bad Wolf" ],
    mobContinue => [ "17521", "The Big Bad Wolf" ],
    mobEnd => [ "17521", "The Big Bad Wolf" ],
    timeout => 20,
},

"Nightbane" => {
    mobStart => [ "17225", "Nightbane" ],
    mobContinue => [ "17225", "17261", "Nightbane", "Restless Skeleton" ],
    mobEnd => [ "17225", "Nightbane" ],
    timeout => 30,
},

"The Curator" => {
    short => "curator",
    mobStart => [ "15691", "The Curator" ],
    mobContinue => [ "15691", "The Curator" ],
    mobEnd => [ "15691", "The Curator" ],
    timeout => 20,
},

"Shade of Aran" => {
    mobStart => [ "16524", "Shade of Aran" ],
    mobContinue => [ "16524", "Shade of Aran" ],
    mobEnd => [ "16524", "Shade of Aran" ],
    timeout => 20,
},

"Terestian Illhoof" => {
    short => "illhoof",
    mobStart => [ "15688", "Terestian Illhoof" ],
    mobContinue => [ "15688", "Terestian Illhoof" ],
    mobEnd => [ "15688", "Terestian Illhoof" ],
    timeout => 20,
},

"Netherspite" => {
    mobStart => [ "15689", "Netherspite" ],
    mobContinue => [ "15689", "Netherspite" ],
    mobEnd => [ "15689", "Netherspite" ],
    timeout => 45,
},

"Prince Malchezaar" => {
    mobStart => [ "15690", "Prince Malchezaar" ],
    mobContinue => [ "15690", "Prince Malchezaar" ],
    mobEnd => [ "15690", "Prince Malchezaar" ],
    timeout => 20,
},

############
# ZUL'AMAN #
############

"Nalorakk" => {
    mobStart => [ "23576", "Nalorakk" ],
    mobContinue => [ "23576", "Nalorakk" ],
    mobEnd => [ "23576", "Nalorakk" ],
    timeout => 15,
},

"Jan'alai" => {
    mobStart => [ "23578", "Jan'alai" ],
    mobContinue => [ "23578", "Jan'alai" ],
    mobEnd => [ "23578", "Jan'alai" ],
    timeout => 15,
},

"Akil'zon" => {
    mobStart => [ "23574", "Akil'zon" ],
    mobContinue => [ "23574", "Akil'zon" ],
    mobEnd => [ "23574", "Akil'zon" ],
    timeout => 15,
},

"Halazzi" => {
    mobStart => [ "23577", "Halazzi" ],
    mobContinue => [ "23577", "Halazzi" ],
    mobEnd => [ "23577", "Halazzi" ],
    timeout => 15,
},

"Hex Lord Malacrass" => {
    short => "hexlord",
    mobStart => [ "24239", "Hex Lord Malacrass" ],
    mobContinue => [ "24239", "Hex Lord Malacrass" ],
    mobEnd => [ "24239", "Hex Lord Malacrass" ],
    timeout => 15,
},

"Zul'jin" => {
    mobStart => [ "23863", "Zul'jin" ],
    mobContinue => [ "23863", "Zul'jin" ],
    mobEnd => [ "23863", "Zul'jin" ],
    timeout => 30,
},

#################
# GRUUL AND MAG #
#################

"High King Maulgar" => {
    short => "maulgar",
    mobStart => [ "18831", "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobContinue => [ "18831", "High King Maulgar", "Kiggler the Crazed", "Krosh Firehand", "Olm the Summoner", "Blindeye the Seer" ],
    mobEnd => [ "18831", "High King Maulgar" ],
    timeout => 15,
},

"Gruul the Dragonkiller" => {
    short => "gruul",
    mobStart => [ "19044", "Gruul the Dragonkiller" ],
    mobContinue => [ "19044", "Gruul the Dragonkiller" ],
    mobEnd => [ "19044", "Gruul the Dragonkiller" ],
    timeout => 15,
},

"Magtheridon" => {
    short => "mag",
    mobStart => [ "17257", "Hellfire Channeler" ],
    mobContinue => [ "17256", "17257", "Magtheridon", "Hellfire Channeler" ],
    mobEnd => [ "17257", "Magtheridon" ],
    timeout => 15,
},

########################
# SERPENTSHRINE CAVERN #
########################

"Hydross the Unstable" => {
    mobStart => [ "21216", "Hydross the Unstable" ],
    mobContinue => [ "21216", "Hydross the Unstable" ],
    mobEnd => [ "21216", "Hydross the Unstable" ],
    timeout => 15,
},

"The Lurker Below" => {
    short => "lurker",
    mobStart => [ "21217", "The Lurker Below" ],
    mobContinue => [ "21217", "21865", "21873", "The Lurker Below", "Coilfang Ambusher", "Coilfang Guardian" ],
    mobEnd => [ "21217", "The Lurker Below" ],
    timeout => 15,
},

"Leotheras the Blind" => {
    short => "leo",
    mobStart => [ "21806", "Greyheart Spellbinder" ],
    mobContinue => [ "21806", "21215", "Greyheart Spellbinder", "Leotheras the Blind" ],
    mobEnd => [ "21215", "Leotheras the Blind" ],
    timeout => 15,
},

"Fathom-Lord Karathress" => {
    short => "flk",
    mobStart => [ "21214", "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobContinue => [ "21214", "Fathom-Lord Karathress", "Fathom-Guard Caribdis", "Fathom-Guard Sharkkis", "Fathom-Guard Tidalvess" ],
    mobEnd => [ "21214", "Fathom-Lord Karathress" ],
    timeout => 15,
},

"Morogrim Tidewalker" => {
    short => "tidewalker",
    mobStart => [ "21213", "Morogrim Tidewalker" ],
    mobContinue => [ "21213", "Morogrim Tidewalker" ],
    mobEnd => [ "21213", "Morogrim Tidewalker" ],
    timeout => 15,
},

"Lady Vashj" => {
    short => "vashj",
    mobStart => [ "21212", "Lady Vashj" ],
    mobContinue => [ "21212", "21958", "22056", "22055", "22009", "Lady Vashj", "Enchanted Elemental", "Tainted Elemental", "Coilfang Strider", "Coilfang Elite" ],
    mobEnd => [ "21212", "Lady Vashj" ],
    timeout => 15,
},

################
# TEMPEST KEEP #
################

"Al'ar" => {
    mobStart => [ "19514", "Al'ar" ],
    mobContinue => [ "19514", "Al'ar" ],
    mobEnd => [ "19514", "Al'ar" ],
    timeout => 30,
},

"Void Reaver" => {
    short => "vr",
    mobStart => [ "19516", "Void Reaver" ],
    mobContinue => [ "19516", "Void Reaver" ],
    mobEnd => [ "19516", "Void Reaver" ],
    timeout => 15,
},

"High Astromancer Solarian" => {
    short => "solarian",
    mobStart => [ "18805", "High Astromancer Solarian" ],
    mobContinue => [ "18805", "18806", "18925", "High Astromancer Solarian", "Solarium Priest", "Solarium Agent" ],
    mobEnd => [ "18805", "High Astromancer Solarian" ],
    timeout => 15,
},

"Kael'thas Sunstrider" => {
    short => "kael",
    mobStart => [ "21272", "21273", "21269", "21268", "21274", "21271", "21270", "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser" ],
    mobContinue => [ "19622", "21272", "21273", "21269", "21268", "21274", "21271", "21270", "20063", "20062", "20064", "20060", "Warp Slicer", "Phaseshift Bulwark", "Devastation", "Netherstrand Longbow", "Staff of Disintegration", "Infinity Blades", "Cosmic Infuser", "Kael'thas Sunstrider", "Phoenix", "Phoenix Egg", "Master Engineer Telonicus", "Grand Astromancer Capernian", "Thaladred the Darkener", "Lord Sanguinar" ],
    mobEnd => [ "19622", "Kael'thas Sunstrider" ],
    timeout => 15,
},

#########
# HYJAL #
#########

"Rage Winterchill" => {
    mobStart => [ "17767", "Rage Winterchill" ],
    mobContinue => [ "17767", "Rage Winterchill" ],
    mobEnd => [ "17767", "Rage Winterchill" ],
    timeout => 10,
},

"Anetheron" => {
    mobStart => [ "17808", "Anetheron" ],
    mobContinue => [ "17808", "Anetheron" ],
    mobEnd => [ "17808", "Anetheron" ],
    timeout => 10,
},

"Kaz'rogal" => {
    mobStart => [ "17888", "Kaz'rogal" ],
    mobContinue => [ "17888", "Kaz'rogal" ],
    mobEnd => [ "17888", "Kaz'rogal" ],
    timeout => 10,
},

"Azgalor" => {
    mobStart => [ "17842", "Azgalor" ],
    mobContinue => [ "17842", "Azgalor" ],
    mobEnd => [ "17842", "Azgalor" ],
    timeout => 10,
},

"Archimonde" => {
    mobStart => [ "17968", "Archimonde" ],
    mobContinue => [ "17968", "Archimonde" ],
    mobEnd => [ "17968", "Archimonde" ],
    timeout => 30,
},

################
# BLACK TEMPLE #
################

"High Warlord Naj'entus" => {
    short => "najentus",
    mobStart => [ "22887", "High Warlord Naj'entus" ],
    mobContinue => [ "22887", "High Warlord Naj'entus" ],
    mobEnd => [ "22887", "High Warlord Naj'entus" ],
    timeout => 15,
},

"Supremus" => {
    mobStart => [ "22898", "Supremus" ],
    mobContinue => [ "22898", "Supremus" ],
    mobEnd => [ "22898", "Supremus" ],
    timeout => 15,
},

"Shade of Akama" => {
    short => "akama",
    mobStart => [ "23421", "23524", "23523", "23318", "Ashtongue Channeler", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue" ],
    mobContinue => [ "23421", "23524", "23523", "23318", "22841", "Ashtongue Channeler", "Ashtongue Defender", "Ashtongue Spiritbinder", "Ashtongue Elementalist", "Ashtongue Rogue", "Shade of Akama" ],
    mobEnd => [ "22841", "Shade of Akama" ],
    timeout => 15,
},

"Teron Gorefiend" => {
    mobStart => [ "22871", "Teron Gorefiend" ],
    mobContinue => [ "22871", "Teron Gorefiend" ],
    mobEnd => [ "22871", "Teron Gorefiend" ],
    timeout => 15,
},

"Gurtogg Bloodboil" => {
    short => "bloodboil",
    mobStart => [ "22948", "Gurtogg Bloodboil" ],
    mobContinue => [ "22948", "Gurtogg Bloodboil" ],
    mobEnd => [ "22948", "Gurtogg Bloodboil" ],
    timeout => 15,
},

"Reliquary of Souls" => {
    short => "ros",
    mobStart => [ "23418", "Essence of Suffering" ],
    mobContinue => [ "23418", "23419", "23420", "23469", "Essence of Suffering", "Essence of Desire", "Essence of Anger", "Enslaved Soul" ],
    mobEnd => [ "23420", "Essence of Anger" ],
    timeout => 30,
},

"Mother Shahraz" => {
    short => "shahraz",
    mobStart => [ "22947", "Mother Shahraz" ],
    mobContinue => [ "22947", "Mother Shahraz" ],
    mobEnd => [ "22947", "Mother Shahraz" ],
    timeout => 15,
},

"Illidari Council" => {
    short => "council",
    mobStart => [ "22950", "22952", "22951", "22949", "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobContinue => [ "22950", "22952", "22951", "22949", "High Nethermancer Zerevor", "Veras Darkshadow", "Lady Malande", "Gathios the Shatterer" ],
    mobEnd => [ "23426", "The Illidari Council" ],
    timeout => 30,
},

"Illidan Stormrage" => {
    mobStart => [ "22917", "Illidan Stormrage" ],
    mobContinue => [ "22917", "22997", "Illidan Stormrage", "Flame of Azzinoth" ],
    mobEnd => [ "22917", "Illidan Stormrage" ],
    timeout => 45,
},

###########
# SUNWELL #
###########

"Kalecgos" => {
    mobStart => [ "24850" ],
    mobContinue => [ "24850", "24892" ],
    mobEnd => [ "24892" ],
    timeout => 30,
},

"Brutallus" => {
    mobStart => [ "24882" ],
    mobContinue => [ "24882" ],
    mobEnd => [ "24882" ],
    timeout => 30,
},

"Felmyst" => {
    mobStart => [ "25038" ],
    mobContinue => [ "25038", "25268" ],
    mobEnd => [ "25038" ],
    timeout => 30,
},

# FIXME: encounter never ends
"Eredar Twins" => {
    mobStart => [ "25166", "25165" ],
    mobContinue => [ "25166", "25165" ],
    mobEnd => [],
    timeout => 30,
},

# FIXME: encounter never ends
"M'uru" => {
    mobStart => [ "25741" ],
    mobContinue => [ "25741", "25840" ],
    mobEnd => [],
    timeout => 30,
},

"Kil'jaeden" => {
    mobStart => [ "25315" ],
    mobContinue => [ "25315" ],
    mobEnd => [ "25315" ],
    timeout => 30,
},

);

# Invert the %fingerprints hash.
my %fstart;
my %fcontinue;
my %fend;

{
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
}

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
    
    # Figure out what to use for the actor and target identifiers.
    # This will be either the name (version 1) or the NPC part of the ID (version 2)
    
    my ($atype, $anpc, $aspawn ) = Stasis::MobUtil->splitguid( $entry->{actor} );
    my ($ttype, $tnpc, $tspawn ) = Stasis::MobUtil->splitguid( $entry->{target} );
    
    my $actor_id = $anpc || $entry->{actor};
    my $target_id = $tnpc || $entry->{target};
    
    # See if we should end, or continue, an encounter currently in progress.
    while( my ($kboss, $vboss) = each %{$self->{scratch}} ) {
        # If we are currently in an encounter with this boss then see what we should do.
        if( $vboss->{start} ) {
            if( $entry->{t} > $vboss->{end} + $fingerprints{$kboss}{timeout} ) {
                # This fingerprint timed out without ending.
                # Record it as an attempt, but disallow zero-length splits.
                
                $vboss->{attempt} ||= 0;
                $vboss->{attempt} ++;
                
                my $splitname = $kboss . " try " . $self->{scratch}{$kboss}{attempt};
                
                # Figure out short name.
                my $short = $fingerprints{$kboss}{short} || lc $kboss;
                $short =~ s/\s+.*$//;
                $short =~ s/[^\w]//g;
                
                $self->{splits}{$splitname} = { short => $short, long => $splitname, start => $self->{scratch}{$kboss}{start}, end => $self->{scratch}{$kboss}{end}, startLine => $self->{scratch}{$kboss}{startLine}, endLine => $self->{scratch}{$kboss}{endLine}, kill => 0 } if $self->{scratch}{$kboss}{end} && $self->{scratch}{$kboss}{start};
                
                # Reset the start/end times for this fingerprint.
                $self->{scratch}{$kboss}{start} = 0;
                $self->{scratch}{$kboss}{end} = 0;
            } elsif( ($fcontinue{$actor_id} && $fcontinue{$actor_id} eq $kboss) || ($fcontinue{$target_id} && $fcontinue{$target_id} eq $kboss) ) {
                # We should continue this encounter.
                $self->{scratch}{$kboss}{end} = $entry->{t};
                $self->{scratch}{$kboss}{endLine} = $self->{nlog};

                # Also possibly end it.
                if( $entry->{action} eq "UNIT_DIED" && $fend{$target_id} && $fend{$target_id} eq $kboss ) {
                    # Figure out short name.
                    my $short = $fingerprints{$kboss}{short} || lc $kboss;
                    $short =~ s/\s+.*$//;
                    $short =~ s/[^\w]//g;

                    $self->{splits}{$kboss} = { short => $short, long => $kboss, start => $self->{scratch}{$kboss}{start}, end => $self->{scratch}{$kboss}{end}, startLine => $self->{scratch}{$kboss}{startLine}, endLine => $self->{scratch}{$kboss}{endLine}, kill => 1 };

                    # Reset the start/end times for this fingerprint.
                    $self->{scratch}{$kboss}{start} = 0;
                    $self->{scratch}{$kboss}{end} = 0;
                }
            }
        }
    }
    
    # See if we should start a new encounter.
    if( $fstart{$actor_id} && !$self->{scratch}{$fstart{$actor_id}}{start} && (grep $entry->{action} eq $_, qw(SPELL_DAMAGE SPELL_DAMAGE_PERIODIC SPELL_MISS SWING_DAMAGE SWING_MISS)) ) {
        # The actor should start a new encounter.
        $self->{scratch}{$fstart{$actor_id}}{start} = $entry->{t};
        $self->{scratch}{$fstart{$actor_id}}{end} = $entry->{t};
        $self->{scratch}{$fstart{$actor_id}}{startLine} = $self->{nlog};
        $self->{scratch}{$fstart{$actor_id}}{endLine} = $self->{nlog};
    }
    
    if( $fstart{$target_id} && !$self->{scratch}{$fstart{$target_id}}{start} && (grep $entry->{action} eq $_, qw(SPELL_DAMAGE SPELL_DAMAGE_PERIODIC SPELL_MISS SWING_DAMAGE SWING_MISS)) ) {
        # The target should start a new encounter.
        $self->{scratch}{$fstart{$target_id}}{start} = $entry->{t};
        $self->{scratch}{$fstart{$target_id}}{end} = $entry->{t};
        $self->{scratch}{$fstart{$target_id}}{startLine} = $self->{nlog};
        $self->{scratch}{$fstart{$target_id}}{endLine} = $self->{nlog};
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
            
            # Figure out short name.
            my $short = $print->{short} || lc $boss;
            $short =~ s/\s+.*$//;
            $short =~ s/[^\w]//g;
            
            if( $self->{scratch}{$boss}{end} && $self->{scratch}{$boss}{start} ) {
                $self->{splits}{$splitname} = { short => $short, long => $splitname, start => $self->{scratch}{$boss}{start}, end => $self->{scratch}{$boss}{end}, startLine => $self->{scratch}{$boss}{startLine}, endLine => $self->{scratch}{$boss}{endLine}, kill => 0 };
            }
        }
    }
    
    # Remove splits that make no sense.
    foreach my $split (values %{$self->{splits}}) {
        # Check zero or negative line length.
        if( $split->{endLine} - $split->{startLine} <= 0 ) {
            $split->{delete} = 1;
        }
        
        # Check zero or negative time.
        if( $split->{end} - $split->{start} <= 0 ) {
            $split->{delete} = 1;
        }
    }
    
    # Remove smaller splits that intersect with larger ones.
    foreach my $split1 (values %{$self->{splits}}) {
        foreach my $split2 (values %{$self->{splits}}) {
            # Don't process identical splits
            next if $split1->{long} eq $split2->{long};
            
            # Don't process splits already marked for deletion.
            next if $split1->{delete} || $split2->{delete};
            
            # If split2 is smaller than split1 and intersects, remove it.
            my $size1 = $split1->{endLine} - $split1->{startLine};
            my $size2 = $split2->{endLine} - $split2->{startLine};
            if( 
                $size1 >= $size2 && 
                (
                    (
                        $split2->{startLine} <= $split1->{endLine} && 
                        $split2->{startLine} >= $split1->{startLine}
                    ) ||
                    (
                        $split2->{endLine} <= $split1->{endLine} && 
                        $split2->{endLine} >= $split1->{startLine}
                    )
                )
            )
            {
                $split2->{delete} = 1;
            }
        }
    }
    
    my @splitret;
    foreach my $split (values %{$self->{splits}}) {
        if( !$split->{delete} ) {
            push @splitret, $split;
        }
    }
    
    # Sort the splits chronologically.
    return sort {
        $a->{startLine} <=> $b->{startLine}
    } @splitret;
}

1;
