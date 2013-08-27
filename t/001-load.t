#!perl
### Test that the module(s) load!(s)
use Test::Most;
use 5.010;
use lib '../lib', 'lib';
use Data::Walk::Extracted::Dispatch 0.002;
use Data::Walk::Extracted::Types 0.002;
use Data::Walk::Extracted 0.020;
use Data::Walk::Print 0.020;
use Data::Walk::Prune 0.012;
use Data::Walk::Clone 0.012;
use Data::Walk::Graft 0.014;
pass		"Test loading the modules in the package";
explain 	"...Test Done";
done_testing();