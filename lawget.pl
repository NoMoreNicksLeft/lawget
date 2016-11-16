#!/usr/bin/perl
use strict;
use warnings;

# Our includes.
use WWW::Mechanize;
use File::Path;
use File::Copy;
use Config::JSON;
use YAML qw'LoadFile DumpFile';
use Getopt::Long;
use Text::Wrap;
use Term::ReadKey;
use Module::Load;
use Data::Diver qw'DiveRef';
use List::MoreUtils qw(uniq);
use Data::Dumper;

# We have some custom modules for this project that don't really belong on CPAN or in the standard locations.
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lawget/lib';

# Turn off the smartmatch warning.
no warnings 'experimental::smartmatch';

# Set the text wrap up...
my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
$Text::Wrap::columns = $wchar;

# Load up the config file.
my $app_config = LoadFile("config.yaml");
# Load up the menu file (don't want to do it in menu(), just bad.)
my $menu_config = LoadFile("menu.yaml");

# Check for options. If none, assume interactive mode.
if (@ARGV > 0) { print "got arguments\n"; exit; }

############################## Command-line Mode ###############################

############################### Interactive Mode ###############################

# Let's give the user some sort of hello message.
system("clear");
print "\nWelcome to lawget.\n\n";
my $banner = "You can download statutory code, administrative code, law reporters, treaties, etc from a number of " .
             "sources. Type 'quit' (without quotes) at any time to exit.";
print wrap('', '', $banner);

# Sending them into the endless polling loop!
while (my $module = menu('United States')) {
    # Load up the module. Should only load once, even if called many times.
    load $module;
    # Configure is running every time, not sure if that's bad or not.
    $module->configure($app_config);

    # We need to call the module's menu() method, and generate a menu from it.
    # Should return parameters to run download() and compile() with.
    my ($format, @materials) = $module->menu();
    
    # Want to rename/move these files? Ask before starting long process.
    my $default_destination = DiveRef($app_config, ($module->you_are_here, 'default_destination')) || "";
    print "\nWhere should the materials be saved? [$$default_destination] ";
    my $destination;
    chomp($destination = <>);
    $destination ||= $$default_destination;
    File::Path::make_path($destination);
    # Check here that it can actually be created, if not, ask again.

    # Make this the new default.
    $$default_destination = $destination;

    my $default_rename = DiveRef($app_config, ($module->you_are_here, 'default_rename')) || "";
    print "\nDo you want to rename the materials? [$$default_rename] ";
    my $rename;
    chomp($rename = <>);
    $rename ||= $$default_rename;
    # Is there any way to check that their sprintf expression is good? If we wait, we can't warn,
    # will just have to fail out.

    # Make this the new default.
    $$default_rename = $rename;

    # Let's write out the configs with new defaults.
    DumpFile("config.yaml", $app_config);

    # Some materials only download junk files, that are virtually useless
    # until compiled. Others are usable as is.
    my (@downloaded) = $module->download($destination, $rename, @materials);

    # Depending on the format desired, may need to do some work.
    my @compiled;
    my @ready_files;
    if    ($format ne 'original') {
        # Will need to be compiled to html, regardless of format.
        (@compiled) = $module->download(@materials);
        if    ($format eq 'html') {
            # The ready files is an identical list to @compiled.
            @ready_files = @compiled;
        }
        elsif ($format eq 'pdf') {
            # Need to convert the html files to pdf. Enter wkhtmltopdf.

        }
    }
    # If original files, no need to recompile. May or may not be on offer.
    else {
        @ready_files = @downloaded;
    }

}

exit;

################################################################################
################################# Subroutines ##################################
################################################################################

sub menu {
    my ($menu_name, $start_letter) = @_;

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

    # Sometimes we don't know what materials exist until we look them up.
    if (exists $menu->{'dynamic_materials'}) {
        my $module = $menu->{'dynamic_materials'};
        # Load up the module that can check what materials are available
        load $module;
        $module->configure($app_config);
        # Grab them
        $module->materials($menu_name, \$menu_config);
        # Now we need to nuke dynamic_materials from the menu object.

    }
    
    # We need to print the m-heading if it exists (might not early in the tree).
    print $menu->{'m-heading'} . "\n" if exists $menu->{'m-heading'};

    # The hard-coded materials menus...
    my $i = 1;
    foreach my $material (@{$menu->{'materials'}}) {
        if (ref($material) eq "HASH") {
            $options{$i}{'type'} = 'module';
            $options{$i}{'name'} = $material->{'module'};
            print "  [$i] " . $material->{'label'} . "\n"; 
        }
        $i++;
    }
    # We need to print the s-heading if it exists.
    print $menu->{'s-heading'} . "\n" if exists $menu->{'s-heading'};

    # Sometimes the list of subdivisions available can be determined dynamically.
    my $module_argument = "";
    $module_argument = $menu->{'argument'} if exists $menu->{'argument'};
    foreach my $module (@{$menu->{'dynamic'}}) {
        load $module;
        $module->configure($app_config);
        $module->subdivisions($module_argument, \$menu_config);
    }

    # If there are more than n subdivisions, we'll want to make this a little
    # easier to browse.
    if (scalar @{$menu->{'subdivisions'}} > 55 && !$start_letter) {
        #print "the length is ", scalar @{$menu->{'subdivisions'}}, "\n";
        my @alphabet;
        foreach my $label (@{$menu->{'subdivisions'}}) {
            if (ref($label) eq "HASH") { 
                push(@alphabet, substr($label->{'label'}, 0, 1));
            }
            else {
                push(@alphabet, substr($label, 0, 1));
            }
        }
        @alphabet = uniq(@alphabet);
        $i = 10;
        foreach my $letter (@alphabet) {
            $options{$i}{'type'} = 'letter';
            $options{$i}{'id'} = $letter;
            print "  [$i] $letter\n";
            $i++;
        }
    }
    elsif (scalar @{$menu->{'subdivisions'}} > 55 && $start_letter) {
        # The subdivision menus...
        $i = 10;
        my @slice = grep { substr($_->{'label'}, 0, 1) eq $start_letter } @{$menu->{'subdivisions'}};
        my @sorted_slice = sort {$a->{'label'} cmp $b->{'label'}} @slice;

        foreach my $subdivision (@sorted_slice) {
            # Sometimes we have to have this value be a hash instead of scalar...
            if (ref($subdivision) eq "HASH") { 
                $options{$i}{'type'} = 'menu';
                $options{$i}{'id'} = $subdivision->{'id'};
                print "  [$i] " . $subdivision->{'label'} . "\n";
            }
            else {
                $options{$i}{'type'} = 'menu';
                $options{$i}{'id'} = $subdivision;
                print "  [$i] $subdivision\n";
            }
            $i++;
        }
    }
    else {
        # The subdivision menus...
        $i = $menu->{'s-start'} if exists $menu->{'s-start'};
        foreach my $subdivision (@{$menu->{'subdivisions'}}) {
            # Sometimes we have to have this value be a hash instead of scalar...
            if (ref($subdivision) eq "HASH") { 
                $options{$i}{'type'} = 'menu';
                $options{$i}{'id'} = $subdivision->{'id'};
                print "  [$i] " . $subdivision->{'label'} . "\n";
            }
            else {
                $options{$i}{'type'} = 'menu';
                $options{$i}{'id'} = $subdivision;
                print "  [$i] $subdivision\n";
            }
            $i++;
        }
    }

    # We'll follow up with a question.
    my $default = $menu->{'default'} || "";
    print "\n" . $menu->{'question'} . " [$default] " if exists $menu->{'question'};

    # Wait for their answer...
    my $selection = <>;
    chomp($selection);

    if    ($selection =~ m/^\s*(quit|q|exit)\s*$/)   { exit; }
    elsif ($selection =~ m/^\s*(top|start)\s*$/)     { menu("World"); }
    elsif ($options{$selection}{'type'} eq 'letter') { menu($menu_name, $options{$selection}->{'id'}); }
    elsif (exists $options{$selection}->{'id'})      { menu($options{$selection}->{'id'}); }
    elsif (exists $options{$selection}->{'name'})    { return $options{$selection}->{'name'}; }
    else { ; }

}

################################################################################
################################################################################
################################################################################
