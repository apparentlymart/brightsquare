
package BrightSquare::Provider;

use strict;
use warnings;
use Carp;

sub find_places {
    my ($self, %params) = @_;

    my $lat = delete $params{lat};
    my $lon = delete $params{lon};
    my $name = delete $params{name};

    Carp::croak("Unrecognised parameters: ".join(',', keys %params)) if %params;

    return $self->_find_places($lat, $lon, $name);
}

sub check_in_at_place {
    my ($self, $place) = @_;

    Carp::croak("Can't check in to a place from ".$place->source_provider." with a $self") unless ref($self) eq $place->source_provider;

    return $self->check_in_at_place_by_id($place->id);
}

sub check_in_at_place_by_id {
    my ($self, $place_id) = @_;

    return $self->_check_in_at_place_by_id($place_id);
}

sub get_place_by_id {
    my ($self, $place_id) = @_;

    return $self->_get_place_by_id($place_id);
}

1;
