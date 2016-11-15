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
            $$menu_config->{"us_${filter}_" . lc($mid)} = "";
        }
    }

    # Set the tripwire, so we can skip this if called again.
    $subdivisions_tripwire{$filter} = 1;
}

################################################################################
################################################################################
################################################################################

1;