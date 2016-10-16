package US::Texas::TAC;
use strict;
use warnings;
use experimental 'smartmatch';
use open ":encoding(utf8)";

our $VERSION = 0.01;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(download compile);

################################################################################
################################# Dependencies #################################
################################################################################

use WWW::Mechanize;
use File::Path;
use Term::ProgressBar;
use File::Copy qw(copy);
use File::Slurp;
use Lingua::EN::Titlecase;

################################################################################
################################### Globals ####################################
################################################################################

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

sub download {
    # We have a few arguments for this.
    my ($tac_url, @titles) = @_;

    my $title_data = get_title_urls($tac_url, @titles);

    # We need a robot.
    my $mech = WWW::Mechanize->new();

    # Now we'll loop through each title...
    foreach my $title_number (keys %$title_data) {
        # We need to prepare a directory to store the html files. 
        File::Path::make_path("$build_root/$title_number");
        # And one for supplementary documents.
        File::Path::make_path("$build_root/$title_number/includes");

        # $a is for filenames, but I also need one that incs for the progress even 
        # inside inner loops.
        my $a = 1; my $z = 1;

        # This will take awhile, let's provide some feedback.
        print "Downloading Title $title_number ...\n";
        my $progress = Term::ProgressBar->new({count => $size_estimate{$title_number}, ETA => 'linear', remove => 1});
        $progress->minor(0);
        $progress->max_update_rate(1);

        # Grab the initial page.
        my $title_url = $$title_data{$title_number};
        $mech->get($title_url);
        $mech->save_content("$build_root/$title_number/". sprintf("%06d", $a) . ".html", binmode => ':utf8');

        # This page will have a "next" link until we get to the end.
        # It may also have a "cont'd" link, these also need to be followed.
        while (my $next_rule_link = $mech->find_link(name_regex => qr/^Next Rule$/)) {
            $a++; $z++;
            # The first title has about 4000, and I originally put 5 digits, but
            # after thinking about it a moment, I'm just going to make this 6. 
            # Not saving anything if I only use 5, and can't make any assumptions.
            my $fullfilepath = "$build_root/$title_number/" . sprintf("%06d", $a);
            $mech->get($next_rule_link);
            $mech->save_content($fullfilepath.".html", binmode => ':utf8');
            $progress->update($z);

            # We'll grab any of the "continued pages" with this. We need the "it"
            # because we will need to use a new robot if they're found.
            my $b = "aa";
            if ($mech->find_link(name_regex => qr/^Continued$/)) {
                # Don't want to pollute the higher level robot.
                my $mech2 = $mech->clone();
                while (my $continued_link = $mech2->find_link(name_regex => qr/^Continued$/)) {
                    # These can continue for quite a few pages, I've seen 8 so far.
                    $mech2->get($continued_link);
                    $mech2->save_content($fullfilepath."$b.html", binmode => ':utf8');
                    $z++;
                    $progress->update($z);
                    $b++;
                }
            }

            # There are also an irritating number of linked supplementary documents.
            my $mech2 = $mech->clone();
            foreach my $doc_link ($mech->find_all_links(url_regex => qr/fids/)) {
                my ($fn) = $doc_link->url() =~ /.+\/(.+)$/;
                $mech2->get($doc_link);
                # The binmode needs to be utf8 for html, but raw for pdfs (and everything else?).
                my $binmode = ($fn =~ /\.html$/ ? ':utf8' : ':raw');
                $mech2->save_content("$build_root/$title_number/includes/$fn", binmode => $binmode);
                $z++;
                $progress->update($z);
            }
        }

        # Let's finish up the progress bar, since we've exited the loop.
        $progress->update($size_estimate{$title_number});
    }
}

sub compile {
    my (@titles) = @_;

    # We might be compiling more than one here.
    foreach my $title_number (@titles) {
        my $work_in_progress = "$build_root/${title_number}wip.html";

        # We'll do a copy for the inital markup.
        copy ("$template_root/open.html", $work_in_progress);

        # We need to look up the list of html files.
        opendir(DIR, "$build_root/$title_number");
        my @source_files = grep(/\.html$/,readdir(DIR));
        closedir(DIR);

        # We also need to convert any pdfs to svg.

        # We need to tack on some javascript to them

        # We need to add some to the htmls too.

        # This will take awhile, let's provide some feedback.
        print "Compiling Title $title_number ...\n";
        my $progress = Term::ProgressBar->new({count => scalar(@source_files), ETA => 'linear', remove => 1});
        $progress->minor(0);
        $progress->max_update_rate(1);

        # Loop through the files...
        my $a = 1;
        open(my $fh, '>>', $work_in_progress);
        foreach my $file (@source_files) {
            # Run it through our grimy little parser and add it to our file.
            my $file_contents = parse_tac_html_file("$build_root/$title_number/$file");
            # Write it out to the work-in-progress file.
            print $fh $file_contents;
            # Don't forget our progress bar.
            $progress->update($a);
            $a++;
        }

        

        close $fh;
    }
}

################################################################################
############################### Private functions ##############################
################################################################################

sub get_title_urls {
    my ($tac_url, @titles) = @_;

    # We'll need a hash to return the data with.
    my %title_data;

    # We'll grab the TAC page, regex out the urls we need, and return those.
    my $mech = WWW::Mechanize->new();
    $mech->get($tac_url);

    # We're going to loop through the (title) links on the page.
    my $page = $mech->content();
    while ($page =~ /HREF="(.+?)" NAME="TITLE">TITLE (\d+)</g) {
        my $title_link = $1;
        my $title_number = $2;

        # Is this title one we actually want to get?
        if (!($title_number ~~ @titles)) { next; }

        # The Title page.
        $mech->get($title_link);
        # The Part page.
        $mech->follow_link(text_regex => qr/^PART \d+/);
        # The Chapter page.
        $mech->follow_link(text_regex => qr/^CHAPTER \d+/);
        # The Subchapter page.
        $mech->follow_link(text_regex => qr/^SUBCHAPTER/);
        # The first rule page, we need to push this onto the array/hash.
        my $rule = $mech->find_link(name_regex => qr/^\xa7/);

        $title_data{$title_number} = $rule->url_abs();
    }

    return \%title_data;
}

sub parse_tac_html_file {
    my ($filepath) = @_;

    # Better than undef $/, we'll just use File::Slurp.
    my $file_contents = read_file($filepath);

    # Need to check here to make sure we even have content. Throw an error?

    # Let's get all the header tag content, and build that portion of the html
    # to return.
    titlea=`perl -ne 'print lc($1) if /NAME="TITLE">(.+?)<\/A><\/TD>/' $file`
    titleb=`perl -ne 'print lc($1) if /NAME="TITLE">.+?<\/A><\/TD><TD>(.+?)<\/font><\/TD>/' $file`
    parta=`perl -ne 'print lc($1) if /NAME="PART">(.+?)<\/A><\/TD>/' $file`
    partb=`perl -ne 'print lc($1) if /NAME="PART">.+?<\/A><\/TD><TD>(.+?)<\/TD>/' $file`
    chapa=`perl -ne 'print lc($1) if /NAME="CHAPTER">(.+?)<\/A><\/TD>/' $file`
    chapb=`perl -ne 'print lc($1) if /NAME="CHAPTER">.+?<\/A><\/TD><TD>(.+?)<\/TD>/' $file`
    suba=`perl -ne 'print lc($1) if /NAME="SUBCHAPTER">(.+?)<\/A><\/TD>/' $file`
    subb=`perl -ne 'print lc($1) if /NAME="SUBCHAPTER">.+?<\/A><\/TD><TD>(.+?)<\/TD>/' $file`
    rulea=`perl -ne 'print lc($1." ".$2) if /<TD WIDTH=\d+>(RULE &sect;)(.+?)<\/TD>/' $file`
    ruleb=`perl -ne 'print $1 if /<TD WIDTH=\d+>.+?<\/TD><TD>(.+?)<\/TD>/' $file`
    sn=`perl -e 'undef $/; $_=<>; print $1 if /<TD>(<B>Source Note:.+?)<\/TD>/s' $file`

    Lingua::EN::Titlecase->new($x)

    my () = 
            $file_contents =~ /NAME="TITLE">(.+?)<.A><.TD><TD>(.+?)<.font>
                               NAME="PART">(.+?)<.A><.TD><TD>(.+?)<.TD>
                               NAME="CHAPTER">(.+?)<.A><.TD><TD>(.+?)<.TD>
                               NAME="SUBCHAPTER">(.+?)<.A><.TD><TD>(.+?)<.TD>
                              /sx;


    # Next, let's snip out the actual content.
    my ($parsed_markup) = $file_contents =~ /<TABLE\s*>\n<TR>\n<TD><HR><.TD>\n<.TR>\n<TR>\n<TD>(.+?)<\/TD>/s;

    # Now we're going to discombobulate this, since it's all the worst parts of
    # mid-1990s html and what I'm guessing is some sgml/xml monstrosity. And
    # they have the gall to put an xhtml doctype at the top.

    # Let's get rid of some crud first.
    $parsed_markup =~ s/(<p>|<\/p>|<\?Pub Caret -\d>)//sg;

    # Now we're going to do the nested lists. Starting at the deepest level,
    # working our way up. A pair of regexes for each, first wraps the list
    # with <ol>s, the second wraps the items in <li>s.
    $parsed_markup =~ s/(<si>.+?)(<ni>|<sl>|<cc>|<sp>|<pp>|<ss>|<\/ni>|<\/sl>|<\/cc>|<\/sp>|<\/pp>|<\/ss>|$)/<ol class="darabic">$1<\/si><\/ol>$2/sg; 
    $parsed_markup =~ s/<si>(?:&nbsp;){12}<no>\(-[0-9]+-\)\s*(.+?)\s*(<\/si><\/ol>|(?=<si>))/<li>$1<\/li>$2/sg;

    $parsed_markup =~ s/(<ni>.+?)(<sl>|<cc>|<sp>|<pp>|<ss>|<\/sl>|<\/cc>|<\/sp>|<\/pp>|<\/ss>|$)/<ol class="dalpha">$1<\/ni><\/ol>$2/sg; 
    $parsed_markup =~ s/<ni>(?:&nbsp;){10}<no>\(-[a-z]+-\)\s*(.+?)\s*(<\/ni><\/ol>|(?=<ni>))/<li>$1<\/li>$2/sg;

    $parsed_markup =~ s/(<sl>.+?)(<cc>|<sp>|<pp>|<ss>|<\/cc>|<\/sp>|<\/pp>|<\/ss>|$)/<ol class="uroman">$1<\/sl><\/ol>$2/sg;
    $parsed_markup =~ s/<sl>(?:&nbsp;){8}<no>\([IVXL]+\)\s*(.+?)\s*(<\/sl><\/ol>|(?=<sl>))/<li>$1<\/li>$2/sg;

    $parsed_markup =~ s/(<cc>.+?)(<sp>|<pp>|<ss>|<\/sp>|<\/pp>|<\/ss>|$)/<ol class="roman">$1<\/cc><\/ol>$2/sg; 
    $parsed_markup =~ s/<cc>(?:&nbsp;){6}<no>\([ivxl]+\)\s*(.+?)\s*(<\/cc><\/ol>|(?=<cc>))/<li>$1<\/li>$2/sg;  

    $parsed_markup =~ s/(<sp>.+?)(<pp>|<ss>|<\/pp>|<\/ss>|$)/<ol class="ualpha">$1<\/sp><\/ol>$2/sg; 
    $parsed_markup =~ s/<sp>(?:&nbsp;){4}<no>\([A-Z]+\)\s*(.+?)\s*(<\/sp><\/ol>|(?=<sp>))/<li>$1<\/li>$2/sg; 

    $parsed_markup =~ s/(<pp>.+?)(<ss>|<\/ss>|$)/<ol class="arabic">$1<\/pp><\/ol>$2/sg; 
    $parsed_markup =~ s/<pp>(?:&nbsp;){2}<no>\(\d+\)\s*(.+?)\s*(<\/pp><\/ol>|(?=<pp>))/<li>$1<\/li>$2/sg; 

    $parsed_markup =~ s/(<ss><no>.+?)$/<ol class="alpha">$1<\/ss><\/ol>/sg; 
    $parsed_markup =~ s/<ss><no>\([a-z]+\)\s*(.+?)\s*(<\/ss><\/ol>|(?=<ss>))/<li>$1<\/li>$2/sg;

    # Non-lists sometimes get wrapped in <ss>, no idea why.
    $parsed_markup =~ s/<ss>(.+?)(<\/ss>|$)/$1/sg;
    # Now we need to clean up some some closing tags we missed.
    $parsed_markup =~ s/(<\/ss>|<\/pp>|<\/sp>|<\/cc><\/sl>|<\/ni>|<\/si>)//g;

    # Fix some entities, create others.
    $parsed_markup =~ s/(\. ){3,4}/ &hellip;/g;
    $parsed_markup =~ s/&sect;/&sect;&nbsp;/g;
    $parsed_markup =~ s/--/ &mdash; /g;
    $parsed_markup =~ s/<! &mdash; /<!--/g;
    $parsed_markup =~ s/ &mdash; >/-->/g;

    # Rather than links, let's include supplementary documents inline.
    my $iframes = "";
    ($iframes) = $parsed_markup =~ s/.*?<a href="(\/fids\/)(.+?)\.(html|pdf)">Attached Graphic<\/a>.*?(?=<a|$)/<iframe id="$2" src="temp$1$2.$3"><\/iframe>/sg;
    # We need any pdf document to be an svg instead.
    if ($iframes) { $iframes =~ s/\.pdf"><\/iframe>/.svg"><\/iframe>/sg; }
    # Any wording of "attached graphic" needs to be "see figure".
    # Need to have the title number and rule here.
    $parsed_markup =~ s/<a href="(\/fids\/)(.+?)\.(html|pdf)">Attached Graphic<\/a>/<a href="#$2">See Figure $t TAC &sect;&nbsp;$r<\/a>/sg;
    # Wrap everything in a p tag, tack iframes on at end.
    $parsed_markup =~ s/^(.+)$/      <p class="rule">$1<\/p>$iframes/sg;

    return $parsed_markup;
}

################################################################################
################################################################################
################################################################################

1;