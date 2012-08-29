#! C:/Perl/bin/perl
#######  Test File for Data::Walk::Prune  #######
BEGIN{
	#~ $ENV{ Smart_Comments } = '### #### #####';
}
use Test::Most;
use Test::Moose;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.015;
use Data::Walk::Prune v0.007;

my  ( $wait, $newclass, $edward_scissorhands, $treeref, $sliceref, $answerref );

my  		@methods = qw(
				new
				prune_data
				set_prune_memory
				get_prune_memory
				has_prune_memory
				clear_prune_memory
				get_pruned_positions
				has_pruned_positions
				number_of_cuts
			);

my  		@attributes = qw(
				prune_memory
			);
    
# basic questions
lives_ok{
			$newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Prune', ) );
			$edward_scissorhands = $newclass->new( );# prune_memory => 1, 
}                                       "Prep a new Prune instance";
does_ok		$edward_scissorhands, 'Data::Walk::Prune',
										"Check that 'with_traits' added the 'Data::Walk::Prune' Role to the instance";
map{ 
has_attribute_ok
			$edward_scissorhands, $_,	"Check that the new instance has the -$_- attribute"
} 			@attributes;
map{
can_ok		$edward_scissorhands, $_
}			@methods;

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
}										'Build the $treeref for testing';
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
}										'Build the $answerref for testing';
is_deeply	$edward_scissorhands->prune_data(
                slice_ref 	=> { Someotherkey => {} }, 
                tree_ref	=> $treeref,
            ),
            $answerref,                 'Test pruning a top level key';
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
}										'build a $sliceref for testing';
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
}										'... change the $answerref for testing';
is_deeply	$edward_scissorhands->prune_data(
                tree_ref    => $treeref, 
                slice_ref   => $sliceref
            ), 
            $answerref,					'Test pruning a low level key (through an arrayref level)';
#~ exit 1;
ok			$edward_scissorhands->set_change_array_size( 1 ),
										'Turn on splice removal of array elements';
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
}										'... change the $sliceref for testing';
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
}										'... change the $answerref for testing';
ok 			$edward_scissorhands->set_prune_memory( 1 ),	
										'Turn on prune rememberance';
#~ $ENV{ special_variable } = 1;
is_deeply	$edward_scissorhands->prune_data(
                tree_ref    => $treeref, 
                slice_ref   => $sliceref,
            ), 
            $answerref,					'Test pruning (by splice) an array element';
lives_ok{   
			$sliceref =  {
				Helping =>[
					undef,
					{
						MyKey =>{
							MiddleKey =>{
								LowerKey1 => {},
							},
						},
					},
				],
			};
}										'... change the $sliceref for testing';
ok 			$edward_scissorhands->has_pruned_positions,
										'See if any slices were remembered';
is 			$edward_scissorhands->number_of_cuts, 1,
										'Count the number of cuts';
is_deeply	$edward_scissorhands->get_pruned_positions, 
			[ $sliceref ],				'Check that the expected prune branch is available';
done_testing;
explain 								"...Test Done";