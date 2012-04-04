#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Extracted  #######
use Modern::Perl;

use Test::Most;
use Test::Output v1.01 qw( 
        stderr_like
        stderr_unlike 
        stdout_from
);
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.05;
use Data::Walk::Print v0.05;

my  ( $firstref, $secondref, $newclass, $AT_ST, $AT_AT, $result, $stdout );
my $test_case = 0;
my  @methods = qw(
        new
        walk_the_data
    );
my  $answer_ref = [
    qr/The composed class passed to 'new' does not have either a 'before_method' or an 'after_method' the Role 'Data::Walk::Print' will be added/,
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
map can_ok( 
    'Data::Walk::Extracted',
    $_ 
), @methods;

### <where> - hard questions
lives_ok{   
    $firstref = {
        Someotherkey    => 'value',
        Parsing         =>{
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
}                                                       'Build the $first for testing';
stderr_like{
    $AT_ST = Data::Walk::Extracted->new( sort_HASH => 1, );#To force order for testing purposes
} $answer_ref->[$test_case],                            "Testing for the warning from test case: $test_case (while creating a new instance)";
$test_case++;
$stdout = stdout_from{
lives_ok{ $result = $AT_ST->walk_the_data( primary_ref => $firstref, ) }
                                                        'Test sending the data structure for test case: ' . $test_case;
};
is_deeply( [ split /\n/, $stdout ], $answer_ref->[$test_case],
                                                        "Testing the output from test case: $test_case");
$test_case++;
lives_ok{ $AT_ST->skip_ARRAY_ref( 1 ); }                "... set 'skip = yes' for future parsed ARRAY refs (test case: $test_case)";
$stdout = stdout_from{
    $result = $AT_ST->walk_the_data( primary_ref => $firstref, );
};
is_deeply( [ split /\n/, $stdout ], $answer_ref->[$test_case],
                                                        "Testing the STDOUT output from test case: $test_case");
is_deeply(  $result,
            { primary_ref => $firstref },               "Testing the value output from test case: $test_case");
$test_case++;
lives_ok{ $AT_ST->skip_ARRAY_ref( 0 ); }                "... set 'skip = NO' for future parsed ARRAY refs (test case: $test_case)";
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
}                                                       "Build a second ref for testing (test case $test_case)";
$stdout = stdout_from{
    $result = $AT_ST->walk_the_data(
        primary_ref     => $firstref,
        secondary_ref   => $secondref,
    );
};
is_deeply( [ split /\n/, $stdout ], $answer_ref->[$test_case],
                                                        "Testing the STDOUT output from test case: $test_case");
is_deeply(  $result,
            {
                primary_ref     => $firstref,
                secondary_ref   => $secondref,
            },                                          "Testing the value output from test case: $test_case");
$test_case++;
lives_ok{
    $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Print' ) );
}                                                       "Prep a new class with the Print Role intentionally added and the match text turned off (test case: $test_case)";
stderr_unlike{
    $AT_AT = $newclass->new(
        match_highlighting => 0,
        sort_HASH => 1,#To force order for testing purposes
    );
} $answer_ref->[0],                                     "Check that the error message from teste case 0 is not given when the instance is created";
#Test with the matching flag turned off
$stdout = stdout_from{
    $result = $AT_AT->walk_the_data(
        primary_ref     =>  $firstref,
        secondary_ref   =>  $secondref,
    ) 
};
is_deeply( [ split /\n/, $stdout ], $answer_ref->[$test_case],
                                                        "Testing the STDOUT output from test case: $test_case");
is_deeply(  $result,
            {
                primary_ref     => $firstref,
                secondary_ref   => $secondref,
            },                                          "Testing the value output from test case: $test_case");
$test_case++;
done_testing();
say '...Test Done';