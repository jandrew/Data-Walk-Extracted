#!perl
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted 0.024;
use Data::Walk::Graft 0.024;
use Data::Walk::Print 0.024;

my  $gardener = with_traits( 
        'Data::Walk::Extracted', 
        ( 
            'Data::Walk::Graft', 
			'Data::Walk::Clone',
            'Data::Walk::Print',
        ) 
    )->new(
		sorted_nodes =>{
			HASH => 1,
		},# For demonstration consistency
		#Until Data::Walk::Extracted and ::Graft support these types
		#(watch Data-Walk-Extracted on github)
		skipped_nodes =>{ 
			OBJECT => 1,
			CODEREF => 1,
		},
		graft_memory => 1,
	);
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
            OtherKey => 'Otherthing',
        },
        MyArray =>[
            'IGNORE',
            {
                What => 'Chicken_Butt!',
            },
            'IGNORE',
            'IGNORE',
            'ValueFive',
        ],
    }, 
    tree_ref  => $tree_ref,
);
$gardener->print_data( $tree_ref );
print "Now a list of -" . $gardener->number_of_scions . "- grafted positions\n";
$gardener->print_data( $gardener->get_grafted_positions );