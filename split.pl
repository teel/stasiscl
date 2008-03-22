#!/usr/bin/perl

use strict;
use warnings;
use lib 'lib';
use Stasis::Parser;
use Stasis::LogSplit;
use Stasis::ActorPage;
use Stasis::ChartPage;
use Stasis::ClassGuess;
use Data::Dumper;
use POSIX;

my $OUTDIR = "/Users/gian/Documents/NewStasis/STASIS";
my $LOGGER = $ARGV[0];

die "First argument must be the name of the logger (you)" unless $LOGGER && $LOGGER =~ /^[A-Za-z]+$/;

# Parse the log.
$| = 1;
print "$0: parsing log .. ";
my (@log) = <STDIN>;
my $parser = Stasis::Parser->new($LOGGER);
my @actions = $parser->parse(@log);
print "done\n$0: building actors list .. ";
my %all_actors = $parser->actors(@actions);
printf "%d actions, %d actors\n", scalar @actions, scalar keys %all_actors;

# Guess classes.
my $guesser = Stasis::ClassGuess->new( \%all_actors );
my %raid;
foreach my $actor (keys %all_actors) {
    my $cguess = $guesser->guess($actor);
    $raid{$actor}{class} = $cguess->{class} if $cguess;
    $raid{$actor}{pets} = $cguess->{pets} if $cguess && $cguess->{pets};
    
    if( $cguess->{pets} && ref $cguess->{pets} eq "ARRAY" ) {
        foreach (@{$cguess->{pets}}) {
            $raid{$_}{class} = "Pet";
        }
    }
}

# Split the log.
print "$0: splitting bosses .. ";
my $splitter = Stasis::LogSplit->new;
my %splits = $splitter->split(@actions);
print sprintf "%d bosses\n", scalar keys %splits;

# Look at each individual split.
while( my ($boss, $split) = each(%splits) ) {
    print "$0: $boss: writing files .. ";

    # This is the section of the log we'll be dealing with.
    my @splitactions = @actions[$split->{startLine} .. $split->{endLine}];
    
    # Get an actors list for this section.
    my $parser = Stasis::Parser->new($LOGGER);
    my %actors = $parser->actors(@splitactions);
    
    # This is the directory we'll put our stuff in.
    my $bossclean = $boss;
    $bossclean =~ s/[^\w]/_/g;
    my $dname = sprintf "%s/sws-%d", $OUTDIR, floor($split->{start});
    
    eval {
        # Remove the directory.
        system "rm -rf $dname" if $dname && -d $dname;

        # Create the directory.
        mkdir $dname or die $!;
        
        # Write the files.
        foreach my $actor (keys %actors) {
            my $id = lc $actor;
            $id =~ s/[^\w]/_/g;

            open ACTORPAGE, sprintf ">$dname/actor_%s.html", $id;

            my $ap = Stasis::ActorPage->new(\%actors, \%raid, \@splitactions, $boss);
            print ACTORPAGE $ap->page($actor);
            close ACTORPAGE;
        }

        # Write the index.
        my $charter = Stasis::ChartPage->new(\%actors, \%raid, \@splitactions, $boss);
        my ($chart_html, $chart_xml) = $charter->page;
        open CHARTPAGE, ">$dname/index.html";
        print CHARTPAGE $chart_html;
        close CHARTPAGE;
        
        # Write the data.xml file.
        open DATAXML, ">$dname/data.xml";
        print DATAXML $chart_xml;
        close DATAXML;
        
        # Report success.
        printf "%d actions, %d actors\n", scalar @splitactions, scalar keys %actors;
    }; if( $@ ) {
        print STDERR "error: $@\n";
    }
    
}
