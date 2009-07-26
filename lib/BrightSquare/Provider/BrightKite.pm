
package BrightSquare::Provider::BrightKite;

use strict;
use warnings;
use base qw(BrightSquare::Provider);
use Net::OAuth;
use Data::Dumper;
use BrightSquare;
use BrightSquare::Place;
use BrightSquare::CheckInNote;
use HTTP::Request;

my $make_place = sub {
    my ($p) = @_;

    return BrightSquare::Place->new({
        id => $p->{id},
        name => $p->{name},
        display_location => $p->{display_location},
        lat => $p->{latitude},
        lon => $p->{longitude},
        source_provider => __PACKAGE__,
    });
};

sub new {
    my ($class, $config) = @_;

    return bless $config, $class;
}

sub _find_places {
    my ($self, $lat, $lon, $name) = @_;

    $name ||= "*";

    my $url = "http://brightkite.com/places/search.json";
    my $args = {
        'q' => $name,
        clat => $lat,
        clng => $lon,
    };

    my $results = $self->_get_request($url, $args);

    $results = [$results] unless ref $results eq 'ARRAY';

    return map {
        $make_place->($_);
    } @$results;

}

sub _check_in_at_place_by_id {
    my ($self, $id) = @_;

    my $url = "http://brightkite.com/places/".$id."/checkins.json";

    my $result = $self->_post_request($url, {});

    my $place_name = $result->{place}{name};

    # No useful information to return for BrightKite.
    return (BrightSquare::CheckInNote->new({
        heading => "Checked in on BrightKite",
        extra => "You're now checked in at $place_name",
    }));
}

sub _get_place_by_id {
    my ($self, $id) = @_;

    my $url = "http://brightkite.com/places/".$id.".json";
    my $result = $self->_get_request($url, {});

    return $make_place->($result);
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

    print STDERR "Sending request to ".$oauth_req->to_url."\n";

    my $res = $ua->get($oauth_req->to_url);

    if ($res->is_success) {
        return $json->decode($res->content);
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

    my $req = HTTP::Request->new(POST => $url);
    $req->content($oauth_req->to_post_body);

    print STDERR "Sending ".$req->as_string."\n";

    my $res = $ua->request($req);

    if ($res->is_success) {
        return $json->decode($res->content);
    }
    else {
        print STDERR $res->as_string;
        Carp::croak("Request failed: ".$res->status_line);
    }
}

1;
