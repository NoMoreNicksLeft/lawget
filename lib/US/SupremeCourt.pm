package US::SupremeCourt;
use strict;
use warnings;
use experimental 'smartmatch';
use open ":encoding(utf8)";

our $VERSION = 0.01;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(menu download);

################################################################################
################################# Dependencies #################################
################################################################################

use WWW::Mechanize;
use File::Path;
use Term::ProgressBar;
use Lingua::EN::Titlecase;
use Text::Wrap;
use List::MoreUtils qw(uniq);
use Data::Dumper;

################################################################################
################################### Globals ####################################
################################################################################

our $config;
my %menu_list = ('empty' => 'true');
my $build_root = "build/us/scotus";

################################################################################
############################### Public functions ###############################
################################################################################

sub configure {
    my ($package, $z) = @_;
    $config = $z;
}

sub menu {
    my $scotus_url = $config->{'north america'}->{'us'}->{'supreme court'}->{'origin'};

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
    
    # First question.
    my @materials_array;
    MATERIALS_LOOP: while(1) {
        print "Which title(s) would you like to download? [all] ";

        my $materials;
        chomp($materials = <>);
        $materials = $materials || 'all';

        # Process the answer into an array of integers.
        my @answer = split(/,/, $materials);
        foreach my $answerpart (@answer) {
            $answerpart =~ s/\s//g;
            if ($answerpart !~ m/^(all|\d+|\d+-\d+|q|quit|exit)$/) {
                print "ERROR:   That option ($answerpart) is unavailable.\n";
                # Part of the answer is wrong, somehow. This iteration needs
                # to end immediately, but we need another to ask again.
                undef(@materials_array);
                next MATERIALS_LOOP;
            }
            elsif ($answerpart eq 'all') {
                @materials_array = (keys %menu_list);
            }
            elsif ($answerpart =~ m/^(q|quit|exit)$/) {
                exit;
            }
            elsif ($answerpart =~ m/^\d+$/) {
                push @materials_array, $answerpart;
            }
            elsif ($answerpart =~ m/^(\d+)-(\d+)$/) {
                push @materials_array, $1 .. $2;
            }
        }
        # Deduplicate the array.
        @materials_array = uniq(@materials_array);
        @materials_array = grep /\S/, @materials_array;

        # Now exit the loop.
        last;
    }

    my $format = "original";
    return ($format, @materials_array);
}

sub download {
    # We have a few arguments for this.
    my ($package, @titles) = @_;

    my $scotus_url = $config->{'north america'}->{'us'}->{'supreme court'}->{'origin'};

    my $title_data = get_title_urls($scotus_url, @titles);

    # We need a robot.
    my $mech = WWW::Mechanize->new();

    # This will take awhile, let's provide some feedback.
    print "Downloading United States Reports ...\n";
    my $progress = Term::ProgressBar->new({count => scalar keys %$title_data, ETA => 'linear', remove => 1});
    $progress->minor(0);
    $progress->max_update_rate(1);

    # Now we'll loop through each title...
    my $z = 1;
    foreach my $title_number (sort {$a <=> $b} keys %$title_data) {
        # We need to prepare a directory to store the html files. 
        File::Path::make_path("$build_root");

        # Grab the initial page.
        my $title_url = $$title_data{$title_number};
        $mech->get($title_url);
        my ($fn) = $title_url =~ /.+\/(.+)$/;
        $mech->save_content("$build_root/$fn", binmode => ':raw');

        # Let's finish up the progress bar, since we've exited the loop.
        $progress->update($z);
        $z++;
    }

    return (0);
}

################################################################################
############################### Private functions ##############################
################################################################################

sub get_title_urls {
    my ($url, @titles) = @_;

    # We'll need a hash to return the data with.
    my %title_data;

    # We'll grab the TAC page, regex out the urls we need, and return those.
    my $mech = WWW::Mechanize->new();
    $mech->get($url);

    # We're going to loop through the (title) links on the page.
    foreach my $link ($mech->find_all_links(text_regex => qr/^Volume \d{3}/)) {
        # Can't do capturing in the method above, so we have to go again.
        my ($title_number) = $link->text() =~ m/Volume (\d{3})/;

         # Is this title one we actually want to get?
        if (!($title_number ~~ @titles)) { next; }

        $title_data{$title_number} = $link->url_abs();
    }

    return \%title_data;
}

################################################################################
################################################################################
################################################################################

1;