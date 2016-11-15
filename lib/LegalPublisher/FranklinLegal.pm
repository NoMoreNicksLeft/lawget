package LegalPublisher::FranklinLegal;
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
our $subdivisions_tripwire = 0;
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

    # No need to run this a second time.
    if ($subdivisions_tripwire) { return 0; }

    my $subdivisions_url = $config->{'legal publisher'}->{'franklin legal'}->{'origin'};

    # We need a robot.
    my $mech = WWW::Mechanize->new();
    $mech->get($subdivisions_url);

    my $page = $mech->content();
    while ($page =~ /<option target="_blank" value="(.+?)">(.+?)<\/option>/g) {
        my ($url, $subdivision_name) = ($1, $2);

        # There are some garbage options in the list, we just need to skip if we find those.
        if ($subdivision_name =~ m/^(Select here|All codes|Texas Municipal Law)/) { next; }

        # Most of these are Texas, a few aren't. We'll load them all anyway. If someone
        # skips through and then does Oklahoma, no reason to run this a second time.
        $subdivision_name =~ m/^(.+?)(, [A-Z]{2})?$/;
        my $municipality = Lingua::EN::Titlecase->new($1)->title;
        my $state = $2 || 'TX'; $state = lc(substr $state, -2);
        my $mid = $municipality; $mid =~ s/[ -'()]/_/g;

        # If the subdivs key doesn't exist yet, it will bitch that "not an array reference",
        # so we'll make it an empty array.
        if (!exists $$menu_config->{"us_${state}_subdivisions"}->{'subdivisions'}) {
            $$menu_config->{"us_${state}_subdivisions"}->{'subdivisions'} = [];
        }
        # Let's check to see if it's already in there.
        if (!grep {$_->{'label'} eq $municipality} @{$$menu_config->{"us_${state}_subdivisions"}->{'subdivisions'}}) {
            push($$menu_config->{"us_${state}_subdivisions"}->{'subdivisions'}, {'label' => $municipality, 'id' => "us_${state}_" . lc($mid) });
            $$menu_config->{"us_${state}_" . lc($mid)} = {'dynamic_materials' => 'LegalPublisher::FranklinLegal', 'origin' => $url};
        }
    }

    # Set the tripwire, so we can skip this if called again.
    $subdivisions_tripwire++;
}

sub materials {
    my ($package, $municipality, $menu_config) = @_;

    my $municipality_url = $$menu_config->{$municipality}->{'origin'};

    # We need a robot.
    my $mech = WWW::Mechanize->new();
    $mech->get($municipality_url);

    # Is there a charter?

    # Ordinances?


}

################################################################################
################################################################################
################################################################################

1;