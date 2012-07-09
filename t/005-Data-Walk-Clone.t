#!perl
#######  Test File for Data::Walk::Clone  #######
use Test::Most;
use Test::Moose;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.011;
use Data::Walk::Clone v0.003;

my  ( 
			$wait,
			$victor_frankenstein, 
			$donor_ref, 
			$test_ref, 
			$dolly_ref, 
			$masha_ref, 
			$little_nicky_ref,
			$injaz_ref,
);

my  		@attributes = qw(
				clone_level
				skip_clone_tests
				should_clone
			);

my  		@methods = qw(
				new
				deep_clone
				has_clone_level
				get_clone_level
				set_clone_level
				clear_clone_level
				get_skip_clone_tests
				clear_skip_clone_tests
				add_skip_clone_test
				has_skip_clone_tests
				set_skip_clone_tests
				set_should_clone
				get_should_clone
				has_should_clone
				clear_should_clone
			);
    
# basic questions
lives_ok{
			$victor_frankenstein = with_traits( 
				'Data::Walk::Extracted', 
					( 
						'Data::Walk::Clone', 
					) 
			)->new();
}										"Prep a new cloner instance";
does_ok		$victor_frankenstein, 'Data::Walk::Clone',
										"Check that 'with_traits' added the 'Data::Walk::Clone' Role to the instance";
map has_attribute_ok( 
			$victor_frankenstein, 
			$_,							"Check that Data::Walk::Clone has the -$_- attribute"
), 			@attributes;
map can_ok($victor_frankenstein, $_ ), @methods;
#Run the hard questions
lives_ok{   
			$donor_ref = {
				Someotherkey    => 'value',
				Parsing         =>{
					HashRef =>{
						LOGGER =>{
							run => 'INFO',
						},
					},
				},
				Helping =>[
					'Somelevel',
					{
						MyKey =>{
							MiddleKey =>{
								LowerKey1 => 'lvalue1',
								LowerKey2 => {
									BottomKey1 => 'bvalue1',
									BottomKey2 => 'bvalue2',
								},
							},
						},
					},
				],
			};
}										'Build the $donor_ref for testing';
lives_ok{   
			$test_ref ={
				Someotherkey    => 'value',
				Parsing         =>{
					HashRef =>{
						LOGGER =>{
							run => 'INFO',
						},
					},
				},
				Helping =>[
					'Somelevel',
					{
						MyKey =>{
							MiddleKey =>{
								LowerKey1 => 'lvalue1',
								LowerKey2 => {
									BottomKey1 => 'bvalue1',
									BottomKey2 => 'bvalue2',
								},
							},
						},
					},
				],
			};
}										'Build the $test_ref for testing';
lives_ok{
			$dolly_ref = $victor_frankenstein->deep_clone(
				donor_ref => $donor_ref,
			) 
}										'Test cloning the donor ref';
is_deeply	$dolly_ref, $test_ref,		'See if the $test_ref matches the clone deeply';
is_deeply	$dolly_ref, $donor_ref,		'See if the $donor_ref matches the clone deeply';
isnt 		$dolly_ref, $test_ref,		'... but it should not match a test ref at the top level';
isnt 		$dolly_ref, $donor_ref,		'... and it should not match the donor ref at the top level';
ok 			$victor_frankenstein->add_skip_clone_test( 
				[ 'HASH', 'LowerKey2', 'ALL',   'ALL' ] 
			),							'Add a skip test to see if partial deep cloning will work';
lives_ok{
			$masha_ref = $victor_frankenstein->deep_clone(
				donor_ref => $donor_ref,
			)
}										'Test cloning the donor ref with a skip called out';
isnt		$masha_ref, $donor_ref,		'It should not match the doner ref at the top level';
is_deeply	$masha_ref, $donor_ref,		'Confirm that the new clone matches deeply';
isnt 		$masha_ref, $donor_ref,		'... and the new clone does not match the donor ref at the top level';
is			$masha_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2}, 
			$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2},
										'... but it should match at the skip level';
isnt		$masha_ref->{Helping}->[1]->{MyKey}->{MiddleKey}, 
			$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey},
										'... and it should not match one level up from the skip level';
lives_ok{ 	$victor_frankenstein->clear_skip_clone_tests }
										'clear the skip test to ensure it is possible';
lives_ok{
			$little_nicky_ref = $victor_frankenstein->deep_clone(
				$donor_ref,
			)
}										'Test cloning the donor ref without a skip called out (again) and sending the donor without a key';
isnt		$little_nicky_ref, $donor_ref,	
										'It should not match the doner ref at the top level';
is_deeply 	$little_nicky_ref, $donor_ref,	
										'Confirm that the new clone matches deeply';
isnt		$little_nicky_ref, $donor_ref,	
										'... and the new clone does not match the donor ref at the string pointer';
isnt		$little_nicky_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2}, 
			$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2},
										'... and it should not match at the (old) skip level';
ok 			$victor_frankenstein->set_clone_level( 1 ),
										'Add a clone level boundary to see if bounded deep cloning will work';
lives_ok{
			$injaz_ref = $victor_frankenstein->deep_clone(
				donor_ref 	=> $donor_ref,
				clone_level => 3,
			)
}										'Test cloning the donor ref with a boundary called out (as a one time method change';
is_deeply	$injaz_ref, $donor_ref,		'Confirm that the new clone matches deeply';
isnt 		$injaz_ref, $donor_ref,		'... and the new clone does not match the donor ref at the top level';
is			$injaz_ref->{Helping}->[1]->{MyKey}, 
			$donor_ref->{Helping}->[1]->{MyKey},
										'... but it should match at the bondary level';
isnt		$injaz_ref->{Helping}->[1], $donor_ref->{Helping}->[1],
										'... and it should not match one level up from the boundary level';
lives_ok{ 	$victor_frankenstein->clear_clone_level }
										'clear the boundary to ensure it is possible';
explain 								"... Test Done\n";
done_testing;