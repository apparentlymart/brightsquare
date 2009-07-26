
package BrightSquare::Place;

use strict;
use warnings;

use base qw(Class::Accessor::Faster);

__PACKAGE__->mk_accessors(qw(id name address1 address2 city state country postal_code display_location lat lon source_provider));

1;
