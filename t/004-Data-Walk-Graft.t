#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Graft  #######
use Modern::Perl;
use Test::Most;
use Test::Moose;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.007;
use Data::Walk::Graft v0.001;

my  ( $wait, $new_class, $gardener, $tree_ref, $scion_ref, $answer_ref );

my  @methods = qw(
        new
        graft_data
    );
    
# basic questions
lives_ok{
    $new_class = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Graft',  ) );#'Data::Walk::Print'
    $gardener = $new_class->new();
}                                                       "Prep a new Graft instance";
does_ok( $gardener, 'Data::Walk::Graft',     "Check that 'with_traits' added the 'Data::Walk::Graft' Role to the instance");
map can_ok( $gardener, $_ ), @methods;

#Run the hard questions
lives_ok{   
    $tree_ref = {
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
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>[
            'A Different name',
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
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'A Different name',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting a different string in an array element that holds a string' );
lives_ok{   
    $answer_ref ={
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
                Somelevel => 'a_new_value',
            },
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
}                                                       'Build another $answerref for testing';
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        {
                            Somelevel => 'a_new_value',
                        }
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting a HashRef in place of a string in an array' );
lives_ok{   
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>[
            'A Different name',
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
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'A Different name',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting a string in an array element that holds a HashRef' );
lives_ok{   
    $answer_ref = {
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>[
            [
                'My',
                'New',
                'List',
            ],
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
}                                                       'Build another $answerref for testing';
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        [
                            'My',
                            'New',
                            'List',
                        ],
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting an ArrayRef in place of a string in an array' );
lives_ok{   
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>[
            'A Different name',
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
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'A Different name',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting a string in an array element that holds an ArrayRef' );
lives_ok{   
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>[
            'A Different name',
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
                OtherKey => 'Something',
            },
        ],
    };
}                                                       'Build the $answerref for testing';
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'IGNORE',
                        {
                            OtherKey => 'Something',
                        },
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting another key/value into a HashRef' );
lives_ok{   
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>{
            OtherKey => 'Something',
        },
    };
}                                                       'Build the $answerref for testing';
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>{
                        OtherKey => 'Something',
                    },
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting a HashRef into the place of an ArrayRef' );
lives_ok{   
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>{
            KeyTwo => 'A New Value',
            KeyThree => 'Another Value',
            OtherKey => 'Something',
        },
        MyArray =>[
            'ValueOne',
            'ValueTwo',
            'ValueThree',
        ],
    };
}                                                       'Build the $answerref for testing';
is_deeply(  $gardener->graft_data(
                scion_ref =>{ 
                    Helping =>{
                        KeyTwo => 'A New Value',
                        KeyThree => 'Another Value',
                    },
                    MyArray =>[
                        'ValueOne',
                        'ValueTwo',
                        'ValueThree',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test grafting more than one key in a HashRef into a HashRef and add another key with an ArrayRef value' );
lives_ok{   
    $answer_ref ={
        Someotherkey    => 'value',
        Parsing         =>{
            HashRef =>{
                LOGGER =>{
                    run => 'INFO',
                },
            },
        },
        Helping =>{
            KeyTwo => 'A New Value',
            KeyThree => 'Another Value',
            OtherKey => 'Something',
        },
        MyArray => [
            'ValueOne',
            {
                AnotherKey => 'Chicken_Butt!',
            },
            'ValueThree',
            undef,
            'ValueFive',
        ],
    };
}                                                       'Build the $answerref for testing';
is_deeply(  $gardener->graft_data(
                scion_ref =>{
                    MyArray =>[
                        'IGNORE',
                        {
                            AnotherKey => 'Chicken_Butt!',
                        },
                        'IGNORE',
                        'IGNORE',
                        'ValueFive',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,                                 'Test changing Array values while skipping other array values' );
lives_ok{   
    $answer_ref ={
        MyArray => [
            'IGNORE',
            {
                AnotherKey => 'Chicken_Butt!',
            },
            'IGNORE',
            'IGNORE',
            'ValueFive',
        ],
    };
}                                                       'Build the $answerref for testing';
is_deeply(  $tree_ref = $gardener->graft_data(
                scion_ref =>{
                    MyArray =>[
                        'IGNORE',
                        {
                            AnotherKey => 'Chicken_Butt!',
                        },
                        'IGNORE',
                        'IGNORE',
                        'ValueFive',
                    ],
                },
            ),
            $answer_ref,                                 'Test the result without a tree_ref' );
done_testing;
say 'Test Done';