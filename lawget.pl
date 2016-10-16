#!/usr/bin/perl
use strict;

# Our includes.
use WWW::Mechanize;
use File::Path;

# We have some custom modules for this project that don't really belong on CPAN or in the standard locations.
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lawget/lib';

use US::Texas::TAC;


#US::Texas::TAC::download('http://texreg.sos.state.tx.us/public/readtac$ext.viewtac', (4, 7));

US::Texas::TAC::compile((1));