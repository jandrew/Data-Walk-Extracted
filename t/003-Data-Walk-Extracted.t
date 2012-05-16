#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Extracted  #######
BEGIN{
    #~ $ENV{Smart_Comments} = '### #### #####';#
    #~ $| = 1;
    #~ $Carp::Verbose = 1;
}

use Test::Most;
use Test::Moose;
use Capture::Tiny qw( 
	capture_stdout 
);
	#~ capture_stderr 
use Smart::Comments -ENV;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.007;
use Data::Walk::Print v0.007;

my  ( $firstref, $secondref, $newclass, $gutenberg, $test_inst, $capture, $wait );#
my $test_case = 1;
my  @extracted_attributes = qw(
        sort_HASH
        sort_ARRAY
        skip_HASH_ref
        skip_ARRAY_ref
        skip_TERMINATOR_ref
        change_array_size
    );
my  @extracted_methods = qw(
        new
        change_array_size_behavior
    );
my  @joint_attributes = qw(
        sort_HASH
        sort_ARRAY
        skip_HASH_ref
        skip_ARRAY_ref
        skip_TERMINATOR_ref
        change_array_size
        match_highlighting
    );
my  @instance_methods = qw(
        print_data
        change_array_size_behavior
        set_match_highlighting
    );
my  $answer_ref = [
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
];
### <where> - easy questions
map has_attribute_ok( 
    'Data::Walk::Extracted', 
    $_,                                                 "Check that Data::Walk::Extracted has the -$_- attribute"
), @extracted_attributes;
map can_ok( 
    'Data::Walk::Extracted',
    $_,
), @extracted_methods;

### <where> - harder questions
lives_ok{
    $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Print' ) );
    $gutenberg = $newclass->new( sort_HASH => 1, );#To ensure test passes
}                                                       "Prep a new Print instance";
map has_attribute_ok( 
    $newclass, 
    $_,                                                 "Check that the new class has the -$_- attribute"
), @joint_attributes;
map can_ok( 
    $gutenberg,
    $_,
), @instance_methods;

### <where> - hardest questions
lives_ok{   
    $firstref = {
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
}                                                       'Build the $firstref for testing';
#### $firstref
ok( $capture = capture_stdout{ $gutenberg->print_data( print_ref => $firstref, ) },
														'Test sending the data structure for test case: ' . $test_case );
my  $x = 0;
my  @answer = split "\n", $capture;
for my $line ( @{$answer_ref->[$test_case]} ){
    is( $line, $answer[$x],						'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case" );
}
$test_case++;
ok( $gutenberg->skip_ARRAY_ref( 1 ),	"... set 'skip = yes' for future parsed ARRAY refs (test case: $test_case)");
#~ $test_inst->capture_output( 'STDOUT',                   "Begin capture of 'STDOUT'");
lives_ok{
     $capture = capture_stdout{ $gutenberg->print_data( print_ref => $firstref, ); }
}                                                       'Test running the same array with the skip_ARRAY_ref set positive (capturing the output)';
#~ map{ warn "$_\n" } $test_inst->get_buffer( 'STDOUT' );
$x = 0;
@answer = split "\n", $capture;
for my $line ( @{$answer_ref->[$test_case]} ){
    is( $line, $answer[$x],          			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case" );
}
#~ $test_inst->return_to_screen( 'STDOUT',                 "... Checking 'STDOUT' buffer" );
#~ map{ print "$_\n" } $test_inst->get_buffer( 'STDOUT' );
$test_case++;
lives_ok{ $gutenberg->skip_ARRAY_ref( 0 ); }
														"... set 'skip = NO' for future parsed ARRAY refs (test case: $test_case)";
lives_ok{   
    $secondref = {
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
}                                            			"Build a second ref for testing (test case $test_case)";
dies_ok{ 
		$gutenberg->print_data( data_ref => $firstref, );
}														"Test sending the data with a bad key";
like( $@, qr/The key -print_ref- is required and must have a value/,
                                                        "Check that the code caught the wrong failure");
lives_ok{
    $capture = capture_stdout{ $gutenberg->print_data( 
        print_ref => $firstref,
        match_ref => $secondref,
    ); }
}                                                       "Test the non matching state with a match ref sent";
$x = 0;
@answer = split "\n", $capture;
for my $line ( @{$answer_ref->[$test_case]} ){
   is( $line, $answer[$x],          				'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case" );
}
$test_case++;
lives_ok{ $gutenberg->set_match_highlighting( 0 ); }
														"... set 'match_highlighting = NO' for future parsed refs (test case: $test_case)";
dies_ok{
    $gutenberg->print_data(
        primary_ref    =>  $firstref,
        match_ref   =>  $secondref,
    ) 
}                                                       "Send a bad reference (actually the underlying method reference) with a new request to print";
like( $@, qr/The key -print_ref- is required and must have a value/,
                                                        "Test that the error message was found" );
lives_ok{
     $capture = capture_stdout{ $gutenberg->print_data(
        print_ref    =>  $firstref,
        match_ref   =>  $secondref,
    ) }
}                                                       "Send the same request with the reference fixed";#~ $x = 0;
$x = 0;
@answer = split "\n", $capture;
for my $line ( @{$answer_ref->[$test_case]} ){
	is( $line, $answer[$x],          			'Test matching line -' . (1 + $x++) . "- of the output for test: $test_case" );
}
$test_case++;
done_testing();
explain "...Test Done";