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

# Stupidly simple auth via a magic secret cookie
# TODO: Do something better that maybe even allows for multiple users.
if (my $auth_secret = $config->{CookieAuthSecret}) {
    my $cookie_secret = $cgi->cookie('a');
    unless ($auth_secret eq $cookie_secret) {
        print "Status: 403 Forbidden\n";
        print "Content-type: text/html\n\n";
        print "<p>This is not for you.</p>";
        exit(0);
    }
}

my $brightsquare = new BrightSquare($config);

$brightsquare->handle_request($cgi);

