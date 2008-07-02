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

package Stasis::SpellPage;

use strict;
use warnings;
use POSIX;
use HTML::Entities;
use Stasis::PageMaker;
use Stasis::ActorGroup;

sub new {
    my $class = shift;
    my %params = @_;
    
    $params{ext} ||= {};
    $params{raid} ||= {};
    $params{grouper} = Stasis::ActorGroup->new;
    $params{grouper}->run( $params{raid}, $params{ext} );
    $params{name} ||= "Untitled";
    
    bless \%params, $class;
}

sub page {
    my $self = shift;
    my $SPELL = shift;
    
    return unless $SPELL;
    
    my $PAGE;
    my $pm = Stasis::PageMaker->new( raid => $self->{raid}, ext => $self->{ext}, grouper => $self->{grouper} );
    
    ###############
    # PAGE HEADER #
    ###############
    
    my $displayName = HTML::Entities::encode_entities($self->{ext}{Index}->spellname($SPELL));
    my ($raidStart, $raidEnd, $raidPresence) = $self->{ext}{Presence}->presence();
    $PAGE .= $pm->pageHeader($self->{name}, $displayName, $raidStart);
    $PAGE .= sprintf "<h3 class=\"colorMob\">%s</h3>", $displayName;
    
    my @summaryRows;
    
    # Wowhead link
    if( $SPELL =~ /^\d+$/ ) {
        push @summaryRows, "Wowhead link" => sprintf "<a href=\"http://www.wowhead.com/?spell=%s\" target=\"swswh_%s\">%s &#187;</a>", $SPELL, $SPELL, $displayName;
    }
    
    $PAGE .= $pm->vertBox( "Spell summary", @summaryRows );
    
    $PAGE .= $pm->pageFooter;
    
    return $PAGE;
}

1;
