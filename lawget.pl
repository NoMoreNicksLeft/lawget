#!/usr/bin/perl
use strict;

# Our includes.
use WWW::Mechanize;
use File::Path;
use Config::JSON;
use YAML qw'LoadFile';
use Getopt::Long;
use Text::Wrap;

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
menu('United States');

print "";
exit;

#menu_world();



eval {
    require US::Texas::TAC;
    US::Texas::TAC->configure($config);
} ;
if($@) { print "error or something"; }

#US::Texas::TAC::download('http://texreg.sos.state.tx.us/public/readtac$ext.viewtac', (1));

US::Texas::TAC::compile((1));


################################################################################
################################# Subroutines ##################################
################################################################################

sub menu {
    my ($menu_name) = @_;

    # Let's make sure this is always passed a menu name.
    if (!exists $menu_config->{$menu_name}) {
        print "\nWARNING: The menu.yaml file may be broken, returning to the top.\n";
        menu("World");
    }

    # This file was passed a label of the menu object to retrieve.
    my $menu = $menu_config->{$menu_name};

    # Let's just keep track of which index is which here.
    my %options;

    # Let's do a newline. Just because.
    print "\n";

    # We need to print the m-heading if it exists (might not early in the tree).
    print $menu->{'m-heading'} . "\n" if exists $menu->{'m-heading'};
    # The materials menus...
    my $a = 1;
    foreach my $material (@{$menu->{'materials'}}) {
        print "  [$a] $material\n";
        $options{$a} = $material;
        $a++;
    }
    # We need to print the s-heading if it exists.
    print $menu->{'s-heading'} . "\n" if exists $menu->{'s-heading'};
    # The materials menus...
    $a = $menu->{'s-start'} if exists $menu->{'s-start'};
    foreach my $subdivision (@{$menu->{'subdivisions'}}) {
        print "  [$a] $subdivision\n";
        $options{$a} = $subdivision;
        $a++;
    }

    # We'll follow up with a question.
    my $default = $menu->{'default'} || "";
    print "\n" . $menu->{'question'} . " [$default] " if exists $menu->{'question'};

    # Wait for their answer...
    my $selection = <>;
    chomp($selection);

    if    ($selection ~~ ["quit", "q", "exit"]) { exit; }
    elsif ($selection ~~ ["top", "start"])      { menu("World"); }
    elsif (exists $options{$selection})         { menu($options{$selection}); }
    # elsif 
    #print Dumper($menu);

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
