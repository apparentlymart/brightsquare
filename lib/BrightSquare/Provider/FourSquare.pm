
package BrightSquare::Provider::FourSquare;

use strict;
use warnings;
use base qw(BrightSquare::Provider);
use Net::OAuth;
use Data::Dumper;
use BrightSquare;
use BrightSquare::Place;
use BrightSquare::CheckInNote;
use XML::XPath;

my $make_place = sub {
    my ($xp, $e) = @_;

    my $value = sub { $xp->findvalue($_[0], $e)->value };

    BrightSquare::Place->new({
        id => $value->("id"),
        name => $value->("name"),
        display_location => $value->("address").", ".$value->("city").", ".$value->("state"),
        lat => $value->("geolat"),
        lon => $value->("geolong"),
        city => $value->("city"),
        state => $value->("state"),
        address1 => $value->("address"),
        source_provider => __PACKAGE__,
    });
};

sub new {
    my ($class, $config) = @_;

    return bless $config, $class;
}

sub _find_places {
    my ($self, $lat, $lon, $name) = @_;

    my $url = "http://api.playfoursquare.com/v1/venues.xml";
    my $args = {
        ($name ? ('q' => $name) : ()),
        geolat => $lat,
        geolong => $lon,
    };

    my $xp = $self->_get_request($url, $args);

    return map {
        $make_place->($xp, $_);
    } $xp->findnodes("/venues/group/venue");

}

sub _get_place_by_id {
    my ($self, $id) = @_;

    my $url = "http://api.playfoursquare.com/v1/venue.xml";
    my $args = {
        vid => $id,
    };

    my $xp = $self->_get_request($url, $args);

    $make_place->($xp, $xp->findnodes("/venue"));

}

sub _check_in_at_place_by_id {
    my ($self, $id) = @_;

    my $url = "http://api.playfoursquare.com/v1/checkin";
    my $args = {
        vid => $id,
    };


    my $xp = $self->_post_request($url, $args);

    my @ret = ();

    if (my $result_text = $xp->getNodeText("/checkin/message")) {
        push @ret, BrightSquare::CheckInNote->new({
            heading => "FourSquare Checkin Successful",
            extra => $result_text,
        });
    }

    foreach my $badge_elem ($xp->findnodes("/checkin/badges/badge")) {
        my $name = $xp->findvalue("name", $badge_elem);
        my $description = $xp->findvalue("message", $badge_elem);

        push @ret, BrightSquare::CheckInNote->new({
            heading => "You've earned the \"$name\" badge",
            extra => $description,
        });
    }

    return @ret;
}

sub _get_request {
    my ($self, $url, $args) = @_;

    my $config = $self;
    my $ua = BrightSquare->ua;
    my $json = BrightSquare->json;

    my $oauth_req = Net::OAuth->request('protected resource')->new(
        consumer_key => $config->{consumer_key},
        consumer_secret => $config->{consumer_secret},
        token => $config->{token},
        token_secret => $config->{token_secret},
        request_url => $url,
        request_method => 'GET',
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => sprintf("%08x%08x", time(), rand(2 ** 32)),
        extra_params => $args,
    );

    $oauth_req->sign();
    my $res = $ua->get($oauth_req->to_url);

    if ($res->is_success) {
        return XML::XPath->new(xml => $res->content);
    }
    else {
        Carp::croak("Request failed: ".$res->status_line);
    }
}

sub _post_request {
    my ($self, $url, $args) = @_;

    my $config = $self;
    my $ua = BrightSquare->ua;
    my $json = BrightSquare->json;

    my $oauth_req = Net::OAuth->request('protected resource')->new(
        consumer_key => $config->{consumer_key},
        consumer_secret => $config->{consumer_secret},
        token => $config->{token},
        token_secret => $config->{token_secret},
        request_url => $url,
        request_method => 'POST',
        signature_method => 'HMAC-SHA1',
        timestamp => time(),
        nonce => sprintf("%08x%08x", time(), rand(2 ** 32)),
        extra_params => $args,
    );

    $oauth_req->sign();

    my $req = HTTP::Request->new(POST => $oauth_req->to_url);

    my $res = $ua->request($req);

    if ($res->is_success) {
        return XML::XPath->new(xml => $res->content);
    }
    else {
        Carp::croak("Request failed: ".$res->status_line);
    }

}

1;
