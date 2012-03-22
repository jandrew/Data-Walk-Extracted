#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Extracted  #######
BEGIN{
    # Comment out to turn off debug printing
    #~ $ENV{Smart_Comments} = '###';# #### #####
}
my $TestOutput = 1;

use Modern::Perl;

use Test::Most;
use YAML::Any;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Smart::Comments -ENV;#'###'
$| = 1;
### <where> - Smart-Comments turned on for Data-Walk-Extracted.t
use Data::Walk::Extracted v0.05;
use Data::Walk::Print v0.05;
$Carp::Verbose = ($TestOutput) ? 0 : 1 ;

my  ( $firstref, $secondref, $newclass, $AT_ST, $AT_AT, $output, $result, $row );
open( SAVEOUT, ">&STDOUT");
open( SAVEERR, ">&STDERR");
my $test_case = 0;
my  @methods = qw(
        new
        walk_the_data
    );
my  $answer_ref = [
    qr/The composed class passed to 'new' does not have either a 'before_method' or an 'after_method' the Role 'Data::Walk::Print' will be added/,
    [
        "{", "\tHelping => [", "\t\t{", "\t\t\tSomelevel => {", 
        "\t\t\t\tSublevel => \'levelvalue\',", "\t\t\t},", "\t\t},", "\t\t{", 
        "\t\t\tMyKey => {", "\t\t\t\tMiddleKey => {", 
        "\t\t\t\t\tLowerKey1 => 'lvalue1',", "\t\t\t\t\tLowerKey2 => {", 
        "\t\t\t\t\t\tBottomKey1 => '12345',", "\t\t\t\t\t\tBottomKey2 => [", 
        "\t\t\t\t\t\t\t'bavalue2',", "\t\t\t\t\t\t\t'bavalue1',", 
        "\t\t\t\t\t\t\t'bavalue3',", "\t\t\t\t\t\t],", 
        "\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},", "\t\t},", "\t],", 
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
        "\t\t\tSomelevel => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
        "\t\t\t\tSublevel => \'levelvalue\',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match", 
        "\t\t\t},", "\t\t},", "\t\t{#<--- Secondary Position Exists - Ref Type Match", 
        "\t\t\tMyKey => {#<--- Secondary Key Match - Ref Type Match", 
        "\t\t\t\tMiddleKey => {#<--- Secondary Key Match - Ref Type Match", 
        "\t\t\t\t\tLowerKey1 => 'lvalue1',#<--- Secondary Key Match - Secondary Value Does NOT Match", 
        "\t\t\t\t\tLowerKey2 => {#<--- Secondary Key Match - Ref Type Match", 
        "\t\t\t\t\t\tBottomKey1 => '12345',#<--- Secondary Key Match - Secondary Value Does NOT Match", 
        "\t\t\t\t\t\tBottomKey2 => [#<--- Secondary Key Match - Ref Type Match", 
        "\t\t\t\t\t\t\t'bavalue2',#<--- Secondary Position Exists - Secondary Value Does NOT Match", 
        "\t\t\t\t\t\t\t'bavalue1',#<--- Secondary Position Exists - Secondary Value Does NOT Match", 
        "\t\t\t\t\t\t\t'bavalue3',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match",
        "\t\t\t\t\t\t],", "\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},", "\t\t},", "\t],", 
        "\tParsing => {#<--- Secondary Key Mismatch - Ref Type Mismatch",
        "\t\tHashRef => {#<--- Secondary Key Mismatch - Ref Type Mismatch", 
        "\t\t\tLOGGER => {#<--- Secondary Key Mismatch - Ref Type Mismatch",
        "\t\t\t\trun => 'INFO',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match", 
        "\t\t\t},", "\t\t},", "\t},",
        "\tSomeotherkey => 'value',#<--- Secondary Key Match - Secondary Value Matches",
        '},',
    ],
    [
        "{", "\tHelping => [", "\t\t{", "\t\t\tSomelevel => {", 
        "\t\t\t\tSublevel => \'levelvalue\',", "\t\t\t},", "\t\t},", "\t\t{", 
        "\t\t\tMyKey => {", "\t\t\t\tMiddleKey => {", 
        "\t\t\t\t\tLowerKey1 => 'lvalue1',", "\t\t\t\t\tLowerKey2 => {", 
        "\t\t\t\t\t\tBottomKey1 => '12345',", "\t\t\t\t\t\tBottomKey2 => [", 
        "\t\t\t\t\t\t\t'bavalue2',", "\t\t\t\t\t\t\t'bavalue1',", 
        "\t\t\t\t\t\t\t'bavalue3',", "\t\t\t\t\t\t],", 
        "\t\t\t\t\t},", "\t\t\t\t},", "\t\t\t},", "\t\t},", "\t],", 
        "\tParsing => {", "\t\tHashRef => {", "\t\t\tLOGGER => {",
        "\t\t\t\trun => 'INFO',", "\t\t\t},", "\t\t},", "\t},",
        "\tSomeotherkey => 'value',", "},"
    ],
];
### <where> - Smart-Comments settings: $ENV{Smart_Comments}
### <where> - Clean the workbench (from previous failed runs)

### <where> - easy questions
map can_ok( 
    'Data::Walk::Extracted',
    $_ 
), @methods;
lives_ok{ print SAVEOUT '' }                            'Confirm that the SAVEOUT filehandle was built';
lives_ok{ print SAVEERR '' }                            'Confirm that the SAVEERR filehandle was built';

### <where> - hard questions
lives_ok{   
    $firstref = Load(
        '---
        Parsing:
            HashRef:
                LOGGER:
                    run: INFO
        Someotherkey: value
        Helping:
            - Somelevel:
                Sublevel: levelvalue
            - MyKey:
                MiddleKey:
                    LowerKey1: lvalue1
                    LowerKey2:
                        BottomKey1: 12345
                        BottomKey2:
                        - bavalue2
                        - bavalue1
                        - bavalue3'
    );
}                                                       'Build a data ref for testing';
if( $TestOutput ){
    ### <where> - Buffer STDERR
    close   STDERR;
    open (  STDERR, ">", \$output )
        or die "Can't open STDERR: $!";
}
lives_ok{
    $AT_ST = Data::Walk::Extracted->new( 
        sort_HASH => 1,#To force order for testing purposes
) }                                                     "Build an instance to use for testing (Test case: $test_case)";
### <where> - Data Walker: $AT_ST
if( $TestOutput ){
    close   STDERR;#Close STDERR capture
    open (  STDERR, ">&SAVEERR" )
        or die "Can't restore STDERR: $!";
    chomp( $output ) if $output;
    like( $output, $answer_ref->[$test_case],           "Testing for the warning from test case: $test_case");
    $output = undef;
    ### <where> - Now buffer STDOUT
    close   STDOUT;
    open (  STDOUT, ">", \$output )
        or die "Can't open STDOUT: $!";
}
$test_case++;
lives_ok{ $result = $AT_ST->walk_the_data( primary_ref => $firstref, ) }
                                                        'Test sending the data structure for test case: ' . $test_case;
if( $TestOutput ){
    $row = 0;
    for my $output_line( split "\n", $output ){
        ### $output_line
        ### Compare line: $answer_ref->[$test_case]->[$row]
        is( $output_line, $answer_ref->[$test_case]->[$row],
                                                        "Testing the output for test case -$test_case- and row: $row");
        $row++;
    }
    close   STDOUT;
    $output = undef;
    open (  STDOUT, ">", \$output )
        or die "Can't open STDOUT: $!";
}
$test_case++;
lives_ok{ $AT_ST->skip_ARRAY_ref( 1 ); }                "... set 'skip = yes' for future parsed ARRAY refs (test case: $test_case)";
lives_ok{ $result = $AT_ST->walk_the_data( primary_ref => $firstref, ) }
                                                        'Test sending the data structure for test case: ' . $test_case;
#### list: $answer_ref->[$test_case]
if( $TestOutput ){
    $row = 0;
    for my $output_line( split "\n", $output ){
        ### $output_line
        ### Compare line: $answer_ref->[$test_case]->[$row]
        is( $output_line, $answer_ref->[$test_case]->[$row],
                                                        "Testing the output for test case -$test_case- and row: $row");
        $row++;
    }
    close   STDOUT;
    $output = undef;
    open (  STDOUT, ">", \$output )
        or die "Can't open STDOUT: $!";
}
$test_case++;
lives_ok{ $AT_ST->skip_ARRAY_ref( 0 ); }                "... set 'skip = NO' for future parsed ARRAY refs (test case: $test_case)";
lives_ok{   
    $secondref = Load(
        '---
        Someotherkey: value
        Helping:
            - Somelevel
            - MyKey:
                MiddleKey:
                    LowerKey1:
                        Testkey1: value1
                        Testkey2: value2
                    LowerKey2:
                        BottomKey1: 12346
                        BottomKey2:
                        - bavalue1
                        - bavalue3'
    );
}                                                       "Build a second ref for testing (test case $test_case)";
lives_ok{ 
    $AT_ST->walk_the_data(
        primary_ref     => $firstref,
        secondary_ref   => $secondref,
) }                                                     "Test sending the data structure with a second structure for matching(test case: $test_case)";
if( $TestOutput ){
    $row = 0;
    for my $output_line( split "\n", $output ){
        ### $output_line
        ### Compare line: $answer_ref->[$test_case]->[$row]
        is( $output_line, $answer_ref->[$test_case]->[$row],
                                                        "Testing the output for test case -$test_case- and row: $row");
        $row++;
    }
    close   STDOUT;
    $output = undef;
    open (  STDOUT, ">", \$output )
        or die "Can't open STDOUT: $!";
}
$test_case++;
lives_ok{
    $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Print' ) );
    $AT_AT = $newclass->new(
        match_highlighting => 0,
        sort_HASH => 1,#To force order for testing purposes
    );
}                                                       "Prep a new class with the Print Role intentionally added and the match text turned off (test case: $test_case)";
lives_ok{
    $AT_AT->walk_the_data(
        primary_ref     =>  $firstref,
        secondary_ref   =>  $secondref,
    ) 
}                                                       "Test sending the data structures as in test case -" . ($test_case - 1) . "- but with the matching flags turned off (test case: $test_case)";
#### list: $answer_ref->[$test_case]
if( $TestOutput ){
    $row = 0;
    for my $output_line( split "\n", $output ){
        ### $output_line
        ### Compare line: $answer_ref->[$test_case]->[$row]
        is( $output_line, $answer_ref->[$test_case]->[$row],
                                                        "Testing the output for test case -$test_case- and row: $row");
        $row++;
    }
    close   STDOUT;
    open (  STDOUT, ">&SAVEOUT" )
        or die "Can't restore STDOUT: $!";
}
$test_case++;
done_testing();
say '...Test Done';