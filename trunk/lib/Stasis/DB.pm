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

package Stasis::DB;

use strict;
use warnings;
use DBI;
use Carp;

use constant {
    db => 0,
    rollback => 1,
    readline_sth => 2,
    readline_result => 3,
    readline_line => 4,
    readline_last => 5,
    lookup_action => 6,
    lookup_extra => 7,
    dbh => 8,
};

our @result_fields = qw(line_id t action actor actor_name actor_relationship target target_name target_relationship kextra vextra use_dict vextra_text);
our @line_fields = qw(t action actor actor_name actor_relationship target target_name target_relationship);

sub new {
    my $class = shift;
    my %params = @_;
    
    my %lookup_action;
    my %lookup_extra;
    
    # Actions
    $lookup_action{"SWING_DAMAGE"} = 1;
    $lookup_action{"SWING_MISSED"} = 2;
    $lookup_action{"RANGE_DAMAGE"} = 3;
    $lookup_action{"RANGE_MISSED"} = 4;
    $lookup_action{"SPELL_DAMAGE"} = 5;
    $lookup_action{"SPELL_MISSED"} = 6;
    $lookup_action{"SPELL_HEAL"} = 7;
    $lookup_action{"SPELL_DRAIN"} = 8;
    $lookup_action{"SPELL_LEECH"} = 9;
    $lookup_action{"SPELL_ENERGIZE"} = 10;
    $lookup_action{"SPELL_PERIODIC_MISSED"} = 11;
    $lookup_action{"SPELL_PERIODIC_DAMAGE"} = 12;
    $lookup_action{"SPELL_PERIODIC_HEAL"} = 13;
    $lookup_action{"SPELL_PERIODIC_DRAIN"} = 14;
    $lookup_action{"SPELL_PERIODIC_LEECH"} = 15;
    $lookup_action{"SPELL_PERIODIC_ENERGIZE"} = 16;
    $lookup_action{"SPELL_AURA_DISPELLED"} = 17;
    $lookup_action{"SPELL_AURA_STOLEN"} = 18;
    $lookup_action{"SPELL_AURA_APPLIED"} = 19;
    $lookup_action{"SPELL_AURA_REMOVED"} = 20;
    $lookup_action{"SPELL_AURA_APPLIED_DOSE"} = 21;
    $lookup_action{"SPELL_AURA_REMOVED_DOSE"} = 22;
    $lookup_action{"SPELL_DISPEL_FAILED"} = 23;
    $lookup_action{"SPELL_INTERRUPT"} = 24;
    $lookup_action{"SPELL_EXTRA_ATTACKS"} = 25;
    $lookup_action{"SPELL_INSTAKILL"} = 26;
    $lookup_action{"SPELL_DURABILITY_DAMAGE"} = 27;
    $lookup_action{"SPELL_DURABILITY_DAMAGE_ALL"} = 28;
    $lookup_action{"SPELL_CAST_START"} = 29;
    $lookup_action{"SPELL_CAST_SUCCESS"} = 30;
    $lookup_action{"SPELL_CAST_FAILED"} = 31;
    $lookup_action{"DAMAGE_SHIELD"} = 32;
    $lookup_action{"DAMAGE_SHIELD_MISSED"} = 33;
    $lookup_action{"PARTY_KILL"} = 34;
    $lookup_action{"UNIT_DIED"} = 35;
    $lookup_action{"UNIT_DESTROYED"} = 36;
    $lookup_action{"ENCHANT_APPLIED"} = 37;
    $lookup_action{"ENCHANT_REMOVED"} = 38;
    $lookup_action{"ENVIRONMENTAL_DAMAGE"} = 39;
    $lookup_action{"DAMAGE_SPLIT"} = 40;
    $lookup_action{"SPELL_CREATE"} = 41;
    $lookup_action{"SPELL_SUMMON"} = 42;
    
    # Extras
    $lookup_extra{"absorbed"} = 1;
    $lookup_extra{"amount"} = 2;
    $lookup_extra{"auratype"} = 3;
    $lookup_extra{"blocked"} = 4;
    $lookup_extra{"critical"} = 5;
    $lookup_extra{"crushing"} = 6;
    $lookup_extra{"environmentaltype"} = 7;
    $lookup_extra{"extraamount"} = 8;
    $lookup_extra{"extraspellid"} = 9;
    $lookup_extra{"extraspellname"} = 10;
    $lookup_extra{"glancing"} = 11;
    $lookup_extra{"misstype"} = 12;
    $lookup_extra{"resisted"} = 13;
    $lookup_extra{"spellid"} = 14;
    $lookup_extra{"spellname"} = 15;
    $lookup_extra{"extraspellschool"} = 16;
    $lookup_extra{"school"} = 17;
    $lookup_extra{"spellschool"} = 18;
    $lookup_extra{"powertype"} = 19;
    
    croak("No DB specified") unless $params{db};
    bless [
        $params{db},
        0,
        undef,
        undef,
        undef,
        undef,
        \%lookup_action,
        \%lookup_extra,
        undef,
    ], $class;
}

sub create {
    my $self = shift;
    
    my $dbh = $self->_dbh();
    eval {
        $self->_begin();
        
        # Action table -- just a list of wow actions, basically an index
        $dbh->do(
            "CREATE TABLE action (
                action_id             INTEGER PRIMARY KEY,
                action                TEXT NOT NULL UNIQUE
            )"
        ) or die;
        
        # Extra table -- just a list of extra fields
        $dbh->do(
            "CREATE TABLE extra (
                extra_id              INTEGER PRIMARY KEY,
                extra                 TEXT NOT NULL UNIQUE
            )"
        ) or die;
        
        # Line table -- references actor table (twice), log table, and action table
        $dbh->do(
            "CREATE TABLE line (
                line_id               INTEGER PRIMARY KEY,
                
                t                     INTEGER NOT NULL,

                action_id             INTEGER NOT NULL DEFAULT 0,

                actor_id              INTEGER NOT NULL DEFAULT 0,
                actor_relationship    INTEGER NOT NULL DEFAULT 0,

                target_id             INTEGER NOT NULL DEFAULT 0,
                target_relationship   INTEGER NOT NULL DEFAULT 0
            )"
        ) or die;
        
        $dbh->do(
            "CREATE TABLE dict (
                dict_id               INTEGER PRIMARY KEY,
                text                  TEXT NOT NULL UNIQUE
            )"
        );
        
        # Line_extra table -- stores the {extra} hash for a log entry
        # if use_dict is 1 we will interpret "extra" as a "dict_id"
        $dbh->do(
            "CREATE TABLE line_extra (
                le_id                 INTEGER PRIMARY KEY,
                
                line_id               INTEGER NOT NULL,
                extra_id              INTEGER NOT NULL,
                extra                 INTEGER NOT NULL,
                use_dict              INTEGER NOT NULL DEFAULT 0,
                
                UNIQUE (line_id, extra_id)
            )"
        ) or die;
        
        # Actor table -- stores names and wow GUIDs of actors (different from the sqlite rowid) on a per log basis
        # Also stores class info
        $dbh->do(
            "CREATE TABLE actor (
                actor_id              INTEGER PRIMARY KEY,
                
                actor_guid            TEXT NOT NULL UNIQUE,
                actor_name            TEXT NOT NULL,
                
                class                 TEXT NOT NULL DEFAULT \"\"
            )"
        ) or die;
        
        ## HINTS tables ##
        
        # Split table -- stores interesting splits like boss attempts, kills, etc
        $dbh->do(
            "CREATE TABLE split (
                split_id              INTEGER PRIMARY KEY,
                
                short                 TEXT NOT NULL,
                long                  TEXT NOT NULL,
                kill                  INTEGER NOT NULL DEFAULT 0,
                start_id              INTEGER NOT NULL UNIQUE,
                end_id                INTEGER NOT NULL,
                
                CHECK (end_id >= start_id)
            )"
        ) or die;
        
        # Pet table -- stores which actors are pets of which other actors
        $dbh->do(
            "CREATE TABLE pet (
                pet_id                INTEGER PRIMARY KEY,
                
                actor_id              INTEGER NOT NULL,
                owner_id              INTEGER NOT NULL,
                
                UNIQUE (owner_id, actor_id)
            )"
        ) or die;
        
        # Insert hash data
        while( my ($kextra, $vextra) = each( %{$self->[Stasis::DB::lookup_extra] } ) ) {
            $dbh->do( sprintf( "INSERT INTO extra (extra_id, extra) VALUES( %d, \"%s\" )", $vextra, $kextra ) );
        }
        
        while( my ($kaction, $vaction) = each( %{$self->[Stasis::DB::lookup_action] } ) ) {
            $dbh->do( sprintf( "INSERT INTO action (action_id, action) VALUES( %d, \"%s\" )", $vaction, $kaction ) );
        }
    }; if( $@ ) {
        my $err = $@;
        eval { $self->_rollback(); };
        croak "Error creating data file: $err";
    }
}

sub finish {
    my $self = shift;
    $self->_commit();
}

sub addLine {
    my $self = shift;
    my $seq = shift;
    my $entry = shift;
    
    if( $seq =~ /^[0-9]+$/ && $entry ) {
        my $dbh = $self->_dbh();
        eval {
            my $sth;

            # Check the lookup tables.
            if( !$self->[Stasis::DB::lookup_action]{ $entry->{action} } ) {
                carp "unrecognized action, not including in db: " . $entry->{action};
                return;
            }

            foreach (keys %{$entry->{extra}}) {
                if( !$self->[Stasis::DB::lookup_extra]{$_} ) {
                    carp "unrecognized extra, not including in db: " . $entry->{action} . "::$_";
                    return;
                }
            }

            # Insert the line itself
            $sth = $dbh->prepare( "INSERT INTO line (line_id, t, action_id, actor_id, actor_relationship, target_id, target_relationship) VALUES ( ?, ?, ?, ?, ?, ?, ? );" );
            $sth->execute( 
                $seq, # line_id
                $entry->{t}, # t
                $self->[Stasis::DB::lookup_action]{ $entry->{action} }, # action_id
                $self->_actor_need( $entry->{actor}, $entry->{actor_name} ), # actor_id
                $entry->{actor_relationship}, # actor_relationship
                $self->_actor_need( $entry->{target}, $entry->{target_name} ), # target_id
                $entry->{target_relationship}, # target_relationship
            );
            $sth->finish;
            undef $sth;

            my $lineid = $dbh->func('last_insert_rowid');

            # Insert the extras.
            while( my ($kextra, $vextra) = each(%{$entry->{extra}}) ) {
                $sth = $dbh->prepare( "INSERT INTO line_extra (line_id, extra_id, extra, use_dict) VALUES ( ?, ?, ?, ? );" );
                $sth->execute(
                    $lineid, # line_id
                    $self->[Stasis::DB::lookup_extra]{$kextra}, # extra_id
                    $vextra =~ /^[0-9]+$/ ? $vextra : $self->_dict_need( $vextra ), # extra
                    $vextra =~ /^[0-9]+$/ ? 0 : 1, # use_dict
                );
                $sth->finish;
                undef $sth;
            }
        }; if( $@ ) {
            my $err = $@;
            eval { $self->_rollback(); };
            croak "error saving parsed log: $err";
        }
    } else {
        croak "bad input";
    }
}

sub line {
    my $self = shift;
    my $startLine = shift;
    my $endLine = shift;
    
    # Maybe change our saved sth
    if( $startLine && $endLine ) {
        if( $self->[Stasis::DB::readline_sth] ) {
            $self->[Stasis::DB::readline_sth]->finish;
            undef $self->[Stasis::DB::readline_sth];
        }
        
        my $dbh = $self->_dbh();
        $self->[Stasis::DB::readline_sth] = $dbh->prepare( "SELECT line.line_id, line.t, action.action, actor.actor_guid AS actor, actor.actor_name, line.actor_relationship, target.actor_guid AS target, target.actor_name AS target_name, line.target_relationship, extra.extra AS kextra, line_extra.extra AS vextra, line_extra.use_dict, dict.text AS vextra_text FROM line LEFT JOIN action ON action.action_id = line.action_id LEFT JOIN actor ON actor.actor_id = line.actor_id LEFT JOIN actor AS target ON target.actor_id = line.target_id LEFT JOIN line_extra ON line_extra.line_id = line.line_id LEFT JOIN extra ON extra.extra_id = line_extra.extra_id LEFT JOIN dict ON dict.dict_id = line_extra.extra WHERE line.line_id >= ? AND line.line_id <= ? ORDER BY line.line_id;" );
        $self->[Stasis::DB::readline_sth]->execute( $startLine, $endLine );
        
        # Set up result bindings.
        my %result;
        @result{@result_fields} = ();
        $self->[Stasis::DB::readline_sth]->bind_columns( map { \$result{$_} } @result_fields );
        $self->[Stasis::DB::readline_result] = \%result;
        
        # Set up the line we want to use.
        my %line;
        @line{@line_fields} = ();
        $line{extra} = {};
        $self->[Stasis::DB::readline_line] = \%line;
        
        # Clear "last" marker.
        $self->[Stasis::DB::readline_last] = 0;
        
        # Just return nothing.
        return undef;
    } elsif( $self->[Stasis::DB::readline_sth] ) {
        # Reading...
        my $r_line_id = \$self->[Stasis::DB::readline_result]{line_id};
        my $line_id = ${$r_line_id} || 0;
        
        if( $line_id ) {
            # There's a %result from the last call to line() with id $line_id
            # Use it to start a new line
            $self->_makeline(1);
        }
        
        # Read more from the result set.
        while( $self->[Stasis::DB::readline_sth]->fetch ) {
            if( !$line_id ) {
                # Set line_id if it came in as zero (meaning this is the first line)
                $line_id = ${$r_line_id};
                $self->_makeline(1);
            } elsif( $line_id == ${$r_line_id} ) {
                # Still reading the same line. Append to %line.
                $self->_makeline(0);
            } else {
                # Got a new line. Return.
                return $self->[Stasis::DB::readline_line];
            }
        }
        
        # Reached the end of the result set.
        # Return the current line and clear our stored info.
        $self->[Stasis::DB::readline_sth]->finish;
        $self->[Stasis::DB::readline_sth] = undef;
        $self->[Stasis::DB::readline_last] = 1;
        
        return $self->[Stasis::DB::readline_line];
    } elsif( $self->[Stasis::DB::readline_last] ) {
        $self->[Stasis::DB::readline_last] = 0;
        return undef;
    } else {
        croak "line() without line(start, end)";
    }
}

sub _makeline {
    my $self = shift;
    my $new = shift;
    my $line = $self->[Stasis::DB::readline_line];
    my $result = $self->[Stasis::DB::readline_result];
    
    if( !$new ) {
        # Line is already set up. Just add the extra.
        $line->{extra}{ $result->{kextra} } = $result->{use_dict} ? $result->{vextra_text} : $result->{vextra};
    } else {
        # Line is new, create it.
        foreach (@line_fields) {
            $line->{$_} = $result->{$_};
        }
        
        # Replace undefined actor or target with blank
        if( !$line->{actor} ) {
            $line->{actor} = 0;
            $line->{actor_name} = "";
        }
        
        if( !$line->{target} ) {
            $line->{target} = 0;
            $line->{target_name} = "";
        }
        
        $line->{extra} = $result->{kextra} ? {
            $result->{kextra} => ($result->{use_dict} ? $result->{vextra_text} : $result->{vextra}) || 0
        } : {};
    }
}

sub splits {
    my $self = shift;
    my $splits = shift;
    
    my $dbh = $self->_dbh();
    if( $splits && ref $splits eq "ARRAY" ) {
        eval {
            $dbh->do( "DELETE FROM split;" );
            
            foreach my $split (@$splits) {
                my $sth = $dbh->prepare( "INSERT INTO split (short, long, kill, start_id, end_id) VALUES (?, ?, ?, ?, ?);");
                $sth->execute(
                    $split->{short}, # short
                    $split->{long}, # long
                    $split->{kill}, # kill
                    $split->{startLine}, # start_id
                    $split->{endLine}, # end_id
                );
                $sth->finish;
                undef $sth;
            }
        }; if( $@ ) {
            my $err = $@;
            eval { $self->_rollback(); };
            croak "error saving splits: $err";
        }
    }
    
    # Always return the splits
    my $sth = $dbh->prepare( "SELECT short, long, kill, start_id AS startLine, end_id AS endLine, line.t AS start, line2.t AS end FROM split JOIN line ON line.line_id = split.start_id JOIN line AS line2 ON line2.line_id = split.end_id;");
    $sth->execute();
    my $ret = $sth->fetchall_arrayref({});
    $sth->finish;
    undef $sth;
    
    return $ret;
}

sub raid {
    my $self = shift;
    my $raid = shift;
    
    my $dbh = $self->_dbh();
    if( $raid && ref $raid eq "HASH" ) {
        eval {
            $dbh->do( "UPDATE actor SET class = \"\";" );
            $dbh->do( "DELETE FROM pet;" );
            
            my $sth;
            while( my ($kraid, $vraid) = each (%$raid) ) {
                # Add class
                if( $vraid->{class} ) {
                    $sth = $dbh->prepare( "UPDATE actor SET class = ? WHERE actor_guid = ?" );
                    $sth->execute( $vraid->{class}, $kraid );
                    $sth->finish;
                    undef $sth;
                }
                
                # Add pets
                foreach my $pet (@{$vraid->{pets}}) {
                    $sth = $dbh->prepare( "INSERT INTO pet (actor_id, owner_id) VALUES (?, ?);");
                    $sth->execute( $self->_actor_need($pet), $self->_actor_need($kraid) );
                    $sth->finish;
                    undef $sth;
                }
            }
        }; if( $@ ) {
            my $err = $@;
            eval { $self->_rollback(); };
            croak "error saving classes and pets: $err";
        }
    }
    
    # Always return the %raid hash
    my $sth = $dbh->prepare( "SELECT actor.actor_guid, actor.actor_name, actor.class, actor2.actor_guid AS pet_guid FROM actor LEFT JOIN pet ON actor.actor_id = pet.owner_id LEFT JOIN actor AS actor2 ON pet.actor_id = actor2.actor_id WHERE actor.class != \"\";");
    $sth->execute;
    my %ret;
    
    while( my $retrow = $sth->fetchrow_hashref ) {
        $ret{ $retrow->{actor_guid} }{class} = $retrow->{class};
        $ret{ $retrow->{actor_guid} }{pets} ||= [];
        
        if( $retrow->{pet_guid} ) {
            push @{ $ret{ $retrow->{actor_guid} }{pets} }, $retrow->{pet_guid};
        }
    }
    
    $sth->finish;
    undef $sth;
    
    return \%ret;
}

sub ext {
    my $self = shift;
    my $ext = shift;
}

sub disconnect {
    my $self = shift;

    if( $self->[Stasis::DB::dbh] ) {
        $self->[Stasis::DB::dbh]->disconnect;
        undef $self->[Stasis::DB::dbh];
    }
}

sub _actor_need {
    my $self = shift;
    my $guid = shift;
    my $name = shift;
    
    # Return 0 if the guid is not set.
    if( !$guid ) {
        return 0;
    }
    
    # Otherwise look for the correct actor_id :
    my $dbh = $self->_dbh();
    my $sth = $dbh->prepare( "SELECT actor_id FROM actor WHERE actor_guid = ?" );
    $sth->execute( $guid );
    
    my $result = $sth->fetchrow_hashref;
    $sth->finish;
    undef $sth;
    
    if( $result ) {
        return $result->{actor_id};
    } elsif( $name ) {
        # Name was set
        $sth = $dbh->prepare( "INSERT INTO actor (actor_guid, actor_name) VALUES (?, ?);");
        $sth->execute( $guid, $name );
        $sth->finish;
        undef $sth;
        
        return $dbh->func('last_insert_rowid');
    } else {
        # Name was not set... the caller expected this thing to be found.
        croak "actor not found: $guid";
    }
}

sub _dict_need {
    my $self = shift;
    my $text = shift;
    
    # Return 0 if the text is not set.
    if( !$text ) {
        return 0;
    }
    
    # Otherwise look for the correct dict_id :
    my $dbh = $self->_dbh();
    my $sth = $dbh->prepare( "SELECT dict_id FROM dict WHERE text = ?" );
    $sth->execute( $text );
    
    my $result = $sth->fetchrow_hashref;
    $sth->finish;
    undef $sth;
    
    if( $result ) {
        return $result->{dict_id};
    } elsif( $text ) {
        # Text was set
        $sth = $dbh->prepare( "INSERT INTO dict (text) VALUES (?);");
        $sth->execute( $text );
        $sth->finish;
        undef $sth;
        
        return $dbh->func('last_insert_rowid');
    } else {
        # Name was not set... the caller expected this thing to be found.
        croak "dictionary entry not found: $text";
    }
}

sub _begin {
    my $self = shift;
    my $dbh = $self->_dbh();
    $dbh->do( "BEGIN" );
}

sub _rollback {
    my $self = shift;
    
    $self->[Stasis::DB::rollback] = 1;
    my $dbh = $self->_dbh();
    $dbh->do( "ROLLBACK" );
    $self->disconnect();
}

sub _commit {
    my $self = shift;
    my $dbh = $self->_dbh();
    $dbh->do( "COMMIT" );
}

sub _dbh {
    my $self = shift;
    
    if( $self->[Stasis::DB::rollback] ) {
        croak "db object has been rolled back, create a new one";
    }
    
    $self->[Stasis::DB::dbh] ||= DBI->connect( "dbi:SQLite:" . $self->[Stasis::DB::db], undef, undef, {RaiseError=>1} ) or croak "Cannot read local database: $DBI::errstr";
    return $self->[Stasis::DB::dbh];
    
}

1;
