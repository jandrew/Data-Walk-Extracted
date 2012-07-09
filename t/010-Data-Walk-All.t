#! C:/Perl/bin/perl
#######  Test File for the joining of all Data::Walk::XXX modules  #######

use Test::Most;
use Test::Moose;
use Moose::Util qw( with_traits );
use lib '../lib', 'lib';
use Data::Walk::Extracted v0.011;
use Data::Walk::Print v0.009;
use Data::Walk::Prune v0.007;
use Data::Walk::Clone v0.003;
use Data::Walk::Graft v0.007;

my  ( 
			$wait,
			$anonymous,
);

my  		@attributes = qw(
				sort_HASH
				sort_ARRAY
				skip_HASH_ref
				skip_ARRAY_ref
				skip_SCALAR_ref
				change_array_size
				match_highlighting
				prune_memory
				clone_level
				skip_clone_tests
				should_clone
				graft_memory
			);

my  		@methods = qw(
				new
				print_data
				set_match_highlighting
				get_sort_HASH
				get_sort_ARRAY
				get_skip_HASH_ref
				get_skip_ARRAY_ref
				get_skip_SCALAR_ref
				set_sort_HASH
				set_sort_ARRAY
				set_skip_HASH_ref
				set_skip_ARRAY_ref
				set_skip_SCALAR_ref
				clear_sort_HASH
				clear_sort_ARRAY
				clear_skip_HASH_ref
				clear_skip_ARRAY_ref
				clear_skip_SCALAR_ref
				has_sort_HASH
				has_sort_ARRAY
				has_skip_HASH_ref
				has_skip_ARRAY_ref
				has_skip_SCALAR_ref
				set_change_array_size
				get_change_array_size
				has_change_array_size
				clear_change_array_size
				set_match_highlighting
				get_match_highlighting
				has_match_highlighting
				clear_match_highlighting
				prune_data
				set_prune_memory
				get_prune_memory
				has_prune_memory
				clear_prune_memory
				get_pruned_positions
				has_pruned_positions
				number_of_cuts
				deep_clone
				has_clone_level
				get_clone_level
				set_clone_level
				clear_clone_level
				get_skip_clone_tests
				clear_skip_clone_tests
				add_skip_clone_test
				has_skip_clone_tests
				set_skip_clone_tests
				set_should_clone
				get_should_clone
				has_should_clone
				clear_should_clone
				graft_data
				has_graft_memory
				set_graft_memory
				get_graft_memory
				clear_graft_memory
				number_of_scions
				has_grafted_positions
				get_grafted_positions
			);
    
# basic questions
lives_ok{
			$anonymous = with_traits( 
				'Data::Walk::Extracted', 
					( 
						'Data::Walk::Clone', 
						'Data::Walk::Print',
						'Data::Walk::Prune',
						'Data::Walk::Graft',
					) 
			)->new();
}										"Prep a new instance with all roles!";
#~ does_ok	$anonymous, 'Data::Walk::Clone',
														#~ "Check that 'with_traits' added the 'Data::Walk::Clone' Role to the instance";
map{
has_attribute_ok
			$anonymous, $_, 			"Check that master instance has the -$_- attribute"
} 			@attributes;
map{
can_ok		$anonymous, $_
}			@methods;
explain 								"...Test Done";
done_testing;