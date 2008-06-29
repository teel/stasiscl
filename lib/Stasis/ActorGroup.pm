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

package Stasis::ActorGroup;

use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{version} = 2 if !$params{version} || $params{version} != 1;
    $params{groups} = [];
    $params{lookup} = {};
    
    bless \%params, $class;
}

sub run {
    my $self = shift;
    
    # Hash reference to %raid
    my $raid = shift;
    
    # Hash reference to %ext
    my $ext = shift;
    
    # Return value, will be an array of hashes like this:
    
    # {
    #     owner => "0xf130003c7b000eb5",
    #     members => [
    #         "0xf130003c78000e8d".
    #         "0xf130003c78000e8e",
    #     ],
    # }
    
    # 'owner' can be blank
    # 'owner' will be set iff the group represents pets from the same owner
    
    my @groups = ();
    
    # First look at pets with the same name and owner
    foreach my $raider (keys %$raid) {
        if( $raid->{$raider}{pets} ) {
            # Track pet names for $raider.
            my %petnames;
            
            foreach my $pet (@{$raid->{$raider}{pets}}) {
                next unless $raid->{$pet} && $raid->{$pet}{class} eq "Pet";
                
                if( $ext->{Presence}{actors}{$pet} ) {
                    my $petname = $ext->{Index}->actorname($pet);
                    $petnames{$petname} ||= [];
                    push @{ $petnames{$petname} }, $pet;
                }
            }
            
            foreach my $petname (keys %petnames) {
                if( @{ $petnames{$petname} } > 1 ) {
                    # We got enough pets to make a group.
                    
                    push @groups, {
                        owner => $raider,
                        members => [ sort @{$petnames{$petname}} ],
                    };
                }
            }
        }
    }
    
    # Next look at mobs with the same name.
    my %name;
    
    foreach my $mob (keys %{$ext->{Presence}{actors}}) {
        next if $raid->{$mob} && $raid->{$mob}{class};
        
        $name{ $ext->{Index}->actorname($mob) } ||= [];
        push @{ $name{ $ext->{Index}->actorname($mob) } }, $mob;
    }
    
    while( my ($mobname, $moblist) = each( %name ) ) {
        if( @$moblist > 1 ) {
            # We got enough mobs to make a group.
            push @groups, {
                members => [ sort @$moblist ],
            }
        }
    }
    
    $self->{groups} = \@groups;
    
    # Build lookup hash.
    $self->{lookup} = {};
    
    for (my $gid = 0; $gid < @groups ; $gid++) {
        foreach my $member (@{$groups[$gid]->{members}}) {
            $self->{lookup}{$member} = $groups[$gid];
        }
    }
    
    return \@groups;
}

sub group {
    my $self = shift;
    my $actor = shift;
    
    return $self->{lookup}{$actor};
}

sub captain {
    my $self = shift;
    my $group = shift;
    
    return $group->{members}->[0];
}

# Starts from 1
sub number {
    my $self = shift;
    my $actor = shift;
    
    my $n = 0;
    my $group = $self->{lookup}{$actor};
    
    if( $group ) {
        foreach (@{$group->{members}}) {
            $n++;
            
            if( lc $_ eq lc $actor ) {
                return $n;
            }
        }
        
        if( !$n ) {
            carp "Group error on mob \"$actor\"";
        }
        
        return $n;
    } else {
        return 0;
    }
}

1;
