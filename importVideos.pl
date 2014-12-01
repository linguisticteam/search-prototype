#!/usr/bin/perl -w
use strict;
use warnings;

use MIME::Base64;
use HTML::TableExtract;
use LWP::Simple;
use JSON;
use Data::Dumper;
use HTML::TokeParser::Simple;
use File::Slurp 'read_file';
use WWW::JSON;
use LWP::UserAgent;
use String::Util qw(trim);

my $numArgs = $#ARGV;
if ($numArgs != 1) 
{
    die("\nUsage: importVideos.pl elasticsearchIP workingPath\n");
}

my ($elasticsearchIP, $workingPath) = @ARGV;

if (not defined $elasticsearchIP) 
{
  die("Supply IP address of Elasticsearch server.");
}

if (not defined $workingPath) 
{
  die("Supply local working area path.");
}

my $file = $workingPath . '/Official-LTI-Repository.html';
my $dryRun = 0;

unless ( -e $file ) 
{
    my $rc = getstore('http://wiki.linguisticteam.org/w/Video_Repository', $file);
    die "Failed to download document\n" unless $rc == 200;
}

my @headers = qw(Date Project Short Running Public);
my $te = HTML::TableExtract->new(
    headers => \@headers,
    attribs => {class=>"wikitable sortable", style=>"text-align:center"},
    keep_html => 1,
);
#$te->parse_file(Encode::decode_utf8($file));
$te->parse_file($file);

my @tables = $te->tables;
for my $table (@tables)
{
    for my $row ($table->rows ) 
    {
        my $json = JSON->new;
        my $parser = HTML::TokeParser::Simple->new(string => @$row[4]);
        my $dotSubURL = "";
        while (my $anchor = $parser->get_tag('a')) 
        {
            next unless defined(my $href = $anchor->get_attr('href'));
            $dotSubURL = $href;
        }
        
        $parser = HTML::TokeParser::Simple->new(string => @$row[2]);
        my $youTubeURL = "";
        while (my $anchor = $parser->get_tag('a')) 
        {
            next unless defined(my $href = $anchor->get_attr('href'));
            $youTubeURL = $href;
            last if $youTubeURL ne "";
        }

        my $title = @$row[1];
        $parser = HTML::TokeParser::Simple->new(string => $title);
        $parser->utf8_mode(1); # attempt to fix "Parsing of undecoded UTF-8 will give garbage when decoding entities at .../perl/vendor/lib/HTML/PullParser.pm line 81." Get two less errors than without it...
        my $href = $parser->get_tag(); # without this, won't pull out title
        my $value = $parser->get_token();
        if (defined $value)
        {
            $title = $value->as_is();
        }
        
        if ($youTubeURL eq "")
        {
            if (defined $href)
            {
                #get the url from the title as a next resort
                $youTubeURL = $href->get_attr('href');
            }
        }

        $parser = HTML::TokeParser::Simple->new(string => @$row[2])->get_token();
        my $description = $parser->as_is();
        
        my $uuid = substr($dotSubURL, length("http://dotsub.com/view/"));

        # Translation/Transcription File Download api
        my $languageCode = "eng";
        my $format = "srt";
        my $dotsubAPIURL = "https://dotsub.com/media/$uuid/c/$languageCode/$format";
        my $coded;
        my $ua = LWP::UserAgent->new();
        my $response = $ua->post( $dotsubAPIURL);
        if ($response->is_success)
        {
            my $subtitles = $response->content();
            $coded=encode_base64($subtitles);
        }
        else
        {
            #todo: 
            print "ERROR: There was a problem getting the subtitles from dotsub\n";
        }

        my $dataToJSON = {date=>trim(@$row[0]), title=>$title, file=>$coded, duration=>trim(@$row[3]), description=>trim($description), url=>$youTubeURL};
        
        if (not $dryRun)
        {
            my $wj = WWW::JSON->new(
                    base_url => "http://$elasticsearchIP:9200",
                    post_body_format => 'JSON'
                );
            
            my $docId =  $uuid;
            my $get = $wj->post(
                "/lti/en/$docId",
                $dataToJSON
            );
        }
        else
        {
            my $debugJSON = {date=>trim(@$row[0]), title=>trim($title), duration=>trim(@$row[3]), description=>trim($description), url=>$youTubeURL};
            
            print Dumper $debugJSON;
        }
    }
}
#todo: more testing, checking
#todo: test with perl version 5.8
#todo: phrase searches
#todo: what if no url e.g. Discovery Channel...
#todo: fix Parsing of undecoded UTF-8 will give garbage when decoding entities at ...perl/vendor/lib/HTML/PullParser.pm...
#todo: check dupes aren't added
