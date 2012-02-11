#! C:/Perl/bin/perl
### Test that the module loads

use Test::More tests => 1;

use lib 'lib';##Change for Scite vs non Scite testing
BEGIN { 
    use_ok( 
        'Data::Walk::Extracted'
    ); 
}


