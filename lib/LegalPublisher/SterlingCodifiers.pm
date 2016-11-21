package LegalPublisher::SterlingCodifiers;
use strict;
use warnings;
use experimental 'smartmatch';
use open ":encoding(utf8)";

our $VERSION = 0.01;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(subdivisions);

################################################################################
################################# Dependencies #################################
################################################################################

use WWW::Mechanize;
use File::Path;
use Term::ProgressBar;
use File::Copy qw(copy);
use File::Slurp;
use Lingua::EN::Titlecase;
use HTML::Manipulator::Document;
use Text::Wrap;
use List::MoreUtils qw(uniq);
use Data::Dumper;

################################################################################
################################### Globals ####################################
################################################################################

our $config;
our %subdivisions_tripwire;
our %subdivision_menu;
my %menu_list = ('empty' => 'true');
my $build_root = "build/us/texas/tac";
my $template_root = "templates/us/texas/tac";
my %size_estimate = ( 1  => 3875,
                      4  => 4000,
                      7  => 4000,
                      10 => 4000,
                      13 => 4000,
                      16 => 4000,
                      19 => 4000,
                      22 => 4000,
                      25 => 4000,
                      28 => 4000,
                      30 => 4000,
                      31 => 4000,
                      34 => 4000,
                      37 => 4000,
                      40 => 4000,
                      43 => 4000,
                    );

################################################################################
############################### Public functions ###############################
################################################################################

sub configure {
    my ($package, $z) = @_;
    $config = $z;
}

sub languages {
    return(['eng']);
}

sub subdivisions {
    my ($package, $filter, $menu_config) = @_;

    $filter = lc($filter);

    # No need to run this a second time.
    if (exists $subdivisions_tripwire{$filter}) { return 0; }

    my $subdivisions_url = $config->{'legal publisher'}->{'sterling codifers'}->{'origin'};

    # We need a robot.
    my $mech = WWW::Mechanize->new();
    $mech->get("http://www.sterlingcodifiers.com/");

    # Some little fancy svg map with form fields to select and return the list.
    $mech->post($subdivisions_url, {'state' => $filter});

    my $page = $mech->content();
    while ($page =~ /<option value="(.+?)">(.+?)<\/option>/g) {
        my ($url, $municipality) = ($1, $2);

        $municipality = Lingua::EN::Titlecase->new($municipality)->title;
        my $mid = $municipality; $mid =~ s/[ -'()]/_/g;

        # If the subdivs key doesn't exist yet, it will bitch that "not an array reference",
        # so we'll make it an empty array.
        if (!exists $$menu_config->{"us_${filter}_subdivisions"}->{'subdivisions'}) {
            $$menu_config->{"us_${filter}_subdivisions"}->{'subdivisions'} = [];
        }
        # Let's check to see if it's already in there.
        if (!grep {$_->{'label'} eq $municipality} @{$$menu_config->{"us_${filter}_subdivisions"}->{'subdivisions'}}) {
            push($$menu_config->{"us_${filter}_subdivisions"}->{'subdivisions'}, {'label' => $municipality, 'id' => "us_${filter}_" . lc($mid) });
            $$menu_config->{"us_${filter}_" . lc($mid)} = {'dynamic_materials' => 'LegalPublisher::SterlingCodifiers', 'origin' => $url, 'label' => "$municipality, ".uc($filter)};
        }
    }

    # Set the tripwire, so we can skip this if called again.
    $subdivisions_tripwire{$filter} = 1;
}

sub materials {
    my ($package, $municipality, $menu_config) = @_;

    my $municipality_url = $$menu_config->{$municipality}->{'origin'};

    # We need the materials node to be an array.
    $$menu_config->{$municipality}->{'materials'} = [];

    # We'll also need the m-heading, question
    $$menu_config->{$municipality}->{'m-heading'} = "The following materials are available for " .
                                                    $$menu_config->{$municipality}->{'label'} . ":";
    $$menu_config->{$municipality}->{'question'} = "Which option would you like to browse?";

    # We need a robot.
    my $mech = WWW::Mechanize->new();
    $mech->get($municipality_url);

    # Now we need to hit the left sidepanel, which lists all the goodies.
    $mech->follow_link(name => 'leftframe');
    my $page = $mech->content();

    # Loop through and try to find evidence of: charter, code of ordinances, other code
    my %parts_already_there;
    while($page =~ /a\.add\(\d+, \d+, '(.+?)',/g) {
        my $part = $1;
        # The string "charter" is enough to convince me that's available for download.
        if ($part =~ /charter/i) {
            # If it shows up twice, we don't want to include it twice.
            if (!exists $$menu_config->{$municipality}->{'materials'}->[0]->{'label'} ||
                $$menu_config->{$municipality}->{'materials'}->[0]->{'label'} ne 'Charter') {
                unshift($$menu_config->{$municipality}->{'materials'}, {'label' => 'Charter', 'module' => $package});
            }
        }
        elsif ($part =~ /(town|city) code/i && !exists $parts_already_there{'code'}) {
            $parts_already_there{'code'} = 1;
            # Whatever they call the code of ordinances, we'll standardize.
            push($$menu_config->{$municipality}->{'materials'}, {'label' => 'Municipal Code', 'module' => $package});
        }
        elsif ($part =~ /ordinances pending/i && !exists $parts_already_there{'pending'}) {
            $parts_already_there{'pending'} = 1;
            # Also the potential for pending ordinance. 
            push($$menu_config->{$municipality}->{'materials'}, {'label' => 'Pending Ordinances', 'module' => $package});
        }

        
    }

    delete $$menu_config->{$municipality}->{'dynamic_materials'};

}


sub menu {
    #my $scotus_url = $config->{'north america'}->{'us'}->{'supreme court'}->{'origin'};

    # The user might return to this menu 3 or 4 times, no need to hammer it
    # every time. 
    if (exists ($menu_list{'empty'}) && $menu_list{'empty'} eq 'true') {
        # We'll grab the TAC page, regex out the urls we need, and return those.
        my $mech = WWW::Mechanize->new();
        $mech->get($scotus_url);

        # We're going to loop through the (title) links on the page.
        my $page = $mech->content();
        while ($page =~ /href="boundvolumes\/(\d{3})bv.pdf.+?>(Volume \d{3})&nbsp;/sg) {
            $menu_list{$1} = Lingua::EN::Titlecase->new($2);
        }
        delete $menu_list{'empty'};
    }

    print "\n"; 
    print wrap('', '', "The United States Reports comprises multiple titles. ");
    print "\n"; 
    print wrap('', '', "You may answer with 'all', a comma-separated list of numbers, a range (1-9), or both:\n");          

    # Let's look up the widest key to make this look pretty.
    my $option_width = 0;
    foreach my $key (keys %menu_list) { 
        if (length($key) > $option_width) { $option_width = length($key); } 
    }

    foreach my $option (sort {$a <=> $b} keys %menu_list) {
        print "  [$option] " . (" " x ($option_width - length($option))) . $menu_list{$option} . "\n";
    }


}

################################################################################
################################################################################
################################################################################

1;