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

package Stasis::CLI::Writer;

use strict;
use warnings;

use open ':encoding(utf8)';
use File::Path ();
use POSIX qw/floor/;

sub new {
    my ( $class, %params ) = @_;

    bless {
        base     => $params{base},
        server   => $params{server},
        template => $params{template} || "sws-:short:-:start:",
    }, $class;
}

sub set {
    my ( $self, %params ) = @_;
    
    foreach my $key qw/boss raid exts index collapse/ {
        $self->{$key} = $params{$key};
    }
}

sub fill_template {
    my ( $self ) = @_;
    my ( $boss, $raid, $exts, $index, $collapse ) = map { $self->{$_} } qw/boss raid exts index collapse/;
    
    my $players =
      grep { $exts->{Presence}{actors}{$_} }
      grep { $raid->{$_} && $raid->{$_}{class} && $raid->{$_}{class} ne "Pet" } keys %$raid;
    my $players_rounded = $players <= 13 ? 10 : 25; # kind of arbitrary

    my %tmp = (
        short => $boss->{short},
        start => floor( $boss->{start} || 0 ),
        end   => floor( $boss->{end} || 0 ),
        kill  => $boss->{kill},
        raid  => $players,
        rraid => $players_rounded
    );
    
    my $template = $self->{template};
    $template =~ s/:(\w+):/ defined $tmp{$1} ? $tmp{$1} : ":$1:" /eg;
    return $template;
}

sub write_dir {
    my ( $self ) = @_;
    my ( $boss, $raid, $exts, $index, $collapse ) = map { $self->{$_} } qw/boss raid exts index collapse/;
    
    my $dname_suffix = $self->fill_template;
    my $dname = sprintf "%s/%s", $self->{base}, $dname_suffix;
    
    if( -d $self->{base} ) {
        File::Path::rmtree( $dname ) if -d $dname;
        File::Path::mkpath( $dname );
    } else {
        die "not a directory: " . $self->{base};
    }
    
    # Group actors.
    my $grouper = Stasis::ActorGroup->new;
    $grouper->run( $raid, $exts, $index );
    
    # Initialize Pages with these parameters.
    my %page_init = (
        server   => $self->{server},
        dirname  => $dname_suffix,
        name     => $boss->{long},
        short    => $boss->{short},
        raid     => $raid,
        ext      => $exts,
        collapse => $collapse,
        grouper  => $grouper,
        index    => $index,
    );
    
    # Write the index.
    my $charter = Stasis::Page::Chart->new( %page_init );
    
    my ($chart_xml, $chart_html) = $charter->page;
    open CHARTPAGE, ">$dname/index.html" or die;
    print CHARTPAGE $chart_html;
    close CHARTPAGE;
    
    # Write the actor files.
    my $ap = Stasis::Page::Actor->new( %page_init );
    
    foreach my $actor (keys %{$exts->{Presence}{actors}}) {
        # Respect $collapse.
        next if $collapse && $grouper->group($actor);
        
        my $id = lc $actor;
        $id = Stasis::PageMaker->tameText($id);

        open ACTORPAGE, sprintf ">$dname/actor_%s.html", $id or die;
        print ACTORPAGE $ap->page($actor);
        close ACTORPAGE;
    }
    
    # Write the group files.
    foreach my $group (@{$grouper->{groups}}) {
        my $id = lc $grouper->captain($group);
        $id = Stasis::PageMaker->tameText($id);
        
        open GROUPPAGE, sprintf ">$dname/group_%s.html", $id or die;
        print GROUPPAGE $ap->page($grouper->captain($group), 1);
        close GROUPPAGE;
    }
    
    # Write the environment file.
    open ENVPAGE, ">$dname/actor_0.html" or die;
    print ENVPAGE $ap->page(0);
    close ENVPAGE;
    
    # Write the spell files.
    my $sp = Stasis::Page::Spell->new( %page_init );
    
    foreach my $spell (keys %{$index->{spells}}) {
        my $id = lc $spell;
        $id = Stasis::PageMaker->tameText($id);

        open SPELLPAGE, sprintf ">$dname/spell_%s.html", $id or die;
        print SPELLPAGE $sp->page($spell);
        close SPELLPAGE;
    }
    
    # Write death clips.
    my $lc = Stasis::Page::LogClip->new( %page_init );
    
    while( my ($kactor, $vactor) = each(%{$exts->{Death}{actors}}) ) {
        my $id = lc $kactor;
        $id = Stasis::PageMaker->tameText($id);
        
        my $dn = 0;
        foreach my $death (@$vactor) {
            $lc->clear;
            foreach my $event (@{$death->{autopsy}}) {
                $lc->add( $event->{event}, hp => $event->{hp}, t => $event->{t} );
            }
            
            open DEATHPAGE, sprintf ">$dname/death_%s_%d.json", $id, ++$dn or die;
            print DEATHPAGE $lc->json;
            close DEATHPAGE;
        }
    }

    # Write the data.xml file.
    open DATAXML, ">$dname/data.xml" or die;
    print DATAXML $chart_xml;
    close DATAXML;
    
    # Return a hash describing what we just wrote.
    my ($rdamage, $rstart, $rend) = (0, $exts->{Presence}->presence);
    $rdamage = $1 if( $chart_xml =~ /<raid[^>]+dmg="(\d+)"/ );
    
    return {
        dname => $dname_suffix,
        short => $boss->{short},
        long => $boss->{long},
        damage => $rdamage,
        start => $rstart,
        end => $rend,
    };
}

1;
