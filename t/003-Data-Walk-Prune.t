#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Prune  #######
use Modern::Perl;

use Test::Most;
use Test::Moose;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.007;
use Data::Walk::Prune v0.003;

my  ( $wait, $newclass, $edward_scissorhands, $treeref, $sliceref, $answerref );

my  @methods = qw(
        new
        prune_data
        change_array_size_behavior
    );

my  @attributes = qw(
        change_array_size
    );
    
# basic questions
lives_ok{
    $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Prune', ) );
    $edward_scissorhands = $newclass->new();
}                                                       "Prep a new Prune instance";
does_ok( $edward_scissorhands, 'Data::Walk::Prune',     "Check that 'with_traits' added the 'Data::Walk::Prune' Role to the instance");
map has_attribute_ok( $edward_scissorhands, $_,         "Check that the new instance has the -$_- attribute"), @attributes;
map can_ok( $edward_scissorhands, $_ ), @methods;

#Run the hard questions
lives_ok{   
    $treeref = {
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
}                                                       'Build the $treeref for testing';
lives_ok{   
    $answerref =  {
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
}                                                       'Build the $answerref for testing';
is_deeply(  $edward_scissorhands->prune_data(
                slice_ref => { Someotherkey => {} }, 
                tree_ref  => $treeref,
            ),
            $answerref,                                 'Test pruning a top level key' );
lives_ok{   
    $sliceref =  {
        Helping =>[
            '',
            {
                MyKey =>{
                    MiddleKey =>{
                        LowerKey2 => {},
                    },
                },
            },
        ],
    };
}                                                       'build a $sliceref for testing';
lives_ok{   
    $answerref =  {
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
                    },
                },
            },
        ],
    };
}                                                       '... change the $answerref for testing';
is_deeply(  $edward_scissorhands->prune_data(
                tree_ref    => $treeref, 
                slice_ref   => $sliceref
            ), 
            $answerref,
                                                        'Test pruning a low level key (through an arrayref level)' );
ok( $edward_scissorhands->change_array_size_behavior( 1 ),  
                                                        'Turn on splice removal of array elements');
lives_ok{   
    $sliceref =  {
        Helping =>[
            'Somelevel',
            {
                MyKey =>{
                    MiddleKey =>{
                        LowerKey1 => [],
                    },
                },
            },
        ],
    };
}                                                       '... change the $sliceref for testing';
lives_ok{   
    $answerref =  {
        Parsing =>{
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
                    },
                },
            },
        ],
    };
}                                                       '... change the $answerref for testing';
is_deeply(  $edward_scissorhands->prune_data(
                tree_ref    => $treeref, 
                slice_ref   => $sliceref,
            ), 
            $answerref,                                 'Test pruning (by splice) an array element' );
done_testing;
say ' Test Done';