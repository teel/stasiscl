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
    COMBATLOG_OBJECT_AFFILIATION_MINE => 0x00000001,
    COMBATLOG_OBJECT_AFFILIATION_PARTY => 0x00000002,
    COMBATLOG_OBJECT_AFFILIATION_RAID => 0x00000004,
    COMBATLOG_OBJECT_AFFILIATION_OUTSIDER => 0x00000008,
    COMBATLOG_OBJECT_AFFILIATION_MASK => 0x0000000F,

    COMBATLOG_OBJECT_REACTION_FRIENDLY => 0x00000010,
    COMBATLOG_OBJECT_REACTION_NEUTRAL => 0x00000020,
    COMBATLOG_OBJECT_REACTION_HOSTILE => 0x00000040,
    COMBATLOG_OBJECT_REACTION_MASK => 0x000000F0,

    COMBATLOG_OBJECT_CONTROL_PLAYER => 0x00000100,
    COMBATLOG_OBJECT_CONTROL_NPC => 0x00000200,
    COMBATLOG_OBJECT_CONTROL_MASK => 0x00000300,

    COMBATLOG_OBJECT_TYPE_PLAYER => 0x00000400,
    COMBATLOG_OBJECT_TYPE_NPC => 0x00000800,
    COMBATLOG_OBJECT_TYPE_PET => 0x00001000,
    COMBATLOG_OBJECT_TYPE_GUARDIAN => 0x00002000,
    COMBATLOG_OBJECT_TYPE_OBJECT => 0x00004000,
    COMBATLOG_OBJECT_TYPE_MASK => 0x0000FC00,

    COMBATLOG_OBJECT_TARGET => 0x00010000,
    COMBATLOG_OBJECT_FOCUS => 0x00020000,
    COMBATLOG_OBJECT_MAINTANK => 0x00040000,
    COMBATLOG_OBJECT_MAINASSIST => 0x00080000,
    COMBATLOG_OBJECT_RAIDTARGET1 => 0x00100000,
    COMBATLOG_OBJECT_RAIDTARGET2 => 0x00200000,
    COMBATLOG_OBJECT_RAIDTARGET3 => 0x00400000,
    COMBATLOG_OBJECT_RAIDTARGET4 => 0x00800000,
    COMBATLOG_OBJECT_RAIDTARGET5 => 0x01000000,
    COMBATLOG_OBJECT_RAIDTARGET6 => 0x02000000,
    COMBATLOG_OBJECT_RAIDTARGET7 => 0x04000000,
    COMBATLOG_OBJECT_RAIDTARGET8 => 0x08000000,
    COMBATLOG_OBJECT_NONE => 0x80000000,
    COMBATLOG_OBJECT_SPECIAL_MASK => 0xFFFF0000,
};

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
    # $params{csv} = Text::CSV_XS->new({ binary => 1, eol => $/ });
    
    bless \%params, $class;
}

=head3 parse( $line )

Parses a single line.

=cut

sub parse {
    my $self = shift;
    return $self->{version} == 1 ? $self->parse1(@_) : $self->parse2(@_);
}

sub parse1 {
    my ($self, $line) = @_;
    
    # Pull the stamp out.
    my $t;
    ($t, $line) = $self->_pullStamp( $line );
    if( !$t ) {
        carp "bad line: $line";
        
         my %result = (
            action => "",
            actor => 0,
            actor_name => "",
            actor_relationship => 0,
            target => 0,
            target_name => "",
            target_relationship => 0,
            extra => {},
        );
        
        if( $self->{ref} ) {
            return \%result;
        } else {
            return %result;
        }
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
        $result{extra}{spellid} =~ s/ \([0-9]+\)$//;
        $result{extra}{spellname} = $result{extra}{spellid};
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
        $result{extra}{spellid} =~ s/ \([0-9]+\)$//;
        $result{extra}{spellname} = $result{extra}{spellid};
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
        $result{extra}{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{extra}{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{extra}{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{extra}{crushing} = $mods->{crush} if $mods->{crush};
        $result{extra}{glancing} = $mods->{glance} if $mods->{glance};
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
            $result{extra}{critical} = 1;
        }
        
        # Assign mods
        my $mods = $self->_parseMods($8);
        $result{extra}{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{extra}{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{extra}{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{extra}{crushing} = $mods->{crush} if $mods->{crush};
        $result{extra}{glancing} = $mods->{glance} if $mods->{glance};
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
            $result{extra}{critical} = 1;
        }
        
        # Assign mods
        my $mods = $self->_parseMods($6);
        $result{extra}{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{extra}{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{extra}{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{extra}{crushing} = $mods->{crush} if $mods->{crush};
        $result{extra}{glancing} = $mods->{glance} if $mods->{glance};
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
        $result{extra}{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{extra}{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{extra}{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{extra}{crushing} = $mods->{crush} if $mods->{crush};
        $result{extra}{glancing} = $mods->{glance} if $mods->{glance};
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
        $result{extra}{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{extra}{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{extra}{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{extra}{crushing} = $mods->{crush} if $mods->{crush};
        $result{extra}{glancing} = $mods->{glance} if $mods->{glance};
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
        $result{extra}{resisted} = $mods->{resistValue} if $mods->{resistValue};
        $result{extra}{absorbed} = $mods->{absorbValue} if $mods->{absorbValue};
        $result{extra}{blocked} = $mods->{blockValue} if $mods->{blockValue};
        $result{extra}{crushing} = $mods->{crush} if $mods->{crush};
        $result{extra}{glancing} = $mods->{glance} if $mods->{glance};
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
    foreach my $rkey ( keys %{$result{extra}} ) {
        if( !defined($result{extra}{$rkey}) ) {
            $result{extra}{$rkey} = 0;
        }
    }
    
    if( $self->{ref} ) {
        return \%result;
    } else {
        return %result;
    }
}

sub parse2 {
    my ($self, $line) = @_;
    
    # Pull the stamp out.
    my ($t, @col) = $self->_split( $line );
    if( !$t ) {
        carp "bad line: $line";
        
         my %result = (
            action => "",
            actor => 0,
            actor_name => "",
            actor_relationship => 0,
            target => 0,
            target_name => "",
            target_relationship => 0,
        );
        
        if( $self->{ref} ) {
            return \%result;
        } else {
            return %result;
        }
    }
    
    # Common processing
    my $result = {
        action              => shift @col,
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
    if( $result->{action} eq "SWING_DAMAGE" ) {
        $result->{extra} = {
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "SWING_MISSED" ) {
        $result->{extra} = {
            misstype => shift @col || 0,
        }
    } elsif( $result->{action} eq "RANGE_DAMAGE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "RANGE_MISSED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            misstype => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_DAMAGE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_MISSED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            misstype => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_HEAL" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            critical => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_ENERGIZE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            powertype => $self->_powerName( shift @col ),
        }
    } elsif( $result->{action} eq "SPELL_PERIODIC_MISSED" ) {
        $result->{extra} = {                
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            misstype => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_PERIODIC_DAMAGE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_PERIODIC_HEAL" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            critical => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_PERIODIC_DRAIN" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            powertype => $self->_powerName( shift @col ),
            extraamount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_PERIODIC_LEECH" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            powertype => $self->_powerName( shift @col ),
            extraamount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_PERIODIC_ENERGIZE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            powertype => $self->_powerName( shift @col ),
        }
    } elsif( $result->{action} eq "SPELL_DRAIN" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            powertype => $self->_powerName( shift @col ),
            extraamount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_LEECH" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            powertype => $self->_powerName( shift @col ),
            extraamount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_INTERRUPT" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            extraspellid => shift @col || 0,
            extraspellname => shift @col || 0,
            extraspellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_EXTRA_ATTACKS" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_INSTAKILL" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_DURABILITY_DAMAGE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_DURABILITY_DAMAGE_ALL" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_DISPEL_FAILED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            extraspellid => shift @col || 0,
            extraspellname => shift @col || 0,
            extraspellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_AURA_DISPELLED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            extraspellid => shift @col || 0,
            extraspellname => shift @col || 0,
            extraspellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_AURA_STOLEN" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            extraspellid => shift @col || 0,
            extraspellname => shift @col || 0,
            extraspellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_AURA_APPLIED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            auratype => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_AURA_REMOVED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            auratype => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_AURA_APPLIED_DOSE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            auratype => shift @col || 0,
            amount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_AURA_REMOVED_DOSE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            auratype => shift @col || 0,
            amount => shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_CAST_START" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_CAST_SUCCESS" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_CAST_FAILED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            misstype => shift @col || 0,
        }
    } elsif( $result->{action} eq "DAMAGE_SHIELD" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "DAMAGE_SHIELD_MISSED" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            misstype => shift @col || 0,
        }
    } elsif( $result->{action} eq "ENCHANT_APPLIED" ) {
        $result->{extra} = {
            spellname => shift @col || 0,
        }
    } elsif( $result->{action} eq "ENCHANT_REMOVED" ) {
        $result->{extra} = {
            spellname => shift @col || 0,
        }
    } elsif( $result->{action} eq "ENVIRONMENTAL_DAMAGE" ) {
        $result->{extra} = {
            environmentaltype => shift @col || 0,
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "DAMAGE_SPLIT" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
            amount => shift @col || 0,
            school => hex shift @col || 0,
            resisted => shift @col || 0,
            blocked => shift @col || 0,
            absorbed => shift @col || 0,
            critical => shift @col || 0,
            glancing => shift @col || 0,
            crushing => shift @col || 0,
        }
    } elsif( $result->{action} eq "UNIT_DIED" || $result->{action} eq "PARTY_KILL" || $result->{action} eq "UNIT_DESTROYED" ) {
        $result->{extra} = {};
    } elsif( $result->{action} eq "SPELL_SUMMON" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } elsif( $result->{action} eq "SPELL_CREATE" ) {
        $result->{extra} = {
            spellid => shift @col || 0,
            spellname => shift @col || 0,
            spellschool => hex shift @col || 0,
        }
    } else {
        # Unrecognized action
        carp( "Unrecognized action: " . $result->{action} );
        $result->{extra} = {};
    }
    
    return $self->{ref} ? $result : %$result;
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

=head3 _stampTime

This function returns a complete timestamp instead of the shortened Blizzard
version.

=cut

sub _stampTime {
    my ($self, $stamp) = @_;
    
    if( $stamp =~ /^([0-9]+)\/([0-9]+) ([0-9]+)\:([0-9]+):([0-9]+)\.([0-9]+)$/ ) {
        return mktime( $5, $4, $3, $2, $1-1, $self->{year} - 1900 ) + $6 / 1000;
    }
    
    return 0;
}

sub _powerName {
    my ($self, $code) = @_;
    
    if( $code == 0 ) {
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
        extra => $extra,
    );
}

sub toString {
    my ($self, $entry) = @_;
    
    my $actor = $entry->{actor_name} || "Environment";
    my $target = $entry->{target_name} || "Environment";
    my $text;
    
    if( $entry->{action} eq "SWING_DAMAGE" ) {
        $text = sprintf "[%s] %s [%s] %d",
            $actor,
            $entry->{extra}{critical} ? "crit" : "hit",
            $target,
            $entry->{extra}{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{extra}{resisted} if $entry->{extra}{resisted};
        $text .= sprintf " (%d blocked)", $entry->{extra}{blocked} if $entry->{extra}{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{extra}{absorbed} if $entry->{extra}{absorbed};
        $text .= " (crushing)" if $entry->{extra}{crushing};
        $text .= " (glancing)" if $entry->{extra}{glancing};
    } elsif( $entry->{action} eq "SWING_MISSED" ) {
        $text = sprintf "[%s] melee [%s] %s",
            $actor,
            $target,
            lc( $entry->{extra}{misstype} );
    } elsif( $entry->{action} eq "RANGE_DAMAGE" ) {
        $text = sprintf "[%s] %s [%s] %d",
            $actor,
            $entry->{extra}{critical} ? "crit" : "hit",
            $target,
            $entry->{extra}{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{extra}{resisted} if $entry->{extra}{resisted};
        $text .= sprintf " (%d blocked)", $entry->{extra}{blocked} if $entry->{extra}{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{extra}{absorbed} if $entry->{extra}{absorbed};
        $text .= " (crushing)" if $entry->{extra}{crushing};
        $text .= " (glancing)" if $entry->{extra}{glancing};
    } elsif( $entry->{action} eq "SPELL_DAMAGE" ) {
        $text = sprintf "[%s] %s %s [%s] %d",
            $actor,
            $entry->{extra}{spellname},
            $entry->{extra}{critical} ? "crit" : "hit",
            $target,
            $entry->{extra}{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{extra}{resisted} if $entry->{extra}{resisted};
        $text .= sprintf " (%d blocked)", $entry->{extra}{blocked} if $entry->{extra}{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{extra}{absorbed} if $entry->{extra}{absorbed};
        $text .= " (crushing)" if $entry->{extra}{crushing};
        $text .= " (glancing)" if $entry->{extra}{glancing};
    } elsif( $entry->{action} eq "SPELL_MISSED" ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            lc( $entry->{extra}{misstype} );
    } elsif( $entry->{action} eq "SPELL_HEAL" ) {
        $text = sprintf "[%s] %s %s [%s] %d",
            $actor,
            $entry->{extra}{spellname},
            $entry->{extra}{critical} ? "crit heal" : "heal",
            $target,
            $entry->{extra}{amount};
    } elsif( $entry->{action} eq "SPELL_ENERGIZE" ) {
        $text = sprintf "[%s] %s energize [%s] %d %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            $entry->{extra}{amount},
            $entry->{extra}{powertype};
    } elsif( $entry->{action} eq "SPELL_PERIODIC_MISSED" ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            lc( $entry->{extra}{misstype} );
    } elsif( $entry->{action} eq "SPELL_PERIODIC_DAMAGE" ) {
        $text = sprintf "[%s] %s dot [%s] %d",
            $actor,
            $entry->{extra}{spellname},
            $target,
            lc( $entry->{extra}{amount} );
        
        $text .= sprintf " (%d resisted)", $entry->{extra}{resisted} if $entry->{extra}{resisted};
        $text .= sprintf " (%d blocked)", $entry->{extra}{blocked} if $entry->{extra}{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{extra}{absorbed} if $entry->{extra}{absorbed};
        $text .= " (crushing)" if $entry->{extra}{crushing};
        $text .= " (glancing)" if $entry->{extra}{glancing};
    } elsif( $entry->{action} eq "SPELL_PERIODIC_HEAL" ) {
        $text = sprintf "[%s] %s hot [%s] %d",
            $actor,
            $entry->{extra}{spellname},
            $target,
            lc( $entry->{extra}{amount} );
    } elsif( $entry->{action} eq "SPELL_PERIODIC_DRAIN" ) {
        $text = sprintf "[%s] %s drain [%s] %d %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            $entry->{extra}{amount},
            $entry->{extra}{powertype};
    } elsif( $entry->{action} eq "SPELL_PERIODIC_LEECH" ) {
        $text = sprintf "[%s] %s leech [%s] %d %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            $entry->{extra}{amount},
            $entry->{extra}{powertype};
    } elsif( $entry->{action} eq "SPELL_PERIODIC_ENERGIZE" ) {
        $text = sprintf "[%s] %s energize [%s] %d %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            $entry->{extra}{amount},
            $entry->{extra}{powertype};
    } elsif( $entry->{action} eq "SPELL_DRAIN" ) {
        $text = sprintf "[%s] %s drain [%s] %d %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            $entry->{extra}{amount},
            $entry->{extra}{powertype};
    } elsif( $entry->{action} eq "SPELL_LEECH" ) {
        $text = sprintf "[%s] %s leech [%s] %d %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            $entry->{extra}{amount},
            $entry->{extra}{powertype};
    } elsif( $entry->{action} eq "SPELL_INTERRUPT" ) {
        $text = sprintf "[%s] %sinterrupt [%s] %s",
            $actor,
            $entry->{extra}{spellname} ? $entry->{extra}{spellname} . " " : "",
            $target,
            $entry->{extra}{extraspellname},
    } elsif( $entry->{action} eq "SPELL_EXTRA_ATTACKS" ) {
        $text = sprintf "[%s] %s +%d attack%s",
            $actor,
            $entry->{extra}{spellname},
            $entry->{extra}{amount},
            $entry->{extra}{amount} > 1 ? "s" : "",
    } elsif( $entry->{action} eq "SPELL_INSTAKILL" ) {
        $text = sprintf "[%s] instakill [%s]",
            $actor,
            $target,
    } elsif( $entry->{action} eq "SPELL_DURABILITY_DAMAGE" ) {

    } elsif( $entry->{action} eq "SPELL_DURABILITY_DAMAGE_ALL" ) {

    } elsif( $entry->{action} eq "SPELL_DISPEL_FAILED" ) {

    } elsif( $entry->{action} eq "SPELL_AURA_DISPELLED" ) {

    } elsif( $entry->{action} eq "SPELL_AURA_STOLEN" ) {
        
    } elsif( $entry->{action} eq "SPELL_AURA_APPLIED" ) {
        $text = sprintf "[%s] %s %s",
            $target,
            $entry->{extra}{auratype} eq "DEBUFF" ? "afflicted by" : "gain",
            $entry->{extra}{spellname};
    } elsif( $entry->{action} eq "SPELL_AURA_REMOVED" ) {
        $text = sprintf "[%s] fade %s",
            $target,
            $entry->{extra}{spellname};
    } elsif( $entry->{action} eq "SPELL_AURA_APPLIED_DOSE" ) {
        $text = sprintf "[%s] %s %s (%d)",
            $target,
            $entry->{extra}{auratype} eq "DEBUFF" ? "afflicted by" : "gain",
            $entry->{extra}{spellname},
            $entry->{extra}{amount};
    } elsif( $entry->{action} eq "SPELL_AURA_REMOVED_DOSE" ) {
        $text = sprintf "[%s] decrease dose %s (%d)",
            $target,
            $entry->{extra}{spellname},
            $entry->{extra}{amount};
    } elsif( $entry->{action} eq "SPELL_CAST_START" ) {

    } elsif( $entry->{action} eq "SPELL_CAST_SUCCESS" ) {
        $text = sprintf "[%s] cast %s [%s]",
            $actor,
            $entry->{extra}{spellname},
            $target;
    } elsif( $entry->{action} eq "SPELL_CAST_FAILED" ) {

    } elsif( $entry->{action} eq "DAMAGE_SHIELD" ) {
        $text = sprintf "[%s] %s reflect %s [%s] %d",
            $actor,
            $entry->{extra}{spellname},
            $entry->{extra}{critical} ? "crit " : "",
            $target,
            $entry->{extra}{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{extra}{resisted} if $entry->{extra}{resisted};
        $text .= sprintf " (%d blocked)", $entry->{extra}{blocked} if $entry->{extra}{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{extra}{absorbed} if $entry->{extra}{absorbed};
        $text .= " (crushing)" if $entry->{extra}{crushing};
        $text .= " (glancing)" if $entry->{extra}{glancing};
    } elsif( $entry->{action} eq "DAMAGE_SHIELD_MISSED" ) {
        $text = sprintf "[%s] %s [%s] %s",
            $actor,
            $entry->{extra}{spellname},
            $target,
            lc( $entry->{extra}{misstype} );
    } elsif( $entry->{action} eq "ENCHANT_APPLIED" ) {

    } elsif( $entry->{action} eq "ENCHANT_REMOVED" ) {

    } elsif( $entry->{action} eq "ENVIRONMENTAL_DAMAGE" ) {

    } elsif( $entry->{action} eq "DAMAGE_SPLIT" ) {
        $text = sprintf "[%s] %s %s [%s] %d (split)",
            $actor,
            $entry->{extra}{spellname},
            $entry->{extra}{critical} ? "crit" : "hit",
            $target,
            $entry->{extra}{amount};
        
        $text .= sprintf " (%d resisted)", $entry->{extra}{resisted} if $entry->{extra}{resisted};
        $text .= sprintf " (%d blocked)", $entry->{extra}{blocked} if $entry->{extra}{blocked};
        $text .= sprintf " (%d absorbed)", $entry->{extra}{absorbed} if $entry->{extra}{absorbed};
        $text .= " (crushing)" if $entry->{extra}{crushing};
        $text .= " (glancing)" if $entry->{extra}{glancing};
    } elsif( $entry->{action} eq "UNIT_DIED" ) {
        $text = sprintf "[%s] dies",
            $target;
    }
    
    return $text;
}

sub _split {
    my ($self, $line) = @_;
    my ($t, $rest) = $self->_pullStamp($line);
    
    return $t, map { $_ eq "nil" ? undef : $_ } split /"?,(?=".*?"(?:,|$)|[^",]+(?:,|$))"?/, $rest;
}

sub _pullStamp {
    my ($self, $line) = @_;
    
    if( $line =~ /^([0-9]+)\/([0-9]+) ([0-9]+)\:([0-9]+):([0-9]+)\.([0-9]+)  (.+?)\s*$/ ) {
        my $t = mktime( $5, $4, $3, $2, $1-1, $self->{year} - 1900 ) + $6 / 1000;
        $line = "$7";
        
        return ($t, $line);
    } else { 
        return (0, $line);
    }
}

1;
