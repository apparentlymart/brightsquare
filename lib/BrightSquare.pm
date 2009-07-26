
package BrightSquare;

use strict;
use warnings;
use Net::OAuth;
use LWP::UserAgent;
use JSON::Any;
use Carp;
use BrightSquare::Place;
use BrightSquare::Provider::BrightKite;
use BrightSquare::Provider::FourSquare;
use Geo::Google::StaticMaps;
use Template;
use FindBin;
my $base_dir;
BEGIN {
    $base_dir = $FindBin::Bin."/..";
}

my $ua = LWP::UserAgent->new();
$ua->agent('BrightSquare/0.1');

my $json = JSON::Any->new();

sub new {
    my ($class, $config) = @_;

    my $self = bless {}, $class;
    $self->{config} = $config;

    return $self;
}

sub brightkite {
    return BrightSquare::Provider::BrightKite->new($_[0]->{config}{BrightKite});
}

sub foursquare {
    return BrightSquare::Provider::FourSquare->new($_[0]->{config}{FourSquare});
}

sub is_probably_same_place {
    my ($class, $place1, $place2) = @_;

    my $difference_is_less_than = sub {
        my ($n1, $n2, $allowed_diff) = @_;

        my $adsq = $allowed_diff ** 2;
        my $diffsq = ($n1 - $n2) ** 2;

        return ($diffsq <= $adsq) ? 1 : 0;
    };

    if ($difference_is_less_than->($place1->lat, $place2->lat, 0.005) && $difference_is_less_than->($place1->lon, $place2->lon, 0.005)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub ua {
    return $ua;
}

sub json {
    return $json;
}

sub handle_request {
    my ($self, $cgi) = @_;

    my $sent_header = 0;
    my $header = sub {
        unless ($sent_header) {
            print "Content-type: text/html; charset=utf-8\n\n";
            $sent_header = 1;
        }
    };

    my $lat = $cgi->param('lat');
    my $lon = $cgi->param('lon');
    my $search_query = $cgi->param('q');
    my $brightkite_place_id = $cgi->param('bkid');
    my $foursquare_place_id = $cgi->param('fsid');

    my $url = $cgi->url;

    my $t = new Template(
        INCLUDE_PATH => "$base_dir/templates",
    );
    my $render_template = sub {
        my ($filename, $stash) = @_;
        $stash ||= {};
        $stash->{current_url} = $url;
        $stash->{current_args} = {
            lat => $lat,
            lon => $lon,
            'q' => $search_query,
            bkid => $brightkite_place_id,
            fsid => $foursquare_place_id,
        };
        $header->();
        $t->process($filename, $stash);
    };

    my $brightkite = $self->brightkite;
    my $foursquare = $self->foursquare;

    my $brightkite_place = $brightkite_place_id ? $brightkite->get_place_by_id($brightkite_place_id) : undef;
    my $foursquare_place = $foursquare_place_id && $foursquare_place_id ne 'none' ? $foursquare->get_place_by_id($foursquare_place_id) : undef;

    if ($cgi->request_method ne 'POST') {

        unless ($lat && $lon) {
            # Lat/Lon Finder

            $render_template->("find_coords.tt");
        }
        elsif (! $brightkite_place_id) {
            # BrightKite Search/Select Page
            my @places = $brightkite->find_places(
                lat => $lat,
                lon => $lon,
                ($search_query ? (name => $search_query) : ()),
            );
            $render_template->("select_place.tt", {
                provider => "BrightKite",
                field_name => "bkid",
                places => \@places,
                search_query => $search_query ? $search_query : '',
            });
        }
        elsif (! $foursquare_place_id) {
            # FourSquare Search/Select Page

            # We search FourSquare using data from BrightKite to increase
            # the chance that we'll hit the same venue on FourSquare.

            my @places = $foursquare->find_places(
                lat => $brightkite_place->lat,
                lon => $brightkite_place->lon,
                name => $brightkite_place->name,
            );

            # Also do a search for the user's original search string.
            push @places, $foursquare->find_places(
                lat => $brightkite_place->lat,
                lon => $brightkite_place->lon,
                name => $search_query,
            ) unless @places;

            @places = grep { BrightSquare->is_probably_same_place($brightkite_place, $_) } @places;

            unshift @places, BrightSquare::Place->new({
                name => "None",
                display_location => "Don't check in on FourSquare",
                id => "none",
            });

            $render_template->("select_place.tt", {
                provider => "FourSquare",
                field_name => "fsid",
                places => \@places,
                search_query => $search_query ? $search_query : '',
            });

        }
        else {
            # Checkin Confirm Page

            $render_template->("confirm_checkin.tt", {
                checkins => [
                    $brightkite_place ? ({
                        provider => "BrightKite",
                        place => $brightkite_place,
                        map_img_url => $self->map_url_for_place($brightkite_place),
                        provider_icon_url => "provider_icons/brightkite.ico",
                    }) : (),
                    $foursquare_place ? ({
                        provider => "FourSquare",
                        place => $foursquare_place,
                        map_img_url => $self->map_url_for_place($foursquare_place),
                        provider_icon_url => "provider_icons/foursquare.ico",
                    }) : (),
                ],
            });
        }
    }
    else {
        # Actually do the checkin!

        my @checkin_notes = ();

        push @checkin_notes, ($brightkite->check_in_at_place($brightkite_place)) if $brightkite_place;
        push @checkin_notes, ($foursquare->check_in_at_place($foursquare_place)) if $foursquare_place;

        $render_template->("checkin_result.tt", {
            notes => \@checkin_notes,
        });
    }

}

sub map_url_for_place {
    my ($self, $place) = @_;

    return Geo::Google::StaticMaps->url(
        key => $self->{config}{GoogleMaps}{api_key},
        size => [ 100, 100 ],
        zoom => 15,
        markers => [
            {
                lat => $place->lat,
                lon => $place->lon,
                size => "tiny",
                color => "green",
            },
        ],
    );
}

1;
