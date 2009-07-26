#!/usr/bin/perl

use strict;
use CGI;
use Template;
use FindBin;
use CGI::Carp qw(fatalsToBrowser);
use YAML::Syck;

my $base_dir;
BEGIN {
    $base_dir = $FindBin::Bin."/..";
}

use lib "$base_dir/lib";

use BrightSquare;

my $cgi = new CGI;
my $t = new Template(
    INCLUDE_PATH => "$base_dir/templates",
);

my $config = YAML::Syck::LoadFile("$base_dir/config.yaml") or die "No configuration file";

my $brightsquare = new BrightSquare($config);

$brightsquare->handle_request($cgi);

