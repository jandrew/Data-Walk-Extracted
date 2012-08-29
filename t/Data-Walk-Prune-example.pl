#!perl
use Modern::Perl;
use Moose::Util qw( with_traits );
use lib '../lib';
use Data::Walk::Extracted v0.015;
use Data::Walk::Prune v0.007;
use Data::Walk::Print v0.009;

my  $edward_scissorhands = with_traits(
		'Data::Walk::Extracted',
		( 
			'Data::Walk::Prune', 
			'Data::Walk::Print',
		),
	)->new( change_array_size => 1, );#Default
my  $firstref = {
        Helping => [
            'Somelevel',
            {
                MyKey => {
                    MiddleKey => {
                        LowerKey1 => 'low_value1',
                        LowerKey2 => {
                            BottomKey1 => 'bvalue1',
                            BottomKey2 => 'bvalue2',
                        },
                    },
                },
            },
        ],
    };
my	$result = $edward_scissorhands->prune_data(
        tree_ref    => $firstref, 
        slice_ref   => {
            Helping => [
				undef,
                {
                    MyKey => {
                        MiddleKey => {
                            LowerKey1 => {},
                        },
                    },
                },
            ],
        },
    );
$edward_scissorhands->print_data( $result );