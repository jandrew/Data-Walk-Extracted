#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Extracted  #######
BEGIN{
    # Comment out to turn off debug printing
    #~ $ENV{Smart_Comments} = '###';# #### #####
}

use Modern::Perl;

use Test::Most;
use Test::Moose;
use YAML::Any;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Smart::Comments -ENV;
$| = 1;
$Carp::Verbose = 1;
### <where> - Smart-Comments turned on for Data-Walk-Extracted.t
use Data::Walk::Extracted v0.05;
use Data::Walk::Prune v0.01;

my  ( $wait, $newclass, $edward_scissorhands, $firstref, $secondref, $topiary );

my  @methods = qw(
        new
        prune
        before_method
        after_method
        change_splice_behavior
    );

my  @attributes = qw(
        splice_arrays
    );
    
# basic questions
lives_ok{
    $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Prune' ) );
    $edward_scissorhands = $newclass->new;
}                                                       "Prep a new Prune instance";
does_ok( $edward_scissorhands, 'Data::Walk::Prune',     "Check that 'with_traits' added the 'Data::Walk::Prune' Role to the instance");
map has_attribute_ok( $edward_scissorhands, $_,         "Check that the new instance has the -$_- attribute"), @attributes;
map can_ok( $edward_scissorhands, $_ ), @methods;

#Run the hard questions
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
                        BottomKey1: bvalue1
                        BottomKey2: bvalue2'
    );
    $secondref = Load(
        '---
        Parsing:
            Logger:
                LOGGER:
                    run: INFO'
    );
}                                                       'Build two HashRefs for testing';
is_deeply(  $edward_scissorhands->prune(
                slice_ref => { Someotherkey => {} }, 
                tree_ref  => $firstref,
            ),
            Load(
                '---
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
                                BottomKey1: bvalue1
                                BottomKey2: bvalue2'
            ),                                          'Test pruning a top level key' );
is_deeply(  $edward_scissorhands->prune(
                tree_ref    => $firstref, 
                slice_ref   => Load(
                    '---
                    Helping:
                    -
                    - MyKey:
                        MiddleKey:
                            LowerKey2:
                                BottomKey1: {}' 
                ),
            ), 
            Load(
                '---
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
                                BottomKey2: bvalue2'
            ),                                          'Test pruning a low level key (through an arrayref level)' );
ok( $edward_scissorhands->change_splice_behavior( 1 ),  'Turn on splice removal of array elements');
is_deeply(  $edward_scissorhands->prune(
                tree_ref    => $firstref, 
                slice_ref   => Load(
                    '---
                    Helping:
                    - Somelevel
                    - MyKey:
                        MiddleKey:
                            LowerKey1: []' 
                ),
            ), 
            Load(
                '---
                Parsing:
                    HashRef:
                        LOGGER:
                            run: INFO
                Helping:
                    - Somelevel
                    - MyKey:
                        MiddleKey:
                            LowerKey2:
                                BottomKey2: bvalue2'
            ),                                          'Test pruning (by splice) an array element' );
done_testing;
say ' Test Done';