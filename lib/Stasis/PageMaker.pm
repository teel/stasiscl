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
use Carp;

sub new {
    my $class = shift;
    bless {}, $class;
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

# tableHeader( @header_rows )
sub tableHeader {
    my $self = shift;
    
    my $result;
    
    $result .= "<tr>";
    
    foreach my $col (@_) {
        my $style_text = "";
        if( $col =~ /^R-/ ) {
            $style_text = "text-align: right; ";
        }
        
        if( $col =~ /-W$/ ) {
            $style_text = "white-space: normal; width: 300px;";
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
    $params{name} ||= "";
    
    if( $params{type} eq "slave" ) {
        $result .= sprintf "<tr class=\"sectionSlave\" name=\"section_%s\">", $params{name}, $params{name};
    } elsif( $params{type} eq "master" ) {
        $result .= sprintf "<tr class=\"sectionMaster\">", $params{name};
    } else {
        $result .= sprintf "<tr class=\"section\">", $params{name};
    }
    
    my $firstflag;
    my $first;
    
    foreach my $col (@{$params{header}}) {
        if( !$firstflag ) {
            $first = " class=\"first\"" ;
        } else {
            $first = "";
        }
        
        my $align = "";
        if( $col =~ /^R-/ ) {
            $align = "text-align: right; ";
        }
        
        if( $col =~ /-W$/ ) {
            $align = "white-space: normal; width: 300px;";
        }
        
        if( $align ) {
            $align = " style=\"${align}\"";
        }
        
        my $ncol = $col;
        $ncol =~ s/^R-//;
        $ncol =~ s/-W$//;
        
        if( $col =~ /^\s+$/ && $params{data}{$col} ) {
            $params{data}{$col} = sprintf "<div style=\"background-color: #339933; width:%dpx\">&nbsp;</span>", $params{data}{$col};
        }
        
        if( !$firstflag && $params{type} eq "master" ) {
            # This is the first one (flag hasn't been set yet)
            $result .= sprintf "<td${first}${align}>(<a class=\"toggle\" id=\"a_section_%s\" href=\"javascript:toggleTableSection('%s');\">-</a>) %s</td>", $params{name}, $params{name}, $params{data}{$col};
        } else {
            if( $params{data}{$col} ) {
                $result .= sprintf "<td${first}${align}>%s</td>", $params{data}{$col};
            } else {
                $result .= "<td${first}${align}>&nbsp;</td>";
            }
        }
        
        $firstflag = 1;
    }
    
    $result .= "</tr>";
}

# pageHeader( $title )
sub pageHeader {
    my $self = shift;
    my $boss = shift;
    my $start = shift;
    
    # Default vars
    $boss ||= "Page";
    
    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime( $start );
    #my $starttxt = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    my $starttxt = asctime localtime $start;
    
    return <<END;
<html>
<head>
<title>$boss</title>
<link rel="stylesheet" type="text/css" href="../extras/sws.css" />
<script type="text/javascript" src="../extras/sws.js"></script>
</head>
<body>
<div class="top">
<h2>$boss: $starttxt</h2>
<b><a href="index.html#damage">Damage</a> &ndash; <a href="index.html#healing">Healing</a> &ndash; <a href="index.html#actors">Raid &amp; Mobs</a></b>
</div>
END
}

# pageFooter()
sub pageFooter {
    my $self = shift;
    my $timestr = asctime localtime;
    
    return <<END;
<p class="footer">Generated on $timestr</p>
<p class="footer">stasiscl available at <a href="http://code.google.com/p/stasiscl/">http://code.google.com/p/stasiscl/</a></p>
</div>
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

sub jsClose {
    my $self = shift;
    my $section = shift;
    return <<END;
<script type="text/javascript">
toggleTableSection('$section');
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
    my $id = shift;
    my $name = shift;
    my $color = shift;
    
    $name ||= "";
    $color ||= "464646";
    
    if( $id ) {
        return sprintf "<a href=\"actor_%s.html\" class=\"actor\" style=\"color: #%s\">%s</a>", $self->tameText($id), $color, HTML::Entities::encode_entities($name);
    } else {
        return HTML::Entities::encode_entities($name);
    }
}

sub spellLink {
    my $self = shift;
    my $id = shift;
    my $name = shift;
    
    $name ||= "";
    
    if( $id && $id =~ /^[0-9]+$/ ) {
        return sprintf "<a href=\"http://www.wowhead.com/?spell=%s\" target=\"swswh_%s\" class=\"spell\">%s <span> wh &#187;</span></a>", $id, $id, HTML::Entities::encode_entities($name);
    } else {
        return HTML::Entities::encode_entities($name);
    }
}

sub classColor {
    my $self = shift;
    my $class = shift;
    
    my %colors = (
            "Warrior" => "b06515",
            "Druid" => "e26f09",
            "Rogue" => "9e9300",
            "Mage" => "0083b2",
            "Warlock" => "6039d6",
            "Hunter" => "639918",
            "Priest" => "898989",
            "Paladin" => "f53589",
            "Shaman" => "00806c",
        );
    
    return $class && $colors{$class} ? $colors{$class} : "464646";
}

1;
