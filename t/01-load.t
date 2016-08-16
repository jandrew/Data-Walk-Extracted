#!perl
### Test that the module(s) load!(s)
use	Test::More tests => 16;
BEGIN{ use_ok( version ) };
BEGIN{ use_ok( Test::Moose ) };
BEGIN{ use_ok( MooseX::StrictConstructor ) };
BEGIN{ use_ok( MooseX::HasDefaults::RO ) };
BEGIN{ use_ok( Class::Inspector ) };
BEGIN{ use_ok( Scalar::Util ) };
BEGIN{ use_ok( Carp ) };
BEGIN{ use_ok( Types::Standard ) };
BEGIN{ use_ok( Capture::Tiny, qw( capture_stderr ) ) };
use	lib '../lib', 'lib';
BEGIN{ use_ok( Data::Walk::Extracted::Types, 0.028 ) };
BEGIN{ use_ok( Data::Walk::Extracted::Dispatch, 0.028 ) };
BEGIN{ use_ok( Data::Walk::Extracted, 0.028 ) };
BEGIN{ use_ok( Data::Walk::Print, 0.028 ) };
BEGIN{ use_ok( Data::Walk::Prune, 0.028 ) };
BEGIN{ use_ok( Data::Walk::Clone, 0.028 ) };
BEGIN{ use_ok( Data::Walk::Graft, 0.028 ) };
done_testing();