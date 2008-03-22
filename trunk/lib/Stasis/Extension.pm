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

package Stasis::Extension;

use strict;
use warnings;
use Carp;

# Meant to be called statically like:
# Stasis::Extension->factory "Aura" 
sub factory {
    my ($self, $ext) = @_;
    my $class = "Stasis::Extension::$ext";
    
    # Grab the file.
    require "Stasis/Extension/$ext.pm" or return undef;
    
    # Create the object.
    my $obj = $class->new();
    
    # Return it.
    return $obj ? $obj : undef;
}

# Standard constructor.
sub new {
    my $class = shift;
    my %params = @_;
    
    bless {
        params => \%params
    }, $class;
}

# Subclasses may implement this function, which will be called once at
# the start of processing.
sub start {
    return 1;
}

# Subclasses must implement this function, which will be called repeatedly
# Each call will be a log entry from Stasis::Parser
sub process {
    croak "Not implemented.";
}

# Subclasses may implement this function, which will be called once at
# the end of processing.
sub finish {
    return 1;
}

1;
