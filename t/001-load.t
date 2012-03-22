#! C:/Perl/bin/perl
### Test that the module loads

use Test::Most;

use lib '../lib', 'lib';

my  @modules = ( 
        'Data::Walk::Extracted v0.05',
        'Data::Walk::Print v0.05',
        'Data::Walk::Prune v0.01',
    );

map{ use_ok( $_ ) } @modules;
done_testing;


