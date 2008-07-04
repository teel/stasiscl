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
    my %params = @_;
    
    $params{id} = 0;
    bless \%params, $class;
}

sub tabBar {
    my $self = shift;
    
    my $BAR;
    $BAR .= "<div class=\"tabContainer\">";
    $BAR .= "<div class=\"tabBar\">";
    
    foreach my $tab (@_) {
        $BAR .= sprintf "<a href=\"javascript:toggleTab('%s');\" id=\"tablink_%s\" class=\"tabLink\">%s</a>", $self->tameText($tab), $self->tameText($tab), $tab;
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
    
    # Override 'name'
    $params{name} = $params{type} eq "master" ? ++$self->{id} : $self->{id};
    
    if( $params{type} eq "slave" ) {
        $result .= sprintf "<tr class=\"sectionSlave\" name=\"s%s\">", $params{name}, $params{name};
    } elsif( $params{type} eq "master" ) {
        $result .= sprintf "<tr class=\"sectionMaster\">";
    } else {
        $result .= sprintf "<tr class=\"section\">";
    }
    
    my $firstflag;
    
    foreach my $col (@{$params{header}}) {
        my @class;
        my $align = "";
        
        if( !$firstflag ) {
            push @class, "f";
        }
        
        my $r;
        if( $col =~ /^R-/ ) {
            $r = 1;
            push @class, "r";
        }
        
        if( $col =~ /-W$/ ) {
            push @class, "w";
        }
        
        if( @class ) {
            $align = " class=\"" . join( " ", @class ) . "\"";
        }
        
        my $ncol = $col;
        $ncol =~ s/^R-//;
        $ncol =~ s/-W$//;
        
        if( $col =~ /^\s+$/ && $params{data}{$col} ) {
            $params{data}{$col} = sprintf "<div class=\"chartbar\" style=\"width:%dpx\">&nbsp;</span>", $params{data}{$col};
        }
        
        if( !$firstflag && $params{type} eq "master" ) {
            # This is the first one (flag hasn't been set yet)
            $result .= sprintf "<td${align}>(<a class=\"toggle\" id=\"as%s\" href=\"javascript:toggleTableSection(%s);\">+</a>) %s</td>", $params{name}, $params{name}, $r ? $self->_commify($params{data}{$col}) : $params{data}{$col};
        } else {
            if( $params{data}{$col} ) {
                $result .= sprintf "<td${align}>%s</td>", $r ? $self->_commify($params{data}{$col}) : $params{data}{$col};
            } else {
                $result .= "<td${align}>&nbsp;</td>";
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
    my $title = shift;
    my $start = shift;
    
    # Default vars
    $boss ||= "Page";
    $title ||= "";
    $title = $title ? "$boss : $title" : $boss;
    
    # Reset table row ID
    $self->{id} = 0;
    
    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime( $start );
    #my $starttxt = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    my $starttxt = asctime localtime $start;
    
    return <<END;
<html>
<head>
<title>$title</title>
<link rel="stylesheet" type="text/css" href="../extras/sws2.css" />
<script type="text/javascript" src="../extras/sws.js"></script>
<script src="http://www.wowhead.com/widgets/power.js"></script>
</head>
<body>
<div class="swsmaster">
<div class="top">
<h2>$boss: $starttxt</h2>
<b><a href="index.html">Damage Out</a> &ndash; <a href="index.html#damagein">Damage In</a> &ndash; <a href="index.html#healing">Healing</a> &ndash; <a href="index.html#deaths">Deaths</a> &ndash; <a href="index.html#actors">Raid &amp; Mobs</a></b>
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

sub jsClose {
    my $self = shift;
    my $section = shift;
    
    # Override $section
    $section = $self->{id};
    
    return <<END;
<script type="text/javascript">
toggleTableSection('$section');
</script>   

END
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
    my $id = shift;
    my $single = shift;
    my $name = $self->{ext}{Index}->actorname($id);
    my $color = $self->{raid}{$id} && $self->{raid}{$id}{class};
    
    $name ||= "";
    $color ||= "Mob";
    
    if( $id || (defined $id && $id eq "0") ) {
        my $group = $self->{grouper}->group($id);
        if( $group && !$single ) {
            return sprintf "<a href=\"group_%s.html\" class=\"actor color%s\">%s</a>", $self->tameText($self->{grouper}->captain($group)), $color, HTML::Entities::encode_entities($name);
        } else {
            return sprintf "<a href=\"actor_%s.html\" class=\"actor color%s\">%s%s</a>", $self->tameText($id), $color, HTML::Entities::encode_entities($name), ( $group && $single ? " #" . $self->{grouper}->number($id) : "" );
        }
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
        return sprintf "<a href=\"spell_%s.html\" rel=\"spell=%s\" class=\"spell\">%s</a>", $id, $id, HTML::Entities::encode_entities($name);
        #return sprintf "<a href=\"http://www.wowhead.com/?spell=%s\" target=\"swswh_%s\" class=\"spell\">%s</a>", $id, $id, HTML::Entities::encode_entities($name);
    } else {
        return HTML::Entities::encode_entities($name);
    }
}

sub _commify {
    shift;
    local($_) = shift;
    return $_ unless /^\d+$/;
    1 while s/^(-?\d+)(\d{3})/$1,$2/;
    return $_;
}

1;
