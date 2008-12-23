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

package Stasis::Parser;

=head1 NAME

Stasis::Parser - parse a log file into a list of combat actions.

=head1 SYNOPSIS

    use Stasis::Parser;
    
    my $parser = Stasis::Parser->new( version => 2, year => 2008 );
    while( <STDIN> ) {
        $action = $parser->parse( $_ );
        print $parser->toString( $action ) . "\n";
    }

=head1 METHODS

=cut

use strict;
use warnings;
use POSIX;
use Carp;

# Constants from the 2.4 combat log
use constant {
    SWING_DAMAGE => 1,
    SWING_MISSED => 2,
    RANGE_DAMAGE => 3,
    RANGE_MISSED => 4,
    SPELL_DAMAGE => 5,
    SPELL_MISSED => 6,
    SPELL_HEAL => 7,
    SPELL_ENERGIZE => 8,
    SPELL_PERIODIC_MISSED => 9,
    SPELL_PERIODIC_DAMAGE => 10,
    SPELL_PERIODIC_HEAL => 11,
    SPELL_PERIODIC_DRAIN => 12,
    SPELL_PERIODIC_LEECH => 13,
    SPELL_PERIODIC_ENERGIZE => 14,
    SPELL_DRAIN => 15,
    SPELL_LEECH => 16,
    SPELL_INTERRUPT => 17,
    SPELL_EXTRA_ATTACKS => 18,
    SPELL_INSTAKILL => 19,
    SPELL_DURABILITY_DAMAGE => 20,
    SPELL_DURABILITY_DAMAGE_ALL => 21,
    SPELL_DISPEL_FAILED => 22,
    SPELL_AURA_DISPELLED => 23,
    SPELL_AURA_STOLEN => 24,
    SPELL_AURA_APPLIED => 25,
    SPELL_AURA_REMOVED => 26,
    SPELL_AURA_APPLIED_DOSE => 27,
    SPELL_AURA_REMOVED_DOSE => 28,
    SPELL_CAST_START => 29,
    SPELL_CAST_SUCCESS => 30,
    SPELL_CAST_FAILED => 31,
    DAMAGE_SHIELD => 32,
    DAMAGE_SHIELD_MISSED => 33,
    ENCHANT_APPLIED => 34,
    ENCHANT_REMOVED => 35,
    ENVIRONMENTAL_DAMAGE => 36,
    DAMAGE_SPLIT => 37,
    UNIT_DIED => 38,
    SPELL_SUMMON => 39,
    SPELL_CREATE => 40,
    PARTY_KILL => 41,
    UNIT_DESTROYED => 42,
    SPELL_AURA_REFRESH => 43,
    SPELL_AURA_BROKEN_SPELL => 44,
    SPELL_DISPEL => 45,
    SPELL_STOLEN => 46,
    SPELL_AURA_BROKEN => 47,
    SPELL_RESURRECT => 48,
    SPELL_BUILDING_DAMAGE => 49,
};

our %action_map = (
    SWING_DAMAGE => 1,
    SWING_MISSED => 2,
    RANGE_DAMAGE => 3,
    RANGE_MISSED => 4,
    SPELL_DAMAGE => 5,
    SPELL_MISSED => 6,
    SPELL_HEAL => 7,
    SPELL_ENERGIZE => 8,
    SPELL_PERIODIC_MISSED => 9,
    SPELL_PERIODIC_DAMAGE => 10,
    SPELL_PERIODIC_HEAL => 11,
    SPELL_PERIODIC_DRAIN => 12,
    SPELL_PERIODIC_LEECH => 13,
    SPELL_PERIODIC_ENERGIZE => 14,
    SPELL_DRAIN => 15,
    SPELL_LEECH => 16,
    SPELL_INTERRUPT => 17,
    SPELL_EXTRA_ATTACKS => 18,
    SPELL_INSTAKILL => 19,
    SPELL_DURABILITY_DAMAGE => 20,
    SPELL_DURABILITY_DAMAGE_ALL => 21,
    SPELL_DISPEL_FAILED => 22,
    SPELL_AURA_DISPELLED => 23,
    SPELL_AURA_STOLEN => 24,
    SPELL_AURA_APPLIED => 25,
    SPELL_AURA_REMOVED => 26,
    SPELL_AURA_APPLIED_DOSE => 27,
    SPELL_AURA_REMOVED_DOSE => 28,
    SPELL_CAST_START => 29,
    SPELL_CAST_SUCCESS => 30,
    SPELL_CAST_FAILED => 31,
    DAMAGE_SHIELD => 32,
    DAMAGE_SHIELD_MISSED => 33,
    ENCHANT_APPLIED => 34,
    ENCHANT_REMOVED => 35,
    ENVIRONMENTAL_DAMAGE => 36,
    DAMAGE_SPLIT => 37,
    UNIT_DIED => 38,
    SPELL_SUMMON => 39,
    SPELL_CREATE => 40,
    PARTY_KILL => 41,
    UNIT_DESTROYED => 42,
    SPELL_AURA_REFRESH => 43,
    SPELL_AURA_BROKEN_SPELL => 44,
    SPELL_DISPEL => 45,
    SPELL_STOLEN => 46,
    SPELL_AURA_BROKEN => 47,
    SPELL_RESURRECT => 48,
    SPELL_BUILDING_DAMAGE => 49,
);

=head3 new

Takes three parameters.

=over 4

=item logger

The name of the logger. This value defaults to "You". The name of 
the logger is not required for version 2 logs (since they contain
the logger's real name).

=item version

"1" or "2" for pre-2.4 and post-2.4 logs respectively. The version
defaults to 2.

=item year

This optional argument can be used to specify a different year. The
year defaults to the current year.

=back

=head3 EXAMPLE

    $parser = Stasis::Parser->new ( 
            logger => "Gian",
            version => 1,
            year => 2008,
        );

=cut

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{year} ||= strftime "%Y", localtime;
    $params{logger} ||= "You";
    $params{version} = 2 if !$params{version} || $params{version} != 1;
    
    bless {
        year => $params{year} || strftime( "%Y", localtime ),
        logger => $params{logger} || "You",
        version => ( !$params{version} || $params{version} != 1 ? 2 : 1 ),
        compact => $params{compact},
    }, $class;
}

=head3 parse( $line )

Parses a single line.

=cut

{
    my %reverse_action_map;
    @reverse_action_map{ values %action_map } = keys %action_map;
    
    sub parse {
        my $entry;
        
        if( $_[0]->{version} == 1 ) {
            # v1, compact
            $entry = parse1(@_);
        } else {
            # v2, compact
            $entry = parse2(@_);
        }
        
        if( !$_[0]->{compact} ) {
            # modify it for heathens
            $entry->{action} = $entry->{action} ? $reverse_action_map{ $entry->{action} } : "";
            $entry->{$_} = delete $entry->{$_} foreach( grep { $_ ne "action" && $_ ne "actor" && $_ ne "actor_name" && $_ ne "actor_relationship" && $_ ne "target" && $_ ne "target_name" && $_ ne "target_relationship" && $_ ne "t" } keys %$entry );
        }
        
        return $entry;
    }
    
    sub action_name {
        my ($self, $id) = @_;
        return $reverse_action_map{$id};
    }
}

# Returns compact hashes for v1 logs.
sub parse1 {
    my ($self, $line) = @_;
    
    # Pull the stamp out.
    my $t;
    ($t, $line) = $self->_pullStamp( $line );
    if( !$t ) {
        return {
            action => 0,
            actor => 0,
            actor_name => "",
            actor_relationship => 0,
            target => 0,
            target_name => "",
            target_relationship => 0,
        };
    }
    
    my %result;
    
    #############################
    # VERSION 1 LOGIC (PRE-2.4) #
    #############################
    
    if( $line =~ /^(.+) fades from (.+)\.$/ ) {
        # AURA FADE
        %result = $self->_legacyAction(
            "SPELL_AURA_REMOVED",
            undef,
            $2,
            {
                spellid => $1,
                spellname => $1,
                spellschool => undef,
                auratype => undef,
            }
        );
	} elsif( $line =~ /^(.+) (?:gain|gains) ([0-9]+) (Happiness|Rage|Mana|Energy|Focus) from (?:(you)r|(.+?)\s*'s) (.+)\.$/ ) {
	    # POWER GAIN WITH SOURCE
	    %result = $self->_legacyAction(
            "SPELL_ENERGIZE",
            $4 ? $4 : $5,
            $1,
            {
                spellid => $6,
                spellname => $6,
                spellschool => undef,
                amount => $2,
                powertype => lc $3,
            }
        );
    } elsif( $line =~ /^(.+) (?:gain|gains) ([0-9]+) (Happiness|Rage|Mana|Energy|Focus) from (.+)\.$/ ) {
	    # POWER GAIN WITHOUT SOURCE
	    %result = $self->_legacyAction(
            "SPELL_ENERGIZE",
            $1,
            $1,
            {
                spellid => $4,
                spellname => $4,
                spellschool => undef,
                amount => $2,
                powertype => lc $3,
            }
        );
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+?) drains ([0-9]+) Mana from ([^\.]+)\. .+ (?:gain|gains) [0-9]+ Mana\.$/ ) {
        # MANA LEECH
        %result = $self->_legacyAction(
            "SPELL_LEECH",
            $1 ? $1 : $2,
            $5,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $4,
                powertype => "mana",
                extraamount => 0,
            }
        );
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+?) drains ([0-9]+) Mana from ([^\.]+)\.$/ ) {
        # MANA DRAIN
        %result = $self->_legacyAction(
            "SPELL_DRAIN",
            $1 ? $1 : $2,
            $5,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $4,
                powertype => "mana",
                extraamount => 0,
            }
        );
    } elsif( $line =~ /^(.+) (?:gain|gains) ([0-9]+) health from (?:(you)r|(.+?)\s*'s) (.+)\.$/ ) {
        # HOT HEAL WITH SOURCE
        %result = $self->_legacyAction(
            "SPELL_PERIODIC_HEAL",
            $3 ? $3 : $4,
            $1,
            {
                spellid => $5,
                spellname => $5,
                spellschool => undef,
                amount => $2,
                critical => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:gain|gains) ([0-9]+) health from (.+)\.$/ ) {
        # HOT HEAL WITHOUT SOURCE
        %result = $self->_legacyAction(
            "SPELL_PERIODIC_HEAL",
            $1,
            $1,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $2,
                critical => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:gain|gains) ([0-9]+) extra (?:attack|attacks) through (.+)\.$/ ) {
        # EXTRA ATTACKS
        %result = $self->_legacyAction(
            "SPELL_EXTRA_ATTACKS",
            $1,
            $1,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $2,
            }
        );
    } elsif( $line =~ /^(.+) (?:gain|gains) (.+)\.$/ ) {
        # BUFF GAIN
        %result = $self->_legacyAction(
            "SPELL_AURA_APPLIED",
            undef,
            $1,
            {
                spellid => $2,
                spellname => $2,
                spellschool => undef,
                auratype => "BUFF",
            }
        );
        
        # Remove doses from the name
        $result{spellid} =~ s/ \([0-9]+\)$//;
        $result{spellname} = $result{spellid};
    } elsif( $line =~ /^(.+) (?:is|are) afflicted by (.+)\.$/ ) {
        # DEBUFF GAIN
        %result = $self->_legacyAction(
            "SPELL_AURA_APPLIED",
            undef,
            $1,
            {
                spellid => $2,
                spellname => $2,
                spellschool => undef,
                auratype => "DEBUFF",
            }
        );
        
        # Remove doses from the name
        $result{spellid} =~ s/ \([0-9]+\)$//;
        $result{spellname} = $result{spellid};
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) causes (.+) ([0-9]+) damage\.\w*(.*?)$/ ) {
        # CAUSED DAMAGE (e.g. SOUL LINK)
        
        %result = $self->_legacyAction(
            "DAMAGE_SPLIT",
            $1 ? $1 : $2,
            $4,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $5,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
        
        # Assign mods
        my $mods = $self->_parseMods($6);
        $result{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{crushing} = $mods->{crush} if $mods->{crush};
        $result{glancing} = $mods->{glance} if $mods->{glance};
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) (crits|crit|hit|hits) (.+) for ([0-9]+)( [a-zA-Z]+ damage|)\.\w*(.*?)$/ ) {
        # DIRECT YELLOW HIT (SPELL OR MELEE)
        %result = $self->_legacyAction(
            "SPELL_DAMAGE",
            $1 ? $1 : $2,
            $5,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $6,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
        
        # Check if it was a critical
        if( $4 eq "crits" || $4 eq "crit" ) {
            $result{critical} = 1;
        }
        
        # Assign mods
        my $mods = $self->_parseMods($8);
        $result{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{crushing} = $mods->{crush} if $mods->{crush};
        $result{glancing} = $mods->{glance} if $mods->{glance};
    } elsif( $line =~ /^(.+) (crits|crit|hit|hits) (.+) for ([0-9]+)( [a-zA-Z]+ damage|)\.\w*(.*?)$/ ) {
        # DIRECT WHITE HIT (MELEE)
        %result = $self->_legacyAction(
            "SWING_DAMAGE",
            $1,
            $3,
            {
                amount => $4,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
        
        # Check if it was a critical
        if( $2 eq "crits" || $2 eq "crit" ) {
            $result{critical} = 1;
        }
        
        # Assign mods
        my $mods = $self->_parseMods($6);
        $result{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{crushing} = $mods->{crush} if $mods->{crush};
        $result{glancing} = $mods->{glance} if $mods->{glance};
    } elsif( $line =~ /^(.+) (?:attack|attacks)\. (.+) (?:block|blocks)\.$/ ) {
        # WHITE FULL BLOCK
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "BLOCK",
            }
        );
    } elsif( $line =~ /^(.+) (?:attack|attacks)\. (.+) (?:parry|parries)\.$/ ) {
        # WHITE PARRY
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "PARRY",
            }
        );
    } elsif( $line =~ /^(.+) (?:attack|attacks)\. (.+) (?:dodge|dodges)\.$/ ) {
        # WHITE DODGE
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "DODGE",
            }
        );
    } elsif( $line =~ /^(.+) (?:attack|attacks)\. (.+) (?:absorb|absorbs) all the damage\.$/ ) {
        # WHITE FULL ABSORB
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "ABSORB",
            }
        );
    } elsif( $line =~ /^(.+) (?:miss|misses) (.+)\.$/ ) {
        # WHITE MISS
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "MISS",
            }
        );
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) (?:is parried|was parried)( by .+|)\.$/ ) {
        # YELLOW PARRY
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            undef,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "PARRY",
            }
        );
        
        # Figure out target.
        my $target = $4;
        if( $target && $target =~ /^ by (.+)$/ ) {
            $target = $1;
        } else {
            $target = "you";
        }
        
        $result{target} = $result{target_name} = $target;
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) was dodged( by .+|)\.$/ ) {
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            undef,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "DODGE",
            }
        );
        
        # Figure out target.
        my $target = $4;
        if( $target && $target =~ /^ by (.+)$/ ) {
            $target = $1;
        } else {
            $target = "you";
        }
        
        $result{target} = $result{target_name} = $target;
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) was resisted( by .+|)\.$/ ) {
        # YELLOW RESIST
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            undef,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "RESIST",
            }
        );
        
        # Figure out target.
        my $target = $4;
        if( $target && $target =~ /^ by (.+)$/ ) {
            $target = $1;
        } else {
            $target = "you";
        }
        
        $result{target} = $result{target_name} = $target;
    } elsif( $line =~ /^(.+) resists (?:(You)r|(.+?)\s*'s) (.+)\.$/ ) {
        # YELLOW RESIST, ALTERNATE FORMAT
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $2 ? $2 : $3,
            $1,
            {
                spellid => $4,
                spellname => $4,
                spellschool => undef,
                misstype => "RESIST",
            }
        );
    } elsif( $line =~ /^(.+) was resisted by (.+)\.$/ ) {
        # WHITE RESIST
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "RESIST",
            }
        );

        # Figure out target.
        my $target = $4;
        if( $target && $target =~ /^ by (.+)$/ ) {
            $target = $1;
        } else {
            $target = "you";
        }

        $result{target} = $result{target_name} = $target;
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) (?:missed|misses) (.+)\.$/ ) {
        # YELLOW MISS
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            $4,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "MISS",
            }
        );
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) was blocked( by .+|)\.$/ ) {
        # YELLOW FULL BLOCK
        # (Is this what a self block looks like?)
        
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            undef,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "BLOCK",
            }
        );
        
        # Figure out target.
        my $target = $4;
        if( $target && $target =~ /^ by (.+)$/ ) {
            $target = $1;
        } else {
            $target = "you";
        }
        
        $result{target} = $result{target_name} = $target;
    } elsif( $line =~ /^You absorb (?:(you)r|(.+?)\s*'s) (.+)\.$/ ) {
        # YELLOW FULL ABSORB, SELF
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            "you",
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "ABSORB",
            }
        );
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+) is absorbed by (.+)\.$/ ) {
        # YELLOW FULL ABSORB, OTHER
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            $4,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "ABSORB",
            }
        );
    } elsif( $line =~ /^(.+) (?:suffer|suffers) ([0-9]+) (\w+) damage from (?:(you)r|(.+?)\s*'s) (.+)\.\w*(.*?)$/ ) {
        # YELLOW DOT WITH SOURCE
        %result = $self->_legacyAction(
            "SPELL_PERIODIC_DAMAGE",
            $4 ? $4 : $5,
            $1,
            {
                spellid => $6,
                spellname => $6,
                spellschool => undef,
                amount => $2,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
        
        # Assign mods
        my $mods = $self->_parseMods($7);
        $result{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{crushing} = $mods->{crush} if $mods->{crush};
        $result{glancing} = $mods->{glance} if $mods->{glance};
    } elsif( $line =~ /^(.+) (?:suffer|suffers) ([0-9]+) (\w+) damage from (.+)\.\w*(.*?)$/ ) {
        # YELLOW DOT WITHOUT SOURCE
        %result = $self->_legacyAction(
            "SPELL_PERIODIC_DAMAGE",
            $1,
            $1,
            {
                spellid => $4,
                spellname => $4,
                spellschool => undef,
                amount => $2,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
        
        # Assign mods
        my $mods = $self->_parseMods($5);
        $result{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{crushing} = $mods->{crush} if $mods->{crush};
        $result{glancing} = $mods->{glance} if $mods->{glance};
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+?) (critically heals|heals) (.+) for ([0-9]+)\.$/ ) {
        # HEAL
        %result = $self->_legacyAction(
            "SPELL_HEAL",
            $1 ? $1 : $2,
            $5,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                amount => $6,
                critical => $4 eq "critically heals" ? 1 : undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:begins|begin) to (?:cast|perform) (.+)\.$/ ) {
        # CAST START
        %result = $self->_legacyAction(
            "SPELL_CAST_START",
            $1,
            undef,
            {
                spellid => $2,
                spellname => $2,
                spellschool => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:fail|fails) to (?:cast|perform) (.+): (.+)\.$/ ) {
        # CAST FAILURE
        %result = $self->_legacyAction(
            "SPELL_CAST_FAILED",
            $1,
            undef,
            {
                spellid => $2,
                spellname => $2,
                spellschool => undef,
                misstype => $3,
            }
        );
    } elsif( $line =~ /^(.+) (?:cast|casts|perform|performs) (.+)\.$/ ) {
        # CAST SUCCESS
        my $actor = $1;
        my $target;
        my $spell;
        
        # Split the performance into target and spell, maybe.
        my $performance = $2;
        if( $performance =~ /^(.+) on (.+)$/ ) {
            $target = $2;
            $spell = $1;
        } else {
            $spell = $performance;
        }
        
        # Create the action.
        %result = $self->_legacyAction(
            "SPELL_CAST_SUCCESS",
            $actor,
            $target,
            {
                spellid => $spell,
                spellname => $spell,
                spellschool => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:dies|die|is destroyed)\.$/ ) {
        # DEATH
        %result = $self->_legacyAction(
            "UNIT_DIED",
            undef,
            $1,
            {
                
            }
        );
    } elsif( $line =~ /^(.+) (?:is|are) killed by (.+)\.$/ ) {
        # KILL (e.g. DEMONIC SACRIFICE)
        %result = $self->_legacyAction(
            "SPELL_INSTAKILL",
            undef,
            $1,
            {
                spellid => $2,
                spellname => $2,
                spellschool => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:fall|falls) and (?:lose|loses) ([0-9]+) health\.$/ ) {
        # FALL DAMAGE
        %result = $self->_legacyAction(
            "ENVIRONMENTAL_DAMAGE",
            undef,
            $1,
            {
                environmentaltype => "FALLING",
                amount => $2,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:interrupt|interrupts) (.+?)\s*'s (.+)\.$/ ) {
        # INTERRUPT
        %result = $self->_legacyAction(
            "SPELL_INTERRUPT",
            $1,
            $2,
            {
                spellid => undef,
                spellname => undef,
                spellschool => undef,
                extraspellid => $3,
                extraspellname => $3,
                extraspellschool => undef,
            }
        );
    } elsif( $line =~ /^(.+) (?:reflect|reflects) ([0-9]+) (\w+) damage to (.+)\.\w*(.*?)$/ ) {
        # MELEE REFLECT (e.g. THORNS)
        %result = $self->_legacyAction(
            "DAMAGE_SHIELD",
            $1,
            $4,
            {
                spellid => "Reflect",
                spellname => "Reflect",
                spellschool => undef,
                amount => $2,
                school => undef,
                resisted => undef,
                blocked => undef,
                absorbed => undef,
                critical => undef,
                glancing => undef,
                crushing => undef,
            }
        );
        
        my $mods = $self->_parseMods($5);
        $result{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{crushing} = $mods->{crush} if $mods->{crush};
        $result{glancing} = $mods->{glance} if $mods->{glance};
    } elsif( $line =~ /^(?:(You)r|(.+?)\s*'s) (.+?) (?:fails|failed)\.\s+(.+) (?:are|is) immune\.$/ ) {
        # YELLOW IMMUNITY
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $1 ? $1 : $2,
            $4,
            {
                spellid => $3,
                spellname => $3,
                spellschool => undef,
                misstype => "IMMUNE",
            }
        );
    } elsif( $line =~ /^(.+) (?:is|are) immune to (?:(you)r|(.+?)\s*'s) (.+)\.$/ ) {
        # YELLOW IMMUNITY, ALTERNATE FORMAT
        %result = $self->_legacyAction(
            "SPELL_MISSED",
            $2 ? $2 : $3,
            $1,
            {
                spellid => $4,
                spellname => $4,
                spellschool => undef,
                misstype => "IMMUNE",
            }
        );
    } elsif( $line =~ /^(.+) (?:attacks|attack) but (.+) (?:are|is) immune\.$/ ) {
        # WHITE IMMUNITY
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "IMMUNE",
            }
        );
    } elsif( $line =~ /^(.+) (?:fails|failed)\. (.+) (?:are|is) immune\.$/ ) {
        # SINGLE-WORD IMMUNITY (e.g. DOOMFIRE)
        %result = $self->_legacyAction(
            "SWING_MISSED",
            $1,
            $2,
            {
                misstype => "IMMUNE",
            }
        );
    } else {
        # Unrecognized action
        %result = $self->_legacyAction(
            "",
            "",
            "",
            {}
        );
    }
    
    # Replace action with a number
    $result{action} = $action_map{$result{action}} || 0;
    
    # Replace "You" with name of the logger
    $result{actor} = $self->{logger} if $result{actor} && lc $result{actor} eq "you";
    $result{target} = $self->{logger} if $result{target} && lc $result{target} eq "you";
    
    $result{actor_name} = $self->{logger} if $result{actor_name} && lc $result{actor_name} eq "you";
    $result{target_name} = $self->{logger} if $result{target_name} && lc $result{target_name} eq "you";
    
    # Write in the time
    $result{t} = $t;
    
    # Replace undefined actor or target with blank
    if( !$result{actor_name} ) {
        $result{actor} = 0;
        $result{actor_relationship} = 0;
        $result{actor_name} = "";
    }
    
    if( !$result{target_name} ) {
        $result{target} = 0;
        $result{target_relationship} = 0;
        $result{target_name} = "";
    }
    
    # Replace other undefs with zeros
    foreach my $rkey ( keys %result ) {
        if( !defined($result{$rkey}) ) {
            $result{$rkey} = 0;
        }
    }
    
    return \%result;
}

my @fspell      = qw(spellid spellname spellschool);
my @fextraspell = qw(extraspellid extraspellname extraspellschool);
my @fdamage     = qw(amount school resisted blocked absorbed critical glancing crushing);
my @fdamage_wlk = qw(amount extraamount school resisted blocked absorbed critical glancing crushing);
my @fmiss       = qw(misstype amount);
my @fspellname  = qw(spellname);
my @fheal       = qw(amount critical);
my @fheal_wlk   = qw(amount extraamount critical);
my @fenergize   = qw(amount powertype extraamount);
my @faura       = qw(auratype amount);
my @fenv        = qw(environmentaltype);

# Returns compact hashes for v2 logs.
sub parse2 {
    my ($self, $line) = @_;
    
    # Pull the stamp out.
    my ($t, @col) = $self->_split( $line );
    if( !$t || @col < 7 ) {
        return {
            action => 0,
            actor => 0,
            actor_name => "",
            actor_relationship => 0,
            target => 0,
            target_name => "",
            target_relationship => 0,
        };
    }
    
    # Common processing
    my $action = $action_map{ shift @col };
    my $result = {
        action              => $action,
        actor               => shift @col,
        actor_name          => shift @col || "",
        actor_relationship  => hex shift @col,
        target              => shift @col,
        target_name         => shift @col || "",
        target_relationship => hex shift @col,
        t                   => $t,
    };
    
    $result->{target} = 0 unless $result->{target_name};
    $result->{actor} = 0 unless $result->{actor_name};
    
    # Action specific processing
    if( $action == SWING_DAMAGE ) {
        if( @col <= 8 ) {
            @{$result}{@fdamage} = @col;
        } else {
            @{$result}{@fdamage_wlk} = @col;
        }
    } elsif( $action == SWING_MISSED ) {
        @{$result}{@fmiss} = @col;
    } elsif( 
        $action == RANGE_DAMAGE || 
        $action == SPELL_DAMAGE || 
        $action == SPELL_PERIODIC_DAMAGE || 
        $action == SPELL_BUILDING_DAMAGE ||
        $action == DAMAGE_SHIELD || 
        $action == DAMAGE_SPLIT
    ) {
        if( @col <= 11 ) {
            @{$result}{ (@fspell, @fdamage) } = @col;
        } else {
            @{$result}{ (@fspell, @fdamage_wlk) } = @col;
        }
    } elsif( 
        $action == RANGE_MISSED || 
        $action == SPELL_MISSED || 
        $action == SPELL_PERIODIC_MISSED || 
        $action == SPELL_CAST_FAILED || 
        $action == DAMAGE_SHIELD_MISSED
    ) {
        @{$result}{ (@fspell, @fmiss) } = @col;
    } elsif( $action == SPELL_HEAL || $action == SPELL_PERIODIC_HEAL ) {
        if( @col <= 5 ) {
            @{$result}{ (@fspell, @fheal) } = @col;
        } else {
            @{$result}{ (@fspell, @fheal_wlk) } = @col;
        }
    } elsif(
        $action == SPELL_PERIODIC_DRAIN ||
        $action == SPELL_PERIODIC_LEECH ||
        $action == SPELL_PERIODIC_ENERGIZE ||
        $action == SPELL_DRAIN ||
        $action == SPELL_LEECH ||
        $action == SPELL_ENERGIZE ||
        $action == SPELL_EXTRA_ATTACKS
    ) {
        @{$result}{ (@fspell, @fenergize) } = @col;
    } elsif(
        $action == SPELL_DISPEL_FAILED ||
        $action == SPELL_AURA_DISPELLED ||
        $action == SPELL_AURA_STOLEN ||
        $action == SPELL_INTERRUPT ||
        $action == SPELL_AURA_BROKEN_SPELL ||
        $action == SPELL_DISPEL ||
        $action == SPELL_STOLEN
    ) {
        @{$result}{ (@fspell, @fextraspell) } = @col;
    } elsif(
        $action == SPELL_AURA_APPLIED ||
        $action == SPELL_AURA_REMOVED ||
        $action == SPELL_AURA_APPLIED_DOSE ||
        $action == SPELL_AURA_REMOVED_DOSE ||
        $action == SPELL_AURA_REFRESH
    ) {
        @{$result}{ (@fspell, @faura) } = @col;
    } elsif(
        $action == ENCHANT_APPLIED ||
        $action == ENCHANT_REMOVED
    ) {
        @{$result}{@fspellname} = @col;
    } elsif( $action == ENVIRONMENTAL_DAMAGE ) {
        if( @col <= 9 ) {
            @{$result}{ (@fenv, @fdamage) } = @col;
        } else {
            @{$result}{ (@fenv, @fdamage_wlk) } = @col;
        }
    } elsif( $action ) {
        @{$result}{@fspell} = @col;
    }
    
    return $result;
}

sub _parseMods {
    my ($self, $mods) = @_;
    
    my %result = ();
    
    # figure out mods
    if( $mods ) {
        while( $mods =~ /\(([^\)]+)\)/g ) {
            my $mod = $1;
            if( $mod =~ /^([0-9]+) (.+)$/ ) {
                # numeric mod
                if( $2 eq "blocked" ) {
                    $result{blockValue} = $1;
                } elsif( $2 eq "absorbed" ) {
                    $result{absorbValue} = $1;
                } elsif( $2 eq "resisted" ) {
                    $result{resistValue} = $1;
                }
            } else {
                # text mod
                if( $mod eq "crushing" ) {
                    $result{crush} = 1;
                } elsif( $mod eq "glancing" ) {
                    $result{glance} = 1;
                }
            }
        }
    }
    
    return \%result;
}

sub _powerName {
    my ($self, $code) = @_;
    
    if( !defined $code ) {
        return "power";
    } elsif( $code == 0 ) {
        return "mana";
    } elsif( $code == 1 ) {
        return "rage";
    } elsif( $code == 2 ) {
        return "focus";
    } elsif( $code == 3 ) {
        return "energy";
    } elsif( $code == 4 ) {
        return "happiness";
    } elsif( $code == 5 ) {
        return "runes";
    } elsif( $code == -2 ) {
        return "health";
    } else {
        return "$code (?)";
    }
}

sub _legacyAction {
    my ($self, $action, $actor, $target, $extra) = @_;
    
    return (
        action => $action,
        actor => $actor,
        actor_name => $actor,
        actor_relationship => 0,
        target => $target,
        target_name => $target,
        target_relationship => 0,
        %$extra
    );
}

sub toString {
    my ($self, $entry, $actor_callback, $spell_callback) = @_;
    
    my $actor = $actor_callback ? $actor_callback->( $entry->{actor} ) : ($entry->{actor_name} || "Environment");
    my $target = $actor_callback ? $actor_callback->( $entry->{target} ) : ($entry->{target_name} || "Environment");
    my $spell = $spell_callback ? $spell_callback->( $entry->{spellid} ) : ($entry->{spellname});
    my $extraspell = $spell_callback ? $spell_callback->( $entry->{extraspellid} ) : ($entry->{extraspellname});
    my $text = "";
    
    if( $entry->{action} == SWING_DAMAGE ) {
        $text = sprintf "[%s] %s [%s] %d",
            $actor,
            $entry->{critical} ? "crit" : "hit",
            $target,
            $entry->{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{resisted} if $entry->{resisted};
        $text .= sprintf " (%d blocked)", $entry->{blocked} if $entry->{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{absorbed} if $entry->{absorbed};
        $text .= " (crushing)" if $entry->{crushing};
        $text .= " (glancing)" if $entry->{glancing};
        
        # WLK log overdamage
        if( $entry->{extraamount} ) {
            $text .= sprintf " {%s}", $entry->{extraamount};
        }
    } elsif( $entry->{action} == SWING_MISSED ) {
        $text = sprintf "[%s] melee [%s] %s",
            $actor,
            $target,
            lc( $entry->{misstype} );
    } elsif( $entry->{action} == RANGE_DAMAGE ) {
        $text = sprintf "[%s] %s %s [%s] %d",
            $actor,
            $spell,
            $entry->{critical} ? "crit" : "hit",
            $target,
            $entry->{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{resisted} if $entry->{resisted};
        $text .= sprintf " (%d blocked)", $entry->{blocked} if $entry->{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{absorbed} if $entry->{absorbed};
        $text .= " (crushing)" if $entry->{crushing};
        $text .= " (glancing)" if $entry->{glancing};
        
        # WLK log overdamage
        if( $entry->{extraamount} ) {
            $text .= sprintf " {%s}", $entry->{extraamount};
        }
    } elsif( $entry->{action} == RANGE_MISSED ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $spell,
            $target,
            lc( $entry->{misstype} );
    } elsif( $entry->{action} == SPELL_DAMAGE ) {
        $text = sprintf "[%s] %s %s [%s] %d",
            $actor,
            $spell,
            $entry->{critical} ? "crit" : "hit",
            $target,
            $entry->{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{resisted} if $entry->{resisted};
        $text .= sprintf " (%d blocked)", $entry->{blocked} if $entry->{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{absorbed} if $entry->{absorbed};
        $text .= " (crushing)" if $entry->{crushing};
        $text .= " (glancing)" if $entry->{glancing};
        
        # WLK log overdamage
        if( $entry->{extraamount} ) {
            $text .= sprintf " {%s}", $entry->{extraamount};
        }
    } elsif( $entry->{action} == SPELL_MISSED ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $spell,
            $target,
            lc( $entry->{misstype} );
    } elsif( $entry->{action} == SPELL_HEAL ) {
        $text = sprintf "[%s] %s %s [%s] %d",
            $actor,
            $spell,
            $entry->{critical} ? "crit heal" : "heal",
            $target,
            $entry->{amount};
        
        # WLK log overhealing
        if( $entry->{extraamount} ) {
            $text .= sprintf " {%s}", $entry->{extraamount};
        }
    } elsif( $entry->{action} == SPELL_ENERGIZE ) {
        $text = sprintf "[%s] %s energize [%s] %d %s",
            $actor,
            $spell,
            $target,
            $entry->{amount},
            $self->_powerName( $entry->{powertype} );
    } elsif( $entry->{action} == SPELL_PERIODIC_MISSED ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $spell,
            $target,
            lc( $entry->{misstype} );
    } elsif( $entry->{action} == SPELL_PERIODIC_DAMAGE ) {
        $text = sprintf "[%s] %s dot [%s] %d",
            $actor,
            $spell,
            $target,
            lc( $entry->{amount} );
        
        $text .= sprintf " (%d resisted)", $entry->{resisted} if $entry->{resisted};
        $text .= sprintf " (%d blocked)", $entry->{blocked} if $entry->{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{absorbed} if $entry->{absorbed};
        $text .= " (crushing)" if $entry->{crushing};
        $text .= " (glancing)" if $entry->{glancing};
        
        # WLK log overdamage
        if( $entry->{extraamount} ) {
            $text .= sprintf " {%s}", $entry->{extraamount};
        }
    } elsif( $entry->{action} == SPELL_PERIODIC_HEAL ) {
        $text = sprintf "[%s] %s hot [%s] %d",
            $actor,
            $spell,
            $target,
            $entry->{amount};
        
        # WLK log overhealing
        if( $entry->{extraamount} ) {
            $text .= sprintf " {%s}", $entry->{extraamount};
        }
    } elsif( $entry->{action} == SPELL_PERIODIC_DRAIN ) {
        $text = sprintf "[%s] %s drain [%s] %d %s",
            $actor,
            $spell,
            $target,
            $entry->{amount},
            $self->_powerName( $entry->{powertype} );
    } elsif( $entry->{action} == SPELL_PERIODIC_LEECH ) {
        $text = sprintf "[%s] %s leech [%s] %d %s",
            $actor,
            $spell,
            $target,
            $entry->{amount},
            $self->_powerName( $entry->{powertype} );
    } elsif( $entry->{action} == SPELL_PERIODIC_ENERGIZE ) {
        $text = sprintf "[%s] %s energize [%s] %d %s",
            $actor,
            $spell,
            $target,
            $entry->{amount},
            $self->_powerName( $entry->{powertype} );
    } elsif( $entry->{action} == SPELL_DRAIN ) {
        $text = sprintf "[%s] %s drain [%s] %d %s",
            $actor,
            $spell,
            $target,
            $entry->{amount},
            $self->_powerName( $entry->{powertype} );
    } elsif( $entry->{action} == SPELL_LEECH ) {
        $text = sprintf "[%s] %s leech [%s] %d %s",
            $actor,
            $spell,
            $target,
            $entry->{amount},
            $self->_powerName( $entry->{powertype} );
    } elsif( $entry->{action} == SPELL_INTERRUPT ) {
        $text = sprintf "[%s] %sinterrupt [%s] %s",
            $actor,
            $spell ? $spell . " " : "",
            $target,
            $extraspell,
    } elsif( $entry->{action} == SPELL_EXTRA_ATTACKS ) {
        $text = sprintf "[%s] %s +%d attack%s",
            $actor,
            $spell,
            $entry->{amount},
            $entry->{amount} > 1 ? "s" : "",
    } elsif( $entry->{action} == SPELL_INSTAKILL ) {
        $text = sprintf "[%s] instakill [%s]",
            $actor,
            $target,
    } elsif( $entry->{action} == SPELL_DURABILITY_DAMAGE ) {

    } elsif( $entry->{action} == SPELL_DURABILITY_DAMAGE_ALL ) {

    } elsif( $entry->{action} == SPELL_DISPEL_FAILED ) {

    } elsif( $entry->{action} == SPELL_AURA_DISPELLED ) {

    } elsif( $entry->{action} == SPELL_AURA_STOLEN ) {
        
    } elsif( $entry->{action} == SPELL_AURA_APPLIED ) {
        $text = sprintf "[%s] %s %s",
            $target,
            $entry->{auratype} eq "DEBUFF" ? "afflicted by" : "gain",
            $spell;
    } elsif( $entry->{action} == SPELL_AURA_REMOVED ) {
        $text = sprintf "[%s] fade %s",
            $target,
            $spell;
    } elsif( $entry->{action} == SPELL_AURA_APPLIED_DOSE ) {
        $text = sprintf "[%s] %s %s (%d)",
            $target,
            $entry->{auratype} eq "DEBUFF" ? "afflicted by" : "gain",
            $spell,
            $entry->{amount};
    } elsif( $entry->{action} == SPELL_AURA_REMOVED_DOSE ) {
        $text = sprintf "[%s] decrease dose %s (%d)",
            $target,
            $spell,
            $entry->{amount};
    } elsif( $entry->{action} == SPELL_CAST_START ) {

    } elsif( $entry->{action} == SPELL_CAST_SUCCESS ) {
        $text = sprintf "[%s] cast %s [%s]",
            $actor,
            $spell,
            $target;
    } elsif( $entry->{action} == SPELL_CAST_FAILED ) {

    } elsif( $entry->{action} == DAMAGE_SHIELD ) {
        $text = sprintf "[%s] %s reflect %s[%s] %d",
            $actor,
            $spell,
            $entry->{critical} ? "crit " : "",
            $target,
            $entry->{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{resisted} if $entry->{resisted};
        $text .= sprintf " (%d blocked)", $entry->{blocked} if $entry->{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{absorbed} if $entry->{absorbed};
        $text .= " (crushing)" if $entry->{crushing};
        $text .= " (glancing)" if $entry->{glancing};
    } elsif( $entry->{action} == DAMAGE_SHIELD_MISSED ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $spell,
            $target,
            lc( $entry->{misstype} );
    } elsif( $entry->{action} == ENCHANT_APPLIED ) {

    } elsif( $entry->{action} == ENCHANT_REMOVED ) {

    } elsif( $entry->{action} == ENVIRONMENTAL_DAMAGE ) {

    } elsif( $entry->{action} == DAMAGE_SPLIT ) {
        $text = sprintf "[%s] %s %s [%s] %d (split)",
            $actor,
            $spell,
            $entry->{critical} ? "crit" : "hit",
            $target,
            $entry->{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{resisted} if $entry->{resisted};
        $text .= sprintf " (%d blocked)", $entry->{blocked} if $entry->{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{absorbed} if $entry->{absorbed};
        $text .= " (crushing)" if $entry->{crushing};
        $text .= " (glancing)" if $entry->{glancing};
    } elsif( $entry->{action} == UNIT_DIED ) {
        $text = sprintf "[%s] dies",
            $target;
    } elsif( $entry->{action} == SPELL_RESURRECT ) {
        $text = sprintf "[%s] %s resurrect [%s]",
            $actor,
            $spell,
            $target;
    }
    
    return $text;
}

my $stamp_regex = qr/^(\d+)\/(\d+) (\d+):(\d+):(\d+)\.(\d+)  (.*?)[\r\n]*$/s;
sub _pullStamp {
    my ($self, $line) = @_;
    
    if( $line =~ $stamp_regex ) {
        return 
            POSIX::mktime( 
                $5, # sec
                $4, # min
                $3, # hour
                $2, # mday
                $1 - 1, # mon
                $self->{year} - 1900, # year
                0, # wday
                0, # yday
                -1 # is_dst
            ) + $6/1000,
            $7;
    } else {
        # Couldn't recognize time
        return (0, $line);
    }
}

my $csv_regex = qr{"?,(?=".*?"(?:,|$)|[^",]+(?:,|$))"?};
sub _split {
    my ($self, $line) = @_;

    if( $line =~ $stamp_regex ) {
        return 
            POSIX::mktime( 
                $5, # sec
                $4, # min
                $3, # hour
                $2, # mday
                $1 - 1, # mon
                $self->{year} - 1900, # year
                0, # wday
                0, # yday
                -1 # is_dst
            ) + $6/1000,
            map { $_ eq "nil" ? 0 : $_ } split $csv_regex, $7;
    } else {
        # Couldn't recognize time
        return 0, map { $_ eq "nil" ? 0 : $_ } split $csv_regex, $line;
    }
}

1;
