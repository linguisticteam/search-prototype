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

my @headers = qw(Date Project Short Running Repository Languages);
my $te = HTML::TableExtract->new(
    headers => \@headers,
    attribs => {class=>"wikitable sortable", style=>"text-align:center"},
    keep_html => 1,
);
$te->parse_file($file);

my @tables = $te->tables;
for my $table (@tables)
{
    for my $row ($table->rows )
    {
        my $json = JSON->new;
        my $repoLocation = @$row[4];
        next unless ($repoLocation =~ "href");
        my $parser = HTML::TokeParser::Simple->new(string => $repoLocation);
        my $dotSubURL = "";
        while (my $anchor = $parser->get_tag('a')) 
        {
            next unless defined(my $href = $anchor->get_attr('href'));
            $dotSubURL = $href;
        }
        
        my $title = @$row[1];
        $parser = HTML::TokeParser::Simple->new(string => $title);
        $parser->utf8_mode(1);
        my $href = $parser->get_tag(); # without this, won't pull out title
        my $value = $parser->get_token();
        if (defined $value)
        {
            next if $href =~ "<strike>";
            $title = $value->as_is();
        }

        $parser = HTML::TokeParser::Simple->new(string => @$row[2]);
        $parser->utf8_mode(1); 
        my $description = $parser->get_token()->as_is();
        
        my $uuid = substr($dotSubURL, length("http://dotsub.com/view/"));
        $uuid =~ s/\///g;
        
        # Translation/Transcription File Download api
        my $languageCode = "eng";
        my $format = "srt";
        my $dotsubAPIURL = "https://dotsub.com/media/$uuid/c/$languageCode/$format";
        my $base64;
        my $ua = LWP::UserAgent->new();
        my $response = $ua->post( $dotsubAPIURL);
        if ($response->is_success)
        {
            my $subtitles = $response->content();           
            $base64 = encode_base64("$subtitles", '');
        }
        else
        { 
            print "WARNING: There was a problem getting the subtitles for $title: " . $response->status_line . "\n";
            next;
        }

        my ($original, @videoURLs) = getVideoData(@$row[5], $href, @$row[2]);
        
        #print "$original\n";
        #print Dumper @videoURLs;
        
        my $dataToJSON = {date=>trim(@$row[0]), title=>$title, file=>$base64, duration=>trim(@$row[3]), description=>trim($description), url=>$original};
        
        if (not $dryRun)
        {
            my $wj = WWW::JSON->new(
                    base_url => "http://$elasticsearchIP:9200",
                    post_body_format => 'JSON'
                );
            
            my $docId =  $uuid;
            my $get = $wj->post(
                "/lti/en/$docId?pipeline=attachment",
                $dataToJSON
            );
            
            print $get->status_line . "\n" unless $get->success;
            
        }
        else
        {
            my $debugJSON = {date=>trim(@$row[0]), title=>trim($title), duration=>trim(@$row[3]), description=>trim($description), url=>$original};
            
            print Dumper $debugJSON;
        }        
    }
}

sub getVideoData
{
    my $languagesColumn = shift;
    my $titleHref = shift;
    my $descriptionColumn = shift;
    
    my @videos = ();
    my $original = "";
    
    my $parser = HTML::TokeParser::Simple->new(string => $languagesColumn);
    while (my $anchor = $parser->get_tag('a')) 
    {
        my $lang = $parser->get_token()->as_is();
        next unless defined(my $href = $anchor->get_attr('href'));
        my %video;
        if (defined($lang and $href))
        {
            $video{language} = $lang;
            $video{link} = $href;
            push(@videos, \%video);
        }
    }

    if (defined $titleHref)
    {
        $original = $titleHref->get_attr('href');
    }
    
    if (not defined $original)
    {
        $parser = HTML::TokeParser::Simple->new(string => $descriptionColumn);
        while (my $anchor = $parser->get_tag('a')) 
        {
            next unless defined(my $href = $anchor->get_attr('href'));
            if ($href ne "")
            {
                $original = $href;
                last;
            }
        }
        
        if (not defined $original)
        {
            #default to the first link and then try to get the English link to override it
            for my $video (@videos)
            {
                if ($video->{language} eq "English")
                {
                    $original = $video->{link};
                }
            }
            if (not defined $original and @videos)
            {
                $original = $videos[0]->{link};
            }
        }
    }

    #return original and array of hashes (containing language + video link)
    return ($original, \@videos);
}