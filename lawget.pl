#!/usr/bin/perl
use strict;

# Our includes.
use WWW::Mechanize;
use File::Path;
use Config::JSON;
use Getopt::Long;

# We have some custom modules for this project that don't really belong on CPAN or in the standard locations.
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lawget/lib';

# Load up the config file.
my $config = Config::JSON->new("config.json");

# Check for options. If none, assume interactive mode.

# Let's give the user some sort of hello message.
print "\nWelcome to lawget.\n" .
      "You can download statutory code, administrative code, law reporters, treaties,\n" .
      "etc from a number of sources. Type 'quit' (without quotes) at any time to exit.\n\n";

print "The Texas Administrative Code comprises multiple titles (16 as of Oct 18, '16).\n" .
      "The titles numbers are not necessarily sequential due to various factors.\n\n";
print "You may answer with 'all', a comma-separated list of numbers, a range (1-9), or any combination:\n";
print "Which title(s) would you like to download? [all] ";

my $title_list = <> || "0";
chomp($title_list);

print "\nAvilable formats are: pdf, html\n";
print "What document format do you want the titles converted to? [pdf] ";

my $title_format = <> || "pdf";
chomp($title_format);

print "";

#menu_world();



load US::Texas::TAC "test";

#US::Texas::TAC::download('http://texreg.sos.state.tx.us/public/readtac$ext.viewtac', (1));

my $aaa = "prize\n";

US::Texas::TAC::compile((1));


################################################################################
################################# Subroutines ##################################
################################################################################

sub menu_world {
    my ($tac_url, @titles) = @_;

    print "\n"; 
    print "Regions with available materials:\n";
    print "[1] North America\n";
    # print "[2] South America\n";
    # print "[3] Europe\n";
    # print "[4] Mars\n";
    print "\n"; 
    print "Which region of the world would you like to browse? [] ";
    # Get the answer back.

    my $selection = <>;
    chomp($selection);

    # Let's see what they chose.
    if    ($selection == 1)      { menu_north_america(); }
    elsif ($selection eq "quit") { exit; }
    else                    {
        print "Wrong answer! Cut this shit out and give a real one.\n\n";
        menu_world();
    }
    
}

sub menu_north_america {

    print "\n"; 
    print "Countries with available materials:\n";
    print "[1] United States\n";
    # print "[2] Canada\n";
    # print "[3] Mexico\n";
    print "\n"; 
    print "Which country of North America would you like to browse? [] ";

    my $selection = <>;
    chomp($selection);

    # Let's see what they chose.
    if    ($selection == 1)      { menu_united_states(); }
    elsif ($selection eq "quit") { exit; }
    else                    {
        print "Wrong answer! Cut this shit out and give a real one.\n\n";
        menu_north_america();
    }
}

sub menu_united_states {

    print "\n"; 
    print "The following materials are available for United States:\n";
    print "[1] Founding documents\n";
    print "[2] Statutory law\n";
    print "[3] Administrative law\n";
    print "[4] Treaties\n";
    print "\nAdditionally, materials are available for the following subdivisions:\n";
    print "[43] Texas\n";
    print "\n"; 
    print "Which option would you like to browse? [] ";

    my $selection = <>;
    chomp($selection);

    # Let's see what they chose.
    if    ($selection == 1)      { }
    elsif ($selection == 2)      { }
    elsif ($selection == 3)      { }
    elsif ($selection == 43)     { menu_state_of_texas(); }
    elsif ($selection eq "quit") { exit; }
    else                    {
        print "Wrong answer! Cut this shit out and give a real one.\n\n";
        menu_united_states();
    }
}

sub menu_state_of_texas {

    print "\n"; 
    print "The following materials are available for Texas:\n";
    print "[1] Founding documents\n";
    print "[2] Statutory law\n";
    print "[3] Administrative law\n";
    print "\nAdditionally, materials are available for the following subdivisions:\n";
    print "[100] City of Lubbock\n";
    print "\n"; 
    print "Which option would you like to browse? [] ";

    my $selection = <>;
    chomp($selection);

    # Let's see what they chose.
    if    ($selection == 1)      { }
    elsif ($selection == 2)      { }
    elsif ($selection == 3)      { menu_state_of_texas_admin_law(); }
    elsif ($selection == 43)     { }
    elsif ($selection eq "quit") { exit; }
    else                    {
        print "Wrong answer! Cut this shit out and give a real one.\n\n";
        menu_state_of_texas();
    }
}

sub menu_state_of_texas_admin_law {

    print "\n"; 
    print "The Texas Administrative Code comprises multiple titles (16 as of Oct 18, '16).\n" .
          "The titles numbers are not necessarily sequential due to various factors.\n\n";
    print "You may answer with a comma-separated list of numbers, a range (1-9), or both:\n";          
    print "Which title(s) would you like to download? []";

    my $selection = <>;
    chomp($selection);

    # Let's see what they chose.
    if    ($selection == 1)      { }
    elsif ($selection == 2)      { }

}

################################################################################
################################################################################
################################################################################
