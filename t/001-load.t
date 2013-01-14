#!perl
### Test that the module(s) load!(s)
use Test::Most;
use 5.010;
use MooseX::ShortCut::BuildInstance 0.005;
use lib '../lib', 'lib';
use Data::Walk::Extracted::Dispatch 0.001;
use Data::Walk::Extracted::Types 0.001;
use Data::Walk::Extracted 0.019;
use Data::Walk::Print 0.015;
use Data::Walk::Prune 0.011;
use Data::Walk::Clone 0.011;
use Data::Walk::Graft 0.013;
pass		"Test loading the modules in the package";
explain 	"...Test Done";
done_testing();