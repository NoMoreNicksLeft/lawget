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
use HTML::Manipulator::Document;

################################################################################
################################### Globals ####################################
################################################################################

our $config;
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
my $inkscape="/Applications/Inkscape.app/Contents/Resources/bin/inkscape";

################################################################################
############################### Public functions ###############################
################################################################################

sub configure {
    my ($package, $z) = @_;
    $config = $z;
}

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

                    # Supplementary documents are found in continued pages too..
                    my $mech3 = $mech2->clone();
                    foreach my $doc_link ($mech2->find_all_links(text_regex => qr/Attached Graphic/)) {
                        my ($fn) = $doc_link->url() =~ /.+\/(.+)$/;
                        $mech3->get($doc_link);
                        # The binmode needs to be utf8 for html, but raw for pdfs (and everything else?).
                        my $binmode = ($fn =~ /\.html$/ ? ':utf8' : ':raw');
                        $mech3->save_content("$build_root/$title_number/includes/$fn", binmode => $binmode);
                        $z++;
                        $progress->update($z);
                    }
                }
            }

            # There are also an irritating number of linked supplementary documents.
            my $mech2 = $mech->clone();
            foreach my $doc_link ($mech->find_all_links(text_regex => qr/Attached Graphic/)) {
                my ($fn) = $doc_link->url() =~ /.+\/(.+)$/;
                $mech2->get($doc_link);
                # The binmode needs to be utf8 for html, but raw for pdfs (and everything else?).
                my $binmode = ($fn =~ /\.html$/ ? ':utf8' : ':raw');
                $mech2->save_content("$build_root/$title_number/includes/$fn", binmode => $binmode);
                $z++;
                $progress->update($z);
            }
        }

        # The last file downloaded seems to be a dupe of the next to last.
        unlink("$build_root/$title_number/" . sprintf("%06d", $a) . ".html");

        # Let's finish up the progress bar, since we've exited the loop.
        $progress->update($size_estimate{$title_number});
    }
}

sub compile {
    my (@titles) = @_;

    # We might be compiling more than one here.
    foreach my $title_number (@titles) {
        # Name of the html file we're going to create.
        my $work_in_progress;

        # We need to look up the list of html files, but only the ones without
        # aa, ab suffices. 
        opendir(DIR, "$build_root/$title_number");
        my @source_files = grep(/\d\.html$/,readdir(DIR));
        closedir(DIR);

        # We also need to convert any pdfs to svg.
        convert_pdfs_to_svg("$build_root/$title_number/includes");

        # We need to add some to the htmls too.
        opendir(DIR, "$build_root/$title_number/includes");
        my @html_files = grep(/\.html$/,readdir(DIR));
        closedir(DIR);

        # This will take awhile, let's provide some feedback.
        print "Compiling Title $title_number ...\n";
        my $progress = Term::ProgressBar->new({count => scalar(@source_files), ETA => 'linear', remove => 1});
        $progress->minor(0);
        $progress->max_update_rate(1);

        # We need to keep track of the last of each of title, part, chapter, etc.
        my %last_headers = ('division_a' => 'z', 'subchapter_a' => 'z', 
                            'chapter_a' => 'z', 'part_a' => 'z', 
                            'title_a' => 'z', 'section' => 'z');
        my $last_section_change = 0;
        # Loop through the files...
        my $a = 1;
        my $fh;
        foreach my $file (@source_files) {
            # Run it through our grimy little parser and add it to our file.
            my $file_contents = parse_tac_html_file("$build_root/$title_number/$file", \%last_headers);
            # This stuff is just too big. A single html file can be upwards of
            # 8 megs, and the resulting pdf file 2000+ pages. Let's break this
            # up by "part" section.
            if ($last_headers{'section'} ne $last_section_change) {
                # Close the old file, if there is one.
                if ($last_section_change) { 
                    print $fh "    </div>\n  </body>\n</html>";
                    close $fh;
                }
                # Update this value so we can check next iteration.
                $last_section_change = $last_headers{'section'};
                # New file, get it ready.
                $work_in_progress = qq($build_root/t${title_number}p$last_section_change.wip.html);
                copy ("$template_root/open.html", $work_in_progress);
                open($fh, '>>', $work_in_progress);
            }
            # Write it out to the work-in-progress file.
            print $fh "      <!-- $file -->\n";
            print $fh $file_contents;
            # Don't forget our progress bar.
            $progress->update($a);
            $a++;
        }
        # Close up the (last) html.
        print $fh "    </div>\n  </body>\n</html>";
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
    my ($filepath, $last_headers) = @_;

    my $file_contents = read_file($filepath);

    # If this rule is multi-part, let's farm that out to a new sub.
    if ($file_contents =~ m/NAME="Continued"/) { 
        $file_contents = reconstruct_rule_file($filepath); 
    }

    # We need a sub that just constructs the headers.
    my ($headers) = construct_h_tags($file_contents, $last_headers);

    # We'll need the title and rule number if we're putting in a See Figure x link.
    my ($title_number, $rule_number) = get_piece_numbers($file_contents);

    # Next, let's snip out the actual content.
    my ($parsed_markup) = $file_contents =~ /<TABLE\s*>\n<TR>\n<TD><HR><.TD>\n<.TR>\n<TR>\n<TD>(.+?)<\/TD>/s;

    # This thing has mixed \r and \n line endings. Not \r\n, but mixed 
    # (one or the other). Thanks Brian Watson, took him 3 minutes to
    # figure it out. We'll strip those now and save everyone grief.
    $parsed_markup =~ s/(\r|\n)/ /g;

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
    $parsed_markup =~ s/--/ &mdash; /g;
    $parsed_markup =~ s/<! &mdash; /<!--/g;
    $parsed_markup =~ s/ &mdash; >/-->/g;

    # Rather than links, let's include supplementary documents inline.
    my $iframes = $parsed_markup;
    $iframes =~ s/.*?<a href="(\/fids\/)(.+?)\.(html|pdf)">Attached Graphic<\/a>.*?(?=<a|$)/<iframe id="$2" src="$title_number\/includes\/$2.$3"><\/iframe>/sg;
    # We need any pdf document to be an svg instead.
    if ($iframes) { $iframes =~ s/\.pdf"><\/iframe>/.svg"><\/iframe>/sg; }
    # Any wording of "attached graphic" needs to be "see figure".
    $parsed_markup =~ s/<a href="(\/fids\/)(.+?)\.(html|pdf)">Attached Graphic<\/a>/<a href="#$2">See Figure $title_number TAC &sect;&nbsp;$rule_number<\/a>/sg;
    # Wrap everything in a p tag, tack iframes on at end, then source note.
    $parsed_markup =~ s/^(.+)$/      <p class="rule">$1<\/p>$iframes/sg;

    # Don't forget the source note.
    my ($source_note) = $file_contents =~ m/<TD>(<B>Source Note:.+?)<.TD>/s;
    $parsed_markup .= "\n      <p class='sourcenote'>$source_note</p>\n";

    # Or the headers...
    $parsed_markup = $headers . $parsed_markup;
    # Let's do this on the final pass, so that we get source notes too.
    $parsed_markup =~ s/&sect;/&sect;&nbsp;/g;

    return $parsed_markup;
}

sub reconstruct_rule_file {
    my ($filepath) = @_;

    my $file_contents = read_file($filepath);

    # Make the contents (for now) just the portion that contains the headers data.
    $file_contents =~ s/^.+(NAME="TITLE".+?<\/TABLE>).+$/$1/s;

    # If this rule is in a single file, no worries. But if there are cont'd
    # files, we have to roll through 001aa and 001ab, squash the contents
    # together, *then* parse those. Otherwise none but the last has a
    # source note, the regexes fail, warnings blow up all over the place.
    my ($path, $file_no_suffix) = $filepath =~ /^(.+)(\d{6})([a-z]{2})?.html/;

    # Get the true list of files.
    opendir(DIR, "$path");
    my @cont_files = grep(/$file_no_suffix([a-z]{2})?.html$/,readdir(DIR));
    closedir(DIR);

    $file_contents .= "<TABLE >\n<TR>\n<TD><HR></TD>\n</TR>\n<TR>\n<TD>";
    my $sn_markup;
    foreach my $partial (@cont_files) {
        # Better than undef $/, we'll just use File::Slurp.
        my $partial_contents = read_file("$path$partial");
        # Only a source note if the terminal nth of sequence.
        $sn_markup = $1 if $partial_contents =~ m/<TD>(<B>Source Note:.+?)<.TD>/s;
        # Next, let's snip out the actual content.
        $partial_contents =~ s/^.+<TABLE\s*>\s*<TR>\s*<TD><HR><.TD>\s*<.TR>\s*<TR>\s*<TD>\s*(.+?)<\/TD>.+$/$1/s;
        $file_contents .= $partial_contents;
    }
    $file_contents .= "</TD><TD>$sn_markup</TD>";
    $file_contents =~ s/<A HREF=".+?" NAME="Continued">.+?<\/A>//g;

    return $file_contents;
}

sub construct_h_tags {
    my ($file_contents, $last_headers) = @_;

    # Let's get all the header tag content, and build that portion of the html
    # to return.
    my ($title_a, $title_b, $rule_a, $rule_b) = 
            $file_contents =~ m/NAME="TITLE">(.+?)<.A><.TD><TD>(.+?)<.font>.+?<TD WIDTH=\d+>(.+?)<.TD><TD>(.+?)<.TD>/s;
    my ($part_a, $part_b) = 
            $file_contents =~ m/NAME="PART">(.+?)<.A><.TD><TD>(.+?)<.TD>/s;
    my ($chapter_a, $chapter_b) = 
            $file_contents =~ m/NAME="CHAPTER">(.+?)<.A><.TD><TD>(.+?)<.TD>/s;
    my ($subchapter_a, $subchapter_b) = 
            $file_contents =~ m/NAME="SUBCHAPTER">(.+?)<.A><.TD><TD>(.+?)<.TD>/s;
    my ($division_a, $division_b) = 
            $file_contents =~ m/NAME="DIVISION">(.+?)<.A><.TD><TD>(.+?)<.TD>/s;

    my $headers;
    # Now we'll compare what we got against %last_headers to see what we need
    # to add to this iteration's headers.
    if ($subchapter_a && $last_headers->{'subchapter_a'} ne $subchapter_a) {
        $last_headers->{'subchapter_a'} = $subchapter_a;
        #print "$rule_a\n\n"; die;
        if ($last_headers->{'chapter_a'} ne $chapter_a) {
            $last_headers->{'chapter_a'} = $chapter_a;
            if ($last_headers->{'part_a'} ne $part_a) {
                $last_headers->{'part_a'} = $part_a;
                if ($last_headers->{'title_a'} ne $title_a) {
                    $last_headers->{'title_a'} = $title_a;
                    my $h1 = Lingua::EN::Titlecase->new("$title_a - $title_b");
                    $headers .= "      <h1>" . $h1 . "</h1>\n";
                }
                my $h2 = Lingua::EN::Titlecase->new("$part_a - $part_b");
                $headers .= "      <h2>" . $h2 . "</h2>\n";
                # Now we're going to set this, so that we can start a new file.
                # Could use another section label, but for TAC part makes sense.
                ($last_headers->{'section'}) = $part_a =~ m/(\d+)/;
            }
            my $h3 = Lingua::EN::Titlecase->new("$chapter_a - $chapter_b");
            $headers .= "      <h3>" . $h3 . "</h3>\n";
        }
        my $h4 = Lingua::EN::Titlecase->new("$subchapter_a - $subchapter_b");
        $headers .= "      <h4>" . $h4 . "</h4>\n";
    }
    # Divisions only occur in a few subchapters. If a subchapter has two,
    # and we only check if the division has changed when a subchapter has, 
    # Then we won't see the second division. Nor can we nest everything in
    # divisions, since most of the time there are none.
    if ($division_a && $last_headers->{'division_a'} ne $division_a) {
        $last_headers->{'division_a'} = $division_a;
        my $h5 = Lingua::EN::Titlecase->new("$division_a - $division_b");
        $headers .= "      <h5>" . $h5 . "</h5>\n";
    }
    # Rule should change every time, regardless, no need to check. Also,
    # let's go ahead and put a space in the section symbol.
    my $h6 = Lingua::EN::Titlecase->new("$rule_a - $rule_b");
    $h6 =~ s/rule &sect;/Rule &sect&nbsp;/i;
    $headers .= "      <h6>" . $h6 . "</h6>\n";

    return $headers;
}

sub get_piece_numbers {
    my ($file_contents) = @_;

    my ($title_a, $rule_a) = 
            $file_contents =~ m/NAME="TITLE">(.+?)<.A><.TD>.+?<TD WIDTH=\d+>(.+?)<.TD>/s;

    # Need to have the title number and rule.
    my ($title_number) = $title_a =~ m/(\d+)/;
    my ($rule_number) = $rule_a =~ m/^.+?([0-9.]+)/;

    return ($title_number, $rule_number);
}

sub convert_pdfs_to_svg {
    my ($path) = @_;

    opendir(DIR, $path);
    my @pdfs = grep(/\.pdf$/,readdir(DIR));
    closedir(DIR);

    my ($title_number) = $path =~ m/tac.(\d+).includes/;

    print "Converting (Title $title_number) PDFs to SVG ...\n";
    my $progress = Term::ProgressBar->new({count => scalar(@pdfs), ETA => 'linear', remove => 1});
    $progress->minor(0);
    $progress->max_update_rate(1);

    my $a = 1;
    foreach my $pdf (@pdfs) {
        my $svg = $pdf; $svg =~ s/\.pdf$/.svg/; 
        # We need to invoke inkscape to do the svg conversion.
        system($inkscape . " --without-gui --file=$path/$pdf --export-plain-svg=$path/$svg &>/dev/null");
        # Also need to add a script tag to the end of the svg document.
        my $doc = HTML::Manipulator::Document->from_file("$path/$svg");
        my $svg_script = read_file("templates/us/texas/tac/svg.js");
        $doc->insert_before_end(svg2 => $svg_script);
        $doc->save_as("$path/$svg");
        $progress->update($a);
        $a++;
    }
}

################################################################################
################################################################################
################################################################################

1;