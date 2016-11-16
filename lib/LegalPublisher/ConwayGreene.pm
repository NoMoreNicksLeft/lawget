package LegalPublisher::ConwayGreene;
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
my %state_abbreviations = ( 'Ohio'          => 'oh',
                            'Pennsylvania'  => 'pa',
                            'West Virginia' => 'wv'
                          );
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
    if ($subdivisions_tripwire) { return 0; }

    my $subdivisions_url = $config->{'legal publisher'}->{'conway greene'}->{'origin'};

    # We need a robot.
    my $mech = WWW::Mechanize->new();
    $mech->get($subdivisions_url);

    my $page = $mech->content();
    while ($page =~ /<a href="(.+?)">([A-Za-z].+?), (Ohio|Pennsylvania|West Virginia)<\/a><br>/g) {
        my ($url, $municipality, $state) = ($1, $2, $3);

        $municipality = Lingua::EN::Titlecase->new($municipality)->title;
        my $mid = $municipality; $mid =~ s/[ -'()]/_/g;
        my $st = $state_abbreviations{$state};

        # If the subdivs key doesn't exist yet, it will bitch that "not an array reference",
        # so we'll make it an empty array.
        if (!exists $$menu_config->{"us_${st}_subdivisions"}->{'subdivisions'}) {
            $$menu_config->{"us_${st}_subdivisions"}->{'subdivisions'} = [];
        }
        # Let's check to see if it's already in there.
        if (!grep {$_->{'label'} eq $municipality} @{$$menu_config->{"us_${st}_subdivisions"}->{'subdivisions'}}) {
            push($$menu_config->{"us_${st}_subdivisions"}->{'subdivisions'}, {'label' => $municipality, 'id' => "us_${st}_" . lc($mid) });
            $$menu_config->{"us_${st}_" . lc($mid)} = {'dynamic_materials' => 'LegalPublisher::SterlingCodifiers', 'origin' => $url};
        }
    }

    # Set the tripwire, so we can skip this if called again.
    $subdivisions_tripwire++;
}

sub materials {
    my ($package, $municipality, $menu_config) = @_;

    my $municipality_url = $$menu_config->{$municipality}->{'origin'};

    # We need the materials node to be an array.
    $$menu_config->{'materials'} = [];

    # We need a robot.
    my $mech = WWW::Mechanize->new();
    $mech->get($municipality_url);

    # Now we need to hit the left sidepanel, which lists all the goodies.
    $mech->follow_link(name => 'leftframe');
    my $page = $mech->content();

    # Is there a charter?
    while($page =~ /a\.add\(\d+, \d+, '(.+?)',/g) {
        print "zzz $1\n";
    }

    # Ordinances?

    delete $$menu_config->{$municipality}->{'dynamic_materials'};

}
################################################################################
################################################################################
################################################################################

1;