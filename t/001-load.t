#! C:/Perl/bin/perl
### Test that the module(s) load!(s)
use Test::Most;
use lib '../lib', 'lib';
use 5.010;
use Data::Walk::Extracted v0.015;
use Data::Walk::Print v0.009;
use Data::Walk::Prune v0.007;
use Data::Walk::Clone v0.005;
use Data::Walk::Graft v0.009;
pass		"Test loading the modules in the package";
explain 	"...Test Done";
done_testing();