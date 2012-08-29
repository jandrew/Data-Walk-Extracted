#!perl
#######  Test File for Data::Walk::Graft  #######
BEGIN{
	#~ $ENV{ Smart_Comments } = '###';
}
use Test::Most;
use Test::Moose;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.015;
use Data::Walk::Graft v0.009;
use YAML::Any;

my( 
			$wait, $new_class, $gardener, 
			$tree_ref, $scion_ref, $answer_ref, $answer_two,
);

my  		@methods = qw(
				new
				graft_data
				has_graft_memory
				set_graft_memory
				get_graft_memory
				clear_graft_memory
				number_of_scions
				has_grafted_positions
				get_grafted_positions
			);

my			@attributes = qw(
				graft_memory
			);
    
# basic questions
lives_ok{
			$gardener = with_traits( 
				'Data::Walk::Extracted',
				( 
					'Data::Walk::Clone',
					'Data::Walk::Graft',
					'Data::Walk::Print',
				), 
			)->new();
}										"Prep a new Graft instance";
does_ok		$gardener, 'Data::Walk::Graft',
										"Check that 'with_traits' added the 'Data::Walk::Graft' Role to the instance";
map{
has_attribute_ok
			$gardener, $_,				"Check that the new instance has the -$_- attribute",
}			@attributes;
map{									#Check that the new instance can use all methods
can_ok		$gardener, $_,
}			@methods;

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
}										'Build the $treeref for testing';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'A Different name',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,				'Test grafting a different string in an array element that holds a string';
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
}										'Build another $answerref for testing';
is_deeply	$gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        {
                            Somelevel => 'a_new_value',
                        }
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,				'Test grafting a HashRef in place of a string in an array';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'A Different name',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,				'Test grafting a string in an array element that holds a HashRef';
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
}									'Build another $answerref for testing';
is_deeply	$gardener->graft_data(
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
            $answer_ref,			'Test grafting an ArrayRef in place of a string in an array';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
                scion_ref =>{ 
                    Helping =>[
                        'A Different name',
                    ],
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,				'Test grafting a string in an array element that holds an ArrayRef';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
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
            $answer_ref,				'Test grafting another key/value into a HashRef';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
                scion_ref =>{ 
                    Helping =>{
                        OtherKey => 'Something',
                    },
                }, 
                tree_ref  => $tree_ref,
            ),
            $answer_ref,				'Test grafting a HashRef into the place of an ArrayRef';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
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
            $answer_ref,				'Test grafting more than one key in a HashRef into a HashRef and add another key with an ArrayRef value';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
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
            $answer_ref,				'Test changing Array values while skipping other array values';
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
}										'Build the $answerref for testing';
is_deeply	$gardener->graft_data(
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
            $answer_ref,				'Test the result without a tree_ref';
lives_ok{   
			$tree_ref ={
				branch1 => undef,
				branch2 => {
						subbranch => [],
				},
			};
			$scion_ref ={
				branch1 => [ Test1->new, ],
				branch2 => {
						subbranch => [ bless( [], 'Test2' ), ],
				},
			};
}										'Build multi-layer one shot attribute test';
lives_ok{
			$gardener->set_graft_memory( 1 );
		}								'Set graft memory for the next run';
lives_ok{
			$tree_ref = $gardener->graft_data(
				tree_ref => $tree_ref,
				scion_ref => $scion_ref,
				dont_clone_node_types => [ 'OBJECT',  ],
			);
}										'Run the graft operation to test multi-layer one shot attributes';
is_deeply	$tree_ref, $scion_ref,		'Check for deep matching on the multi-layer test';
isnt		$tree_ref->{branch1}, $scion_ref->{branch1},
										'Check that the separate variables are separate for the multi-layer test';
is			$tree_ref->{branch1}->[0],
			$scion_ref->{branch1}->[0],'Check that the graft did not clone at the first Object in the multi-layer test';
is			$tree_ref->{branch1}->[0],
			$scion_ref->{branch1}->[0],'Check that the graft did not clone at the second Object in the multi-layer test(most critical)';
is_deeply	$gardener->get_grafted_positions, 
			[
				{
					branch2 =>{
						subbranch =>[ bless( [], 'Test2' ), ],
					}
				},
				{
					branch1 => [ Test1->new, ],
				},
			],							'Check to see if the graft memory worked';
lives_ok{   
			$tree_ref ={
				branch2 => {
						subbranch => [ { key => 'value', }, ],
				},
			};
			$scion_ref ={};
			$answer_two = $gardener->deep_clone( $tree_ref );
}										'Build a defacto pruning operation test';
lives_ok{
			$answer_ref = $gardener->graft_data(
				tree_ref => $tree_ref,
				scion_ref => $scion_ref,
			);
}										'Run the graft operation to ensure no defacto pruning occurs';
is_deeply	$answer_ref, $answer_two,	'Check for deep matching on the (excluded) defacto pruning test';
explain 								"...Test Done";
done_testing;

package Test1;
use Moose;

sub new{ 
	return bless {
		attribute_key => 'value',
	}, __PACKAGE__;
}

sub print_something{
	print "something";
}

1;