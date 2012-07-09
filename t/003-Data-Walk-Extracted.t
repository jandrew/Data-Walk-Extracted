#!perl
#######  Test File for Data::Walk::Extracted  #######
BEGIN{
	#~ $ENV{ Smart_Comments } = '### #### #####';
}

use Test::Most;
use Test::Moose;
use Capture::Tiny qw( 
	capture_stdout 
);
use Smart::Comments -ENV;#'###'
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.011;
use Data::Walk::Print v0.009;

my  ( 
			$first_ref, $second_ref, $newclass, $gutenberg, 
			$test_inst, $capture, $wait 
);#
my 			$test_case = 1;
my 			@class_attributes = qw(
				sort_HASH
				sort_ARRAY
				skip_HASH_ref
				skip_ARRAY_ref
				skip_SCALAR_ref
				change_array_size
			);
my  		@class_methods = qw(
				new
				has_sort_HASH
				get_sort_HASH
				set_sort_HASH
				clear_sort_HASH
				has_sort_ARRAY
				get_sort_ARRAY
				set_sort_ARRAY
				clear_sort_ARRAY
				get_skip_HASH_ref
				get_skip_ARRAY_ref
				get_skip_SCALAR_ref
				set_skip_HASH_ref
				set_skip_ARRAY_ref
				set_skip_SCALAR_ref
				clear_skip_HASH_ref
				clear_skip_ARRAY_ref
				clear_skip_SCALAR_ref
				has_skip_HASH_ref
				has_skip_ARRAY_ref
				has_skip_SCALAR_ref
				set_change_array_size
				get_change_array_size
				has_change_array_size
				clear_change_array_size
			);
my  		@instance_attributes = qw(
				sort_HASH
				sort_ARRAY
				skip_HASH_ref
				skip_ARRAY_ref
				skip_SCALAR_ref
				change_array_size
				match_highlighting
			);
my  		@instance_methods = qw(
				print_data
				set_match_highlighting
				get_sort_HASH
				get_sort_ARRAY
				get_skip_HASH_ref
				get_skip_ARRAY_ref
				get_skip_SCALAR_ref
				set_sort_HASH
				set_sort_ARRAY
				set_skip_HASH_ref
				set_skip_ARRAY_ref
				set_skip_SCALAR_ref
				clear_sort_HASH
				clear_sort_ARRAY
				clear_skip_HASH_ref
				clear_skip_ARRAY_ref
				clear_skip_SCALAR_ref
				has_sort_HASH
				has_sort_ARRAY
				has_skip_HASH_ref
				has_skip_ARRAY_ref
				has_skip_SCALAR_ref
				set_change_array_size
				get_change_array_size
				has_change_array_size
				clear_change_array_size
				set_match_highlighting
				get_match_highlighting
				has_match_highlighting
				clear_match_highlighting
			);
my			$answer_ref = [
				'',#qr/The composed class passed to 'new' does not have either a 'before_method' or an 'after_method' the Role 'Data::Walk::Print' will be added/,
				[
					"{", "\tHelping => [", "\t\t{", "\t\t\tMyKey => {", "\t\t\t\tMiddleKey => {",
					"\t\t\t\t\tLowerKey1 => 'lvalue1',", "\t\t\t\t\tLowerKey2 => {", 
					"\t\t\t\t\t\tBottomKey1 => '12345',", "\t\t\t\t\t\tBottomKey2 => [", 
					"\t\t\t\t\t\t\t'bavalue2',", "\t\t\t\t\t\t\t'bavalue1',", 
					"\t\t\t\t\t\t\t'bavalue3',", "\t\t\t\t\t\t],", 
					"\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},","\t\t\tSomelevel => {", 
					"\t\t\t\tSublevel => \'levelvalue\',", "\t\t\t},", "\t\t},", "\t],",
					"\tParsing => {", "\t\tHashRef => {", "\t\t\tLOGGER => {",
					"\t\t\t\trun => 'INFO',", "\t\t\t},", "\t\t},", "\t},",
					"\tSomeotherkey => 'value',", "},"
				],
				[
					"{", "\tHelping => [# !!! SKIPPED !!!", "\t],", 
					"\tParsing => {", "\t\tHashRef => {", "\t\t\tLOGGER => {",
					"\t\t\t\trun => 'INFO',", "\t\t\t},", "\t\t},", "\t},",
					"\tSomeotherkey => 'value',", "},"
				],
				[
					"{#<--- Ref Type Match", "\tHelping => [#<--- Secondary Key Match - Ref Type Match",
					"\t\t{#<--- Secondary Position Exists - Ref Type Mismatch", 
					"\t\t\tMyKey => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\t\tMiddleKey => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\t\t\tLowerKey1 => 'lvalue1',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match", 
					"\t\t\t\t\tLowerKey2 => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\t\t\t\tBottomKey1 => '12345',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match", 
					"\t\t\t\t\t\tBottomKey2 => [#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\t\t\t\t\t'bavalue2',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match", 
					"\t\t\t\t\t\t\t'bavalue1',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match", 
					"\t\t\t\t\t\t\t'bavalue3',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match", 
					"\t\t\t\t\t\t],", "\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},", 
					"\t\t\tSomelevel => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\t\tSublevel => 'levelvalue',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match", 
					"\t\t\t},", "\t\t},", "\t],", "\tParsing => {#<--- Secondary Key Match - Ref Type Mismatch", 
					"\t\tHashRef => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\tLOGGER => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
					"\t\t\t\trun => 'INFO',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match", 
					"\t\t\t},", "\t\t},", "\t},", 
					"\tSomeotherkey => 'value',#<--- Secondary Key Match - Secondary Value Matches", 
					"},", 
				],
				[
					"{", "\tHelping => [", "\t\t{", "\t\t\tMyKey => {", "\t\t\t\tMiddleKey => {", 
					"\t\t\t\t\tLowerKey1 => 'lvalue1',", "\t\t\t\t\tLowerKey2 => {", 
					"\t\t\t\t\t\tBottomKey1 => '12345',", "\t\t\t\t\t\tBottomKey2 => [", 
					"\t\t\t\t\t\t\t'bavalue2',", "\t\t\t\t\t\t\t'bavalue1',", "\t\t\t\t\t\t\t'bavalue3',", 
					"\t\t\t\t\t\t],", "\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},", "\t\t\tSomelevel => {", 
					"\t\t\t\tSublevel => 'levelvalue',", "\t\t\t},", "\t\t},", "\t],", "\tParsing => {", 
					"\t\tHashRef => {", "\t\t\tLOGGER => {", "\t\t\t\trun => 'INFO',", "\t\t\t},", "\t\t},", 
					"\t},", "\tSomeotherkey => 'value',", "},",
				],
				[
					"{#<--- Ref Type Match", "\tHelping => [#<--- Secondary Key Match - Ref Type Match",
					"\t\t'Somelevel',#<--- Secondary Position Exists - Secondary Value Matches",
					"\t\t{#<--- Secondary Position Exists - Ref Type Match",
					"\t\t\tMyKey => {#<--- Secondary Key Match - Ref Type Match",
					"\t\t\t\tMiddleKey => {#<--- Secondary Key Match - Ref Type Match",
					"\t\t\t\t\tLowerKey1 => 'lvalue1',#<--- Secondary Key Match - Secondary Value Matches",
					"\t\t\t\t\tLowerKey2 => {#<--- Secondary Key Match - Ref Type Match",
					"\t\t\t\t\t\tBottomKey1 => '12345',#<--- Secondary Key Match - Secondary Value Does NOT Match",
					"\t\t\t\t\t\tBottomKey2 => [#<--- Secondary Key Match - Ref Type Match",
					"\t\t\t\t\t\t\t'bavalue1',#<--- Secondary Position Exists - Secondary Value Matches",
					"\t\t\t\t\t\t\t'bavalue2',#<--- Secondary Position Exists - Secondary Value Matches",
					"\t\t\t\t\t\t\t'bavalue3',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match",
					"\t\t\t\t\t\t],", "\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},", "\t\t},", "\t],",
					"\tParsing => {#<--- Secondary Key Mismatch - Ref Type Mismatch",
					"\t\tHashRef => {#<--- Secondary Key Mismatch - Ref Type Mismatch",
					"\t\t\tLOGGER => {#<--- Secondary Key Mismatch - Ref Type Mismatch",
					"\t\t\t\trun => 'INFO',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match",
					"\t\t\t},", "\t\t},", "\t},",
					"\tSomeotherkey => 'value',#<--- Secondary Key Match - Secondary Value Matches",
					"},",
				],
			];
### <where> 'easy questions
map{ 
has_attribute_ok
			'Data::Walk::Extracted', $_,
										"Check that Data::Walk::Extracted has the -$_- attribute"
} 			@class_attributes;
map{
can_ok		'Data::Walk::Extracted', $_,
} 			@class_methods;

### <where> 'harder questions
lives_ok{
			$gutenberg = with_traits( 
				'Data::Walk::Extracted', 
				( 'Data::Walk::Print' ) 
			)->new( sort_HASH => 1, );#To ensure test passes
}										"Prep a new Print instance";
map{
has_attribute_ok 
			$gutenberg, $_,				"Check that the new class has the -$_- attribute"
} 			@instance_attributes;
map can_ok( 
			$gutenberg, $_,
), 			@instance_methods;

### <where> 'hardest questions
lives_ok{   
			$first_ref = {
				Someotherkey => 'value',
				Parsing =>{
					HashRef =>{
						LOGGER =>{
							run => 'INFO',
						},
					},
				},
				Helping =>[
					{
						Somelevel =>{
							Sublevel => 'levelvalue',
						},
						MyKey =>{
							MiddleKey =>{
								LowerKey1 => 'lvalue1',
								LowerKey2 => {
									BottomKey1 => '12345',
									BottomKey2 =>[
										'bavalue2',
										'bavalue1',
										'bavalue3',
									],
								},
							},
						},
					},
				],
			};
}                                        'Build the $first_ref for testing';
#### $first_ref
ok			$capture = capture_stdout{ 
				$gutenberg->print_data( print_ref => $first_ref, ) 
			},							'Test sending the data structure for test case: ' . $test_case;
my  		$x = 0;
my  		@answer = split "\n", $capture;
### <where> - checking the answers for test: $test_case
map{
is			$answer[$x], $_, 			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case";
}			@{$answer_ref->[$test_case]};
			$test_case++;
ok			$gutenberg->set_skip_ARRAY_ref( 1 ),
										"... set 'skip = yes' for future parsed ARRAY refs (test case: $test_case)";
lives_ok{
			$capture = capture_stdout{ 
				$gutenberg->print_data( print_ref => $first_ref, ); 
			}
}										'Test running the same array with the skip_ARRAY_ref set positive (capturing the output)';
			$x = 0;
			@answer = split "\n", $capture;
### <where> - checking the answers for test: $test_case
map{
is			$answer[$x], $_, 			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case";
}			@{$answer_ref->[$test_case]};
			$test_case++;
lives_ok{ 
			$gutenberg->set_skip_ARRAY_ref( 0 ); 
}										"... set 'skip = NO' for future parsed ARRAY refs (test case: $test_case)";
lives_ok{   
			$second_ref = {
				Someotherkey => 'value',
				'Parsing' =>[
					HashRef =>{
						LOGGER =>{
							run => 'INFO',
						},
					},
				],
				Helping =>[
					[
						'Somelevel',
					],
					{
						MyKey =>{
							MiddleKey =>{
								LowerKey1 =>{
									Testkey1 => 'value1',
									Testkey2 => 'value2',
								},
								LowerKey2 => {
									BottomKey1 => '12354',
									BottomKey2 =>[
										'bavalue1',
										'bavalue3',
									],
								},
							},
						},
					},
				],
			};
}   									"Build a second ref for testing (test case $test_case)";
dies_ok{ 
			$gutenberg->print_data( data_ref => $first_ref, );
}										"Test sending the data with a bad key";
like		$@, qr/The key -print_ref- is required and must have a value/,
										"Check that the code caught the wrong failure";
lives_ok{
			$capture = capture_stdout{ $gutenberg->print_data( 
				print_ref => $first_ref,
				match_ref => $second_ref,
			); }
}                                       "Test the non matching state with a match ref sent";
			$x = 0;
			@answer = split "\n", $capture;
### <where> - checking the answers for test: $test_case
map{
is			$answer[$x], $_, 			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case";
}			@{$answer_ref->[$test_case]};
			$test_case++;
lives_ok{ 
			$gutenberg->set_match_highlighting( 0 ); 
}										"... set 'match_highlighting = NO' for future parsed refs (test case: $test_case)";
dies_ok{
			$gutenberg->print_data(
				primary_ref	=>  $first_ref,
				match_ref   =>  $second_ref,
			) 
}										"Send a bad reference (actually the underlying method reference) with a new request to print";
like		$@, qr/The key -print_ref- is required and must have a value/,
										"Test that the error message was found";
lives_ok{
			$capture = capture_stdout{ $gutenberg->print_data(
				print_ref	=>  $first_ref,
				match_ref   =>  $second_ref,
			) }
}                                      "Send the same request with the reference fixed";#~ $x = 0;
			$x = 0;
			@answer = split "\n", $capture;
### <where> - checking the answers for test: $test_case
map{
is			$answer[$x], $_, 			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case";
}			@{$answer_ref->[$test_case]};
			$test_case++;
lives_ok{
			$first_ref = {
				Someotherkey => 'value',
				Parsing => {
					HashRef => {
						LOGGER => {
							run => 'INFO',
						},
					},
				},
				Helping => [
					'Somelevel',
					{
						MyKey => {
							MiddleKey => {
								LowerKey1 => 'lvalue1',
								LowerKey2 => {
									BottomKey1 => '12345',
									BottomKey2 => [
										'bavalue1',
										'bavalue2',
										'bavalue3',
									],
								},
							},
						},
					},
				],
			};
			$second_ref = {
				Someotherkey => 'value',
				Helping => [
					'Somelevel',
					{
						MyKey => {
							MiddleKey => {
								LowerKey1 => 'lvalue1',
								LowerKey2 => {
									BottomKey2 => [
										'bavalue1',
										'bavalue2',
									],
									BottomKey1 => '12354',
								},
							},
						},
					},
				],
			};
}										"A bug fix text case for testing secondary value equivalence (test case $test_case)";
lives_ok{ 
			$gutenberg->set_match_highlighting( 1 ); 
}										"... set 'match_highlighting = YES' for future parsed refs (test case: $test_case)";
lives_ok{
			$capture = capture_stdout{ $gutenberg->print_data(
				print_ref	=>  $first_ref,
				match_ref   =>  $second_ref,
			) }
}										"Send the request to print_data";
			$x = 0;
			@answer = split "\n", $capture;
### <where> - checking the answers for test: $test_case
map{
is			$answer[$x], $_, 			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case";
}			@{$answer_ref->[$test_case]};
			$test_case++;
explain 								"...Test Done";
done_testing();