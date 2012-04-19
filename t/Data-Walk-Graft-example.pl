#! C:/Perl/bin/perl
use Modern::Perl;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.007;
use Data::Walk::Graft v0.001;
use Data::Walk::Print v0.007;

my  $gardener = with_traits( 
        'Data::Walk::Extracted', 
        ( 
            'Data::Walk::Graft', 
            'Data::Walk::Print' 
        ) 
    )->new();
my  $tree_ref = {
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
$gardener->graft_data(
    scion_ref =>{
        Helping =>{
            OtherKey => 'Something',
        },
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
);
$gardener->print_data( $tree_ref );
