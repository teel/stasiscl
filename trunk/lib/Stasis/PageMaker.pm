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

package Stasis::PageMaker;

use strict;
use warnings;
use POSIX;
use HTML::Entities qw();
use Stasis::Extension qw(ext_sum);
use Carp;

sub new {
    my $class = shift;
    my %params = @_;
    
    # Section ID
    $params{id} = 0;
    
    # Tip ID
    $params{tid} = 0;
    
    bless \%params, $class;
}

sub tabBar {
    my $self = shift;
    
    my $BAR;
    $BAR .= "<div class=\"tabContainer\">";
    $BAR .= "<div class=\"tabBar\">";
    
    foreach my $tab (@_) {
        $BAR .= sprintf 
            "<a href=\"#%s\" onclick=\"toggleTab('%s');\" id=\"tablink_%s\" class=\"tabLink\">%s</a>",
            $self->tameText($tab),
            $self->tameText($tab), 
            $self->tameText($tab), 
            $tab;
    }
    
    $BAR .= "</div>";
}

sub tabBarEnd {
    return "</div>";
}

sub tabStart {
    my $self = shift;
    my $name = shift;
    
    my $id = $self->tameText($name);
    return "<div class=\"tab\" id=\"tab_$id\">";
}

sub tabEnd {
    return "</div>";
}

sub tableStart {
    my $self = shift;
    my $class = shift;
    
    $class ||= "stat";
    
    return "<table cellspacing=\"0\" class=\"$class\">";
}

sub tableEnd {
    return "</table><br />";
}

sub tableTitle {
    my $self = shift;
    my $title = shift;
    
    return sprintf "<tr><th class=\"title\" colspan=\"%d\">%s</th></tr>", scalar @_, $title;
}

# tableHeader( @header_rows )
sub tableHeader {
    my $self = shift;
    
    my $result = $self->tableTitle( shift, @_ );
    
    $result .= "<tr>";
    
    foreach my $col (@_) {
        my $style_text = "";
        if( $col =~ /^R-/ ) {
            $style_text .= "text-align: right;";
        }
        
        if( $col =~ /-W$/ ) {
            $style_text .= "white-space: normal; width: 300px;";
        }
        
        if( $style_text ) {
            $style_text = " style=\"${style_text}\"";
        }
        
        my $ncol = $col;
        $ncol =~ s/^R-//;
        $ncol =~ s/-W$//;
        $result .= sprintf "<th${style_text}>%s</th>", $ncol;
    }
    
    $result .= "</tr>";
}

# tableRow( %args )
sub tableRow {
    my $self = shift;
    my %params = @_;
    
    my $result;
    
    $params{header} ||= [];
    $params{data} ||= {};
    $params{type} ||= "";
    
    # Override 'name'
    $params{name} = $params{type} eq "master" ? ++$self->{id} : $self->{id};
    
    if( $params{type} eq "slave" ) {
        $result .= "<tr class=\"s\" name=\"s" . $params{name} . "\">";
    } elsif( $params{type} eq "master" ) {
        $result .= "<tr class=\"sectionMaster\">";
    } else {
        $result .= "<tr class=\"section\">";
    }
    
    my $firstflag;
    foreach my $col (@{$params{header}}) {
        my @class;
        my $align = "";
        
        if( !$firstflag ) {
            push @class, "f";
        }
        
        push @class, "r" if "R-" eq substr $col, 0, 2;
        push @class, "w" if "-W" eq substr $col, -2;
        
        if( @class ) {
            $align = " class=\"" . join( " ", @class ) . "\"";
        }
        
        if( $col eq " " && $params{data}{$col} ) {
            $params{data}{$col} = sprintf "<div class=\"chartbar\" style=\"width:%dpx\">&nbsp;</div>", $params{data}{$col};
        }
        
        if( !$firstflag && $params{type} eq "master" ) {
            # This is the first one (flag hasn't been set yet)
            $result .= sprintf "<td%s>(<a class=\"toggle\" id=\"as%s\" href=\"javascript:toggleTableSection(%s%s);\">+</a>) %s</td>", $align, $params{name}, $params{name}, $params{url} ? ",'" . $params{url} . "'" : "", $params{data}{$col} =~ /^\d+$/ ? $self->_commify($params{data}{$col}) : $params{data}{$col};
        } else {
            if( $params{data}{$col} ) {
                $result .= "<td${align}>" . ($params{data}{$col} =~ /^\d+$/ ? $self->_commify($params{data}{$col}) : $params{data}{$col}) . "</td>";
            } else {
                $result .= "<td${align}></td>";
            }
        }
        
        $firstflag = 1;
    }
    
    $result .= "</tr>";
}

sub tableRows {
    my ($self, %params) = @_;
    
    # We'll return this.
    my $result;
    
    $params{title} ||= "";
    $params{slave} ||= $params{master};
    $params{master} ||= $params{slave};
    
    # Abort if we have no headers or data.
    return unless $params{master} && $params{data};
    
    # First make master rows. We have to do this first so they can be sorted.
    my %master;
    while( my ($kmaster, $vmaster) = each(%{$params{data}}) ) {
        if( scalar values %$vmaster > 1 ) {
            $master{$kmaster} = ext_sum( {}, values %$vmaster );
        } else {
            $master{$kmaster} = (values %$vmaster)[0];
        }
        
        if( $params{preprocess} ) {
            $params{preprocess}->( $kmaster, $master{$kmaster} );
            $params{preprocess}->( $_, $vmaster->{$_}, $kmaster, $master{$kmaster} ) foreach (keys %$vmaster);
        }
    }
    
    if( %master ) {
        # Print table header.
        $result .= $self->tableHeader( $params{title}, @{$params{header}} ) if $params{title};
        
        # Print rows.
        foreach my $kmaster ( $params{sort} ? sort { $params{sort}->( $master{$a}, $master{$b} ) } keys %master : keys %master ) {
            # Print master row.
            $result .= $self->tableRow( 
                header => $params{header},
                data => $params{master} ? $params{master}->($kmaster, $master{$kmaster}) : {
                    $params{header}->[0] => $kmaster,
                },
                type => "master",
            );

            # Print slave rows.
            my $vmaster = $params{data}{$kmaster};
            foreach my $kslave ( $params{sort} ? sort { $params{sort}->( $vmaster->{$a}, $vmaster->{$b} ) } keys %$vmaster : keys %$vmaster ) {
                $result .= $self->tableRow( 
                    header => $params{header},
                    data => $params{slave} ? $params{slave}->($kslave, $vmaster->{$kslave}, $kmaster, $master{$kmaster}) : {
                        $params{header}->[0] => $kslave,
                    },
                    type => "slave",
                );
            }
        }
    }
    
    return $result;
}

sub pageHeader {
    my $self = shift;
    my $boss = shift;
    my $origtitle = shift;
    my $start = shift;
    
    # Default vars
    $boss ||= "Page";
    $origtitle ||= "";
    my $title = $origtitle ? "$boss : $origtitle" : $boss;
    
    # Reset table row ID
    $self->{id} = 0;
    
    # Reset tip ID
    $self->{tid} = 0;
    
    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime( $start );
    #my $starttxt = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    my $starttxt = asctime localtime $start;
    
    my $PAGE = <<END;
<html>
<head>
<title>$title</title>
<link rel="stylesheet" type="text/css" href="../extras/sws2.css" />
<script type="text/javascript" src="../extras/sws.js"></script>

<!-- YUI -->
<link rel="stylesheet" type="text/css" href="http://yui.yahooapis.com/2.5.2/build/container/assets/skins/sam/container.css"> 
<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/connection/connection-min.js"></script> 
<script type="text/javascript" src="http://yui.yahooapis.com/2.5.2/build/container/container-min.js"></script> 

</head>
<body class="yui-skin-sam" onLoad="hashTab();">
<div class="swsmaster">
<div class="top">
<h2>$boss: $starttxt</h2>
END
    if( $origtitle ) {
        $PAGE .= '<b><a href="index.html#damage_out">Damage Out</a> &ndash; <a href="index.html#damage_in">Damage In</a> &ndash; <a href="index.html#healing">Healing</a> &ndash; <a href="index.html#raid__amp__mobs">Raid &amp; Mobs</a> &ndash; <a href="index.html#deaths">Deaths</a></b>';
    } else {
        $PAGE .= '<b><a href="#damage_out" onclick="toggleTab(\'damage_out\');">Damage Out</a> &ndash; <a href="#damage_in" onclick="toggleTab(\'damage_in\');">Damage In</a> &ndash; <a href="#healing" onclick="toggleTab(\'healing\');">Healing</a> &ndash; <a href="#raid__amp__mobs" onclick="toggleTab(\'raid__amp__mobs\');">Raid &amp; Mobs</a> &ndash; <a href="#deaths" onclick="toggleTab(\'deaths\');">Deaths</a></b>';
    }
    
    return "$PAGE</div>";
}

# pageFooter()
sub pageFooter {
    my $self = shift;
    my $timestr = asctime localtime;
    
    return <<END;
<p class="footer">Generated on $timestr</p>
<p class="footer">stasiscl available at <a href="http://code.google.com/p/stasiscl/">http://code.google.com/p/stasiscl/</a></p>
</div>
<script src="http://www.wowhead.com/widgets/power.js"></script>
<script type="text/javascript">initTabs();</script>
</body>
</html>
END
}

sub textBox {
    my $self = shift;
    my $text = shift;
    my $title = shift;
    
    my $TABLE;
    $TABLE .= "<table cellspacing=\"0\" class=\"text\">";
    $TABLE .= "<tr><th>$title</th></tr>" if $title;
    $TABLE .= "<tr><td>$text</td></tr>" if $text;
    $TABLE .= "</table>";
}

sub vertBox {
    my $self = shift;
    my $title = shift;
    
    my $TABLE;
    $TABLE .= "<table cellspacing=\"0\" class=\"text\">";
    $TABLE .= "<tr><th colspan=\"2\">$title</th></tr>" if $title;
    
    for( my $row = 0; $row < (@_ - 1) ; $row += 2 ) {
        $TABLE .= "<tr><td class=\"vh\">" . $_[$row] . "</td><td>" . $_[$row + 1] . "</td></tr>";
    }
    
    $TABLE .= "</table>";
}

sub jsTab {
    my $self = shift;
    my $section = shift;
    $section = $self->tameText($section);
    return <<END;
<script type="text/javascript">
toggleTab('$section');
</script>   

END
}

sub tameText {
    my $self = shift;
    my $text = shift;
    
    my $tamed = HTML::Entities::encode_entities(lc $text);
    $tamed =~ s/[^\w]/_/g;
    
    return $tamed;
}

sub actorLink {
    my $self = shift;
    my $id = shift || 0;
    my $single = shift;
    my $tab = shift;
    
    $single = 0 if $self->{collapse};
    my $name = $self->{ext}{Index}->actorname($id);
    my $color = $self->{raid}{$id} && $self->{raid}{$id}{class};
    
    #$tab = $tab ? "#" . $self->tameText($tab) : "";
    $tab = "";
    $name ||= "";
    $color ||= "Mob";
    $color =~ s/\s//g;
    
    if( $id || (defined $id && $id eq "0") ) {
        my $group = $self->{grouper}->group($id);
        if( $group && !$single ) {
            return sprintf 
                "<a href=\"group_%s.html%s\" class=\"actor color%s\">%s</a>", 
                $self->tameText($self->{grouper}->captain($group)), 
                $tab,
                $color, 
                HTML::Entities::encode_entities($name);
        } else {
            return sprintf 
                "<a href=\"actor_%s.html%s\" class=\"actor color%s\">%s%s</a>", 
                $self->tameText($id), 
                $tab,
                $color, 
                HTML::Entities::encode_entities($name), 
                ( $group && $single ? " #" . $self->{grouper}->number($id) : "" );
        }
    } else {
        return HTML::Entities::encode_entities($name);
    }
}

sub spellLink {
    my $self = shift;
    my $id = shift;
    my $tab = shift;
    
    my ($name, $rank) = $self->{ext}{Index}->spellname($id);
    $tab = $tab ? "#" . $self->tameText($tab) : "";

    if( $id && $id =~ /^[0-9]+$/ ) {
        return sprintf 
            "<a href=\"spell_%s.html%s\" rel=\"spell=%s\" class=\"spell\">%s</a>%s", 
            $id, 
            $tab,
            $id, 
            HTML::Entities::encode_entities($name),
            $rank ? " ($rank)" : "";
    } elsif( $id ) {
        return sprintf 
            "<a href=\"spell_%s.html%s\" class=\"spell\">%s</a>", 
            $id, 
            $tab,
            HTML::Entities::encode_entities($name);
    } else {
        return HTML::Entities::encode_entities($name);
    }
}

sub tip {
    my ($self, $short, $long) = @_;
    
    my $id = ++ $self->{tid};
    
    if( $long ) {
        $long =~ s/"/&quot;/g;
        return sprintf '<span id="tip%d" class="tip" title="%s">%s</span>', $id, $long, $short;
    } else {
        return $short || "";
    }
}

sub _commify {
    shift;
    local($_) = shift;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}

1;
