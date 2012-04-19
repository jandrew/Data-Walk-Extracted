#! C:/Perl/bin/perl
### Test that the module(s) load!(s)
use Test::More;
use Test::And::Output v0.003;
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.007;
use Data::Walk::Print v0.007;
use Data::Walk::Prune v0.003;
use Data::Walk::Graft v0.001;
pass( "Test loading the modules in the package" );
done_testing();
