#! C:/Perl/bin/perl
#######  Test File for   #######

use Modern::Perl;

use Test::Most;
use YAML::Any;
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.03;

my  ( $firstref, $secondref, );

my  @methods = qw(
        new
        walk_the_data
    );

$| = 1;
### Clean the workbench (from previous failed runs)

### easy questions
map can_ok( 
    'Data::Walk::Extracted',
    $_ 
), @methods;

### hard questions
lives_ok{   
    $firstref = Load(
        '---
        Someotherkey:
            value
        Parsing:
            HashRef:
                LOGGER:
                    run: INFO
        Helping:
            - Somelevel
            - MyKey:
                MiddleKey:
                    LowerKey1: lvalue1
                    LowerKey2:
                        BottomKey1: 12345
                        BottomKey2:
                        - bavalue1
                        - bavalue2
                        - bavalue3'
    );
}                                                       'Build a ref for testing';
lives_ok{ Data::Walk::Extracted->walk_the_data( primary_ref => $firstref, ) }
                                                        'Test sending the data structure';
lives_ok{   
    $secondref = Load(
        '---
        Someotherkey:
            value
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
}                                                       'Build a second ref for testing';
lives_ok{ 
    Data::Walk::Extracted->walk_the_data(
        primary_ref     => $firstref,
        secondary_ref   => $secondref,
) }                                                     'Test sending the data structure with a second structure for matching';
lives_ok{ 
    Data::Walk::Extracted->walk_the_data(
        primary_ref     =>  $firstref,
        secondary_ref   =>  $secondref,
        object          =>  Data::Walk::Extracted::Print->new(
                                match_highlighting => 0,
                            ),
    ) 
}                                                       'Test sending the data structure with a second structure for matching but with the matching flags turned off';

done_testing();
say '...Test Done';