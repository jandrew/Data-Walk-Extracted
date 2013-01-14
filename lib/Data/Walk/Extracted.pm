package Data::Walk::Extracted;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use Class::Inspector;
use Scalar::Util qw( reftype );
use version; our $VERSION = qv('0.019_005');
use Carp qw( confess );
use MooseX::Types::Moose qw(
        ArrayRef
        HashRef
        Object
        CodeRef
        Str
        Int
        Bool
    );
use lib '../../../lib';
if( $ENV{ Smart_Comments } ){
	use Smart::Comments -ENV;
	### Smart-Comments turned on for Data-Walk-Extracted ...
}
use Data::Walk::Extracted::Types 0.001 qw(
		posInt
	);
with 'Data::Walk::Extracted::Dispatch' =>{ -VERSION => 0.001 };

#########1 Package Variables  3#########4#########5#########6#########7#########8#########9

$| = 1;
my 	$wait;
my 	$data_key_tests = {
		required => [ qw(
			primary_ref
		) ],
		at_least_one => [ qw(
			before_method
			after_method
		) ],
		all_possibilities => {
			secondary_ref => 1,
			branch_ref => 1,
		},
	};
# Adding elements from the firts two keys to all ...
for my $key ( @{$data_key_tests->{required}}, @{$data_key_tests->{at_least_one}} ){
	$data_key_tests->{all_possibilities}->{$key} = 1;
}
my	$base_type_ref ={
		SCALAR => 1,
		UNDEF => 1,
	};

my	@data_key_list = qw(
		primary_ref
		secondary_ref
	);

my	@lower_key_list = qw(
		primary_type
		secondary_type
		match
		skip
	);

# This is also the order of type investigaiton testing
# This is the maximum list of types -but-
# if the types are also not listed in the appropriate dispatch 
# tables, then it still won't parse
my 	$supported_type_list = [ qw(
		UNDEF SCALAR CODEREF OBJECT ARRAY HASH
	) ];######<------------------------------------------------------  ADD New types here

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9

my  $node_list_dispatch = {######<----------------------------------  ADD New types here
		name 		=> '- Extracted - node_list_dispatch',#Meta data
		HASH		=> sub{ [ keys %{$_[1]} ] },
		ARRAY		=> sub{
			my $list;
			map{ push @$list, 1 } @{$_[1]};
			return $list;
		},
		SCALAR		=> sub{ [ $_[1] ] },
		OBJECT		=> \&_get_object_list,
		###### Receives: a data reference or scalar
		###### Returns: an array reference of list items
	};
	
my 	$main_down_level_data ={
		###### Purpose: Used to build the generic elements of the next passed ref down
		###### Recieves: the upper ref value
		###### Returns: the lower ref value or undef
		name => '- Extracted - main down level data',
		DEFAULT => sub{ undef },
		before_method => sub{ return $_[1] },
		after_method => sub{ return $_[1] },
		branch_ref => \&_main_down_level_branch_ref,
	};

my	$down_level_tests_dispatch ={
		###### Purpose: Used to test the down level item elements
		###### Recieves: the lower ref
		###### Returns: the lower level test result
		name => '- Extracted - item down level data',
		primary_type => &_item_down_level_type( 'primary_ref' ),
		secondary_type => &_item_down_level_type( 'secondary_ref' ),
		match => \&_ref_matching,
		skip => \&_will_parse_next_ref,
	};

my  $sub_ref_dispatch = {######<------------------------------------  ADD New types here
		name	=> '- Extracted - sub_ref_dispatch',#Meta data
		HASH	=> sub{ return $_[1]->{$_[2]} },
		ARRAY	=> sub{ return $_[1]->[$_[3]] },
		SCALAR	=> sub{ return undef; },
		OBJECT	=> \&_get_object_element,
		###### Receives: a upper data reference, an item, and a position
		###### Returns: a lower array reference 
	};

my 	$discover_type_dispatch = {######<-------------------------------  ADD New types here
		UNDEF		=> sub{ !$_[1] },
		SCALAR		=> sub{ is_Str( $_[1] ) },
		ARRAY		=> sub{ is_ArrayRef( $_[1] ) },
		HASH		=> sub{ is_HashRef( $_[1] ) },
		OBJECT		=> sub{ is_Object( $_[1] ) },
		CODEREF		=> sub{ is_CodeRef( $_[1] ) },
	};

my 	$secondary_match_dispatch = {######<-----------------------------  ADD New types here
		name	=> '- Extracted - secondary_match_dispatch',#Meta data
		DEFAULT	=> 	sub{ return 'YES' },
		SCALAR	=> sub{
			return ( $_[1]->{primary_ref} eq $_[1]->{secondary_ref} ) ?
				'YES' : 'NO' ;
		},
		OBJECT	=> sub{
			return ( ref( $_[1]->{primary_ref} ) eq ref( $_[1]->{secondary_ref} ) ) ?
				'YES' : 'NO' ;
		},
		###### Receives: the next $passed_ref, the item, and the item postion
		###### Returns: YES or NO
		######	Non-existent and non matching lower ref types should have already been eliminated
	};

my 	$up_ref_dispatch = {######<--------------------------------------  ADD New types here
		name 	=> '- Extracted - up_ref_dispatch',#Meta data
		HASH	=> \&_load_hash_up,
		ARRAY 	=> \&_load_array_up,
		SCALAR	=> sub{
			### <where> - made it to SCALAR ref upload ...
			$_[3]->{$_[1]} = $_[2]->[1];
			### <where> - returning: $_[3]
			return $_[3];
		},
		OBJECT	=> \&_load_object_up,
		###### Receives: the data ref key, the lower branch_ref element, 
		######				and the upper and lower data refs
		###### Returns: the upper data ref
	};

my	$object_extraction_dispatch ={######<----------------------------  ADD New types here
		name	=> '- Extracted - object_extraction_dispatch',
		HASH	=> sub{ return {%{$_[1]}} },
		ARRAY	=> sub{ return [@{$_[1]}] },
		DEFAULT => sub{ return ${$_[1]} },
		###### Receives: an object reference
		###### Returns: a reference or string of the blessed data in the object
	};

my	$secondary_ref_exists_dispatch ={######<-------------------------  ADD New types here
		name => '- Extracted - secondary_ref_exists_dispatch',
		HASH => sub{
			### <where> - passed: @_
			exists $_[1]->{secondary_ref} and
			is_HashRef( $_[1]->{secondary_ref} ) and
			exists $_[1]->{secondary_ref}->{$_[2]} 
		},
		ARRAY => sub{ 
			exists $_[1]->{secondary_ref} and
			is_ArrayRef( $_[1]->{secondary_ref} ) and
			exists $_[1]->{secondary_ref}->[$_[3]]
		},
		SCALAR => sub{ exists $_[1]->{secondary_ref} },
	###### Receives: the upper ref, the current list item, and the current position
	###### Returns: pass or fail (pass means continue)
	};

my  $reconstruction_dispatch = {######<-----------------------------  ADD New types here
		name 	=> 'reconstruction_dispatch',#Meta data
		HASH	=> \&_rebuild_hash_level,
		ARRAY 	=> \&_rebuild_array_level,
	};

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9

has 'sorted_nodes' =>(
	is		=> 'ro',
	isa		=> HashRef,
	traits	=> ['Hash'],
	default	=> sub{ {} },
    handles	=> {
        add_sorted_nodes	=> 'set',
		has_sorted_nodes	=> 'count',
		check_sorted_node	=> 'exists',
		clear_sorted_nodes	=> 'clear',
		remove_sorted_node	=> 'delete',
		_retrieve_sorted_nodes => 'get',
    },
	writer		=> 'set_sorted_nodes',
	reader		=> 'get_sorted_nodes',
);

has 'skipped_nodes' =>(
	is		=> 'ro',
	isa		=> HashRef,
	traits	=> ['Hash'],
	default	=> sub{ {} },
    handles	=> {
        add_skipped_nodes	=> 'set',
		has_skipped_nodes	=> 'count',
		check_skipped_node	=> 'exists',
		clear_skipped_nodes	=> 'clear',
		remove_skipped_node	=> 'delete',
    },
	writer		=> 'set_skipped_nodes',
	reader		=> 'get_skipped_nodes',
);

has 'skip_level' =>(
	is			=> 'ro',
	isa			=> Int,
	predicate	=> 'has_skip_level',
	reader		=> 'get_skip_level',
	writer		=> 'set_skip_level',
	clearer		=> 'clear_skip_level',
);

has 'skip_node_tests' =>(
	is		=> 'ro',
	isa		=> ArrayRef[ArrayRef],
	traits	=> ['Array'],
	reader	=> 'get_skip_node_tests',
	writer	=> 'set_skip_node_tests',
	default	=> sub{ [] },
    handles => {
        add_skip_node_test		=> 'push',
		has_skip_node_tests		=> 'count',
		clear_skip_node_tests	=> 'clear',
    },
);

has 'change_array_size' =>(
    is      	=> 'ro',
    isa     	=> Bool,
	predicate	=> 'has_change_array_size',
	reader		=> 'get_change_array_size',
	writer		=> 'set_change_array_size',
	clearer		=> 'clear_change_array_size',
    default 	=> 1,
);

has 'fixed_primary' =>(
    is      	=> 'ro',
    isa     	=> Bool,
	predicate	=> 'has_fixed_primary',
	reader		=> 'get_fixed_primary',
	writer		=> 'set_fixed_primary',
	clearer		=> 'clear_fixed_primary',
    default 	=> 0,
);

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has '_current_level' =>(
	is			=> 'ro',
	isa			=> posInt,
	default		=> 0,
	writer		=> '_set_current_level',
	reader		=> '_get_current_level',
);

has '_had_secondary' =>(
    is			=> 'ro',
    isa     	=> Bool,
	writer		=> '_set_had_secondary',
	reader		=> '_get_had_secondary',
	predicate	=> '_has_had_secondary',
    default		=> 0,
);

sub _clear_had_secondary{
	my ( $self, ) = @_;
	### <where> - setting _had_secondary to 0 ...
	$self->_set_had_secondary( 0 );
	return 1;
}

has '_single_pass_attributes' =>(
	is		=> 'ro',
	isa		=> ArrayRef[HashRef],
	traits	=> ['Array'],
	default	=> sub{ [] },
    handles => {
		_levels_of_saved_attributes	=> 'count',
		_add_saved_attribute_level => 'push',
		_get_saved_attribute_level => 'pop',
    },
);

#########1 Methods for Roles  3#########4#########5#########6#########7#########8#########9

sub _process_the_data{#Used to scrub high level input
    ### <where> - Made it to _process_the_data
    ##### <where> - Passed input  : @_
    my ( $self, $passed_ref, $conversion_ref, ) = @_;
    ### <where> - review the ref keys for requirements and conversion ...
	my $return_conversion;
	( $passed_ref, $return_conversion ) = 
		$self->_convert_data( $passed_ref, $conversion_ref );
	#### <where> - new passed_ref: $passed_ref
	$self->_has_required_inputs( $passed_ref, $return_conversion );
	$passed_ref = $self->_has_at_least_one_input( $passed_ref, $return_conversion );
	$passed_ref = $self->_manage_the_rest( $passed_ref );
	##### <where> - Start recursive parsing with: $passed_ref
	my $return_ref = $self->_walk_the_data( $passed_ref );
    ### <where> - convert the data keys back to the role names
	( $return_ref, $conversion_ref ) = 
		$self->_convert_data( $return_ref, $return_conversion );
    ### <where> - restoring instance clone attributes as needed ...
	$self->_restore_attributes;
	$self->_clear_had_secondary;
	##### <where> - End recursive parsing with: $return_ref
    return $return_ref;
}

sub _build_branch{
    my ( $self, $base_ref, @arg_list ) = @_;
    ## <where> - Made it to _build_branch ...
    ### <where> - base ref : $base_ref
    ##### <where> - the passed arguments  : @arg_list
	if( $arg_list[-1]->[3] == 0 ){
		### <where> - zeroth level found: @arg_list
		return $base_ref;
	}elsif( @arg_list ){
        my $current_ref  = pop @arg_list;
		$base_ref = $self->_dispatch_method( 
			$reconstruction_dispatch , 
			$current_ref->[0], 
			$current_ref, 
			$base_ref,
		);
		my $answer = $self->_build_branch( $base_ref, @arg_list );
		### <where> - back up with : $answer
        return $answer;
    }else{
		### <where> - reached the bottom - returning: $base_ref
		return $base_ref;
    }
	
}

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _walk_the_data{
    my( $self, $passed_ref ) = @_;
    ### <where> - Made it to _walk_the_data
    ##### <where> - Passed input  : $passed_ref
	### <where> - running the before_method ...
	if( exists $passed_ref->{before_method} ){
		my  $before_method = $passed_ref->{before_method};
		### <where> - role has a before_method: $before_method
		$passed_ref = $self->$before_method( $passed_ref );
		### <where> - completed before_method
		#### <where> - the current passed ref is: $passed_ref
	}else{
		### <where> - No before_method found
	}
    ### <where> - See if the node should be parsed ...
	my $list_ref;
    if(	$passed_ref->{skip} eq 'YES' ){
		### <where> - Skip condition identified ...
	}elsif( exists $base_type_ref->{$passed_ref->{primary_type}} ){
		### <where> - base type identified as: $passed_ref->{primary_type}
	}else{
		### <where> - get the lower ref list ...
		$list_ref = $self->_dispatch_method( 
						$node_list_dispatch,
						$passed_ref->{primary_type},
						$passed_ref->{primary_ref},
					);
		### <where> - sorting the list as needed for: $list_ref
		if(	$self->check_sorted_node( $passed_ref->{primary_type} ) ){
			### <where> - The list should be sorted ...
			my $sort_function =  
				( is_CodeRef(  
					$self->_retrieve_sorted_nodes( $passed_ref->{primary_type} ) 
				) ) ? ######## ONLY PARTIALLY TESTED !!!! ######
					$self->_retrieve_sorted_nodes( $passed_ref->{primary_type} ) : 
					sub{ $a cmp $b } ;
			$list_ref = [ sort $sort_function @$list_ref ];
			if( $passed_ref->{primary_type} eq 'ARRAY' ){
				### <where> - This is an array ref and the array ref will be sorted ...
				$passed_ref->{primary_ref} = 
					[sort $sort_function @{$passed_ref->{primary_ref}}];
			}
			##### <where> - sorted list: $list_ref
		}
	}
	if( $list_ref ){
		### <where> - climbing up the node tree ... 
		#### <where> - running the list: $list_ref
		$self->_set_current_level( 1 + $self->_get_current_level );
		#### <where> - new current level: $self->_get_current_level
		my	$lower_ref = $self->_down_load_general( $passed_ref );
		#### <where> - the core lower ref is: $lower_ref
		my	$x = 0;
		for my $item ( @{$list_ref} ){
			### <where> - now parsing: $item
			delete $lower_ref->{secondary_ref};
			$lower_ref = 	$self->_get_lower_refs( 
								$passed_ref, $lower_ref, $item,
								$x, $self->_get_current_level,
							);
			#### <where>- lower ref: $lower_ref
			for my $key ( @lower_key_list ){
				### <where> - working to load: $key
				$lower_ref->{$key} = $self->_dispatch_method(
					$down_level_tests_dispatch, $key, $lower_ref, 
				);
			}
			##### <where> - walking the data: $lower_ref
			$lower_ref = $self->_walk_the_data( $lower_ref );
			my	$old_branch_ref = pop @{$lower_ref->{branch_ref}};
			### <where> - pass any data reference adjustments upward ...
			#### <where> - using branch ref: $old_branch_ref
			for my $key ( @data_key_list ){
				### <where> - processing: $key
				if( $key eq 'primary_ref' and
					$self->has_fixed_primary and
					$self->get_fixed_primary 		){
					### <where> - the primary ref is fixed and no changes will be passed upwards ...
				}elsif( exists $lower_ref->{$key} 	){
					### <where> - a lower ref was identified and will be passed upwards for: $key
					$passed_ref = $self->_dispatch_method(
						$up_ref_dispatch,
						$old_branch_ref->[0],
						$key,
						$old_branch_ref,
						$passed_ref,
						$lower_ref,
					);
				}
				#### <where> - new passed ref: $passed_ref
			}
			$x++;
		}
		### <where> - climbing back down the node tree ...
		#### <where> - current level: $self->_get_current_level
		$self->_set_current_level( -1 + $self->_get_current_level );
	}
    
	### <where> - running the after_method ...
    if( exists $passed_ref->{after_method} ){
        my $after_method = $passed_ref->{after_method};
        ### <where> - role has an after_method: $after_method
        $passed_ref = $self->$after_method( $passed_ref );
        #### <where> - returned from after_method: $passed_ref
    }else{
        ### <where> - No after_method found
    }
    #### <where> - returning passedref: $passed_ref
    return $passed_ref;
}

sub _convert_data{
	my ( $self, $passed_ref, $conversion_ref, ) = @_;
	### <where> - reached _convert_data ...
	#### <where> - conversion ref: $conversion_ref
	#### <where> - passed ref: $passed_ref
	for my $key ( keys %$conversion_ref ){
		if( exists $passed_ref->{$key} ){
			$passed_ref->{$conversion_ref->{$key}} = 
				( $passed_ref->{$key} ) ? 
					$passed_ref->{$key} : undef;
			delete $passed_ref->{$key};
		}
	}
	### <where> - inverting conversion ref ...
	my  $return_conversion = { reverse %$conversion_ref };
	### <where> - passed ref now equals: $passed_ref
	return( $passed_ref, $return_conversion );
}

sub _has_required_inputs{
    my ( $self, $passed_ref, $lookup_ref, ) = @_;
    ### <where> - Made it to _has_required_inputs ...
	##### <where> - Passed ref: $passed_ref
    ##### <where> - Lookup ref: $lookup_ref
    for my $key ( @{$data_key_tests->{required}} ){
		if( !exists $passed_ref->{$key} ){
			confess '-' . 
			( ( exists $lookup_ref->{$key} ) ? $lookup_ref->{$key} : $key ) .
			'- is a required key but was not found in the passed ref';
		}
	}
	return 1;
}

sub _has_at_least_one_input{
    my ( $self, $passed_ref, $lookup_ref ) = @_;
    ### <where> - Made it to _has_at_least_one_input ...
    ##### <where> - Passed ref: $passed_ref
    ##### <where> - Lookup ref: $lookup_ref
	my $count;
    for my $key ( @{$data_key_tests->{at_least_one}} ){
		if( !exists $passed_ref->{$key} ){
			push @{$count->{missing}}, ( 
				( exists $lookup_ref->{$key} ) ?
					$lookup_ref->{$key} : $key 
			);
		}elsif( defined $passed_ref->{$key} ){
			$count->{found}++;
		}else{
			push @{$count->{empty}}, ( 
				( exists $lookup_ref->{$key} ) ?
					$lookup_ref->{$key} : $key 
			);
			delete $passed_ref->{$key};
		}
	}
	if( $count->{found} ){
		return $passed_ref;
	}elsif( exists $count->{empty} ){
		confess '-' . (join '- and -', @{$count->{empty}} ) . 
			'- must have values for the key(s)';
	}else{
		confess 'One of the keys -' . (join '- or -', @{$count->{missing}} ) . 
			'- must be provided with values';
	}
}

sub _manage_the_rest{
    my ( $self, $passed_ref ) = @_;
    ### <where> - Made it to _manage_the_rest ...
    ##### <where> - Passed ref: $passed_ref
	### <where> - load a passed branch_ref ...
	$passed_ref->{branch_ref} =	$self->_main_down_level_branch_ref( 
									$passed_ref->{branch_ref}
								);
	### <where> - handle one shot attributes ...
	my $attributes_at_level = {};
	for my $key ( keys %$passed_ref ){
		if( exists $data_key_tests->{all_possibilities}->{$key} ){
			### <where> - found standard key: $key
		}elsif( $self->meta->find_attribute_by_name( $key )  ){
			### <where> - found an attribute: $key
			$key =~ /^(_)?([^_].*)/;
			my ( $predicate, $writer, $reader, $clearer ) =
					( "has_$2", "set_$2", "get_$2", "clear_$2", );
			if( defined $1 ){
				( $predicate, $writer, $reader, $clearer ) =
					( "_$predicate", "_$writer", "_$reader", "_$clearer" );
			}
			### <where> - Testing for attribute use as a "one-shot" attribute ...
			for my $method ( $predicate, $reader, $writer, $clearer ){
				if( $self->can( $method ) ){
					### <where> - so far so good for: $method
				}else{
					confess "-$method- is not supported for key -$key- " .
						"so one shot attribute test failed";
				}
			}
			### <where> - First save the old settings ...
			$attributes_at_level->{$key} = ( $self->$predicate ) ? 
				$self->$reader : undef;
			### <where> - load the new settings: $passed_ref->{$key}
			$self->$writer( $passed_ref->{$key} );
			delete $passed_ref->{$key};
		}else{
			confess "-$key- is not an accepted hash key value";
		}
	}
	#### <where> - attribute storage: $attributes_at_level
	$self->_add_saved_attribute_level( $attributes_at_level );
	### <where> - setting the secondary flag as needed ...
	if( exists $passed_ref->{secondary_ref} ){
		$self->_set_had_secondary( 1 );
	}
	### <where> - setting the remaining keys ...
	for my $key ( @lower_key_list ){
		### <where> - working to load: $key
		$passed_ref->{$key} =	$self->_dispatch_method(
			$down_level_tests_dispatch, $key, $passed_ref, 
		);
	}
	#### <where> - current passed ref: $passed_ref
	##### <where> - self: $self
    return $passed_ref;
}

sub _main_down_level_branch_ref{
    my ( $self, $value ) = @_;
    ### <where> - reached _main_down_level_branch_ref ...
	$value //= [ [ 'SCALAR', undef, 0, 0, ] ];
	#### <where> - using: $value
	my	$return;
	map{ push @$return, $_ } @$value;
	### <where> - returning: $return
	return $return;
}

sub _get_object_list{
    my ( $self, $data_reference ) = @_;
    ### <where> - Made it to _get_object_list ...
	##### <where> - passed reference: $data_reference
	my $list_ref;
	if( scalar( @{$self->_get_object_attributes( $data_reference )} ) ){
		### <where> - found attributes ...
		push @$list_ref, 'attributes';
	}
	if( scalar( @{$self->_get_object_methods( $data_reference )} ) ){
		### <where> - found methods ...
		push @$list_ref, 'methods';
	}
	### <where> - final list: $list_ref
	return $list_ref;
}

sub _down_load_general{
	my( $self, $upper_ref, ) = @_;
	### <where> - reached _down_load_general ...
	#### <where> - upper ref: $upper_ref
	my $lower_ref;
	for my $key ( keys %$upper_ref ){
		my $return = 	$self->_dispatch_method(
							$main_down_level_data, $key, $upper_ref->{$key},
						);
		$lower_ref->{$key} = $return if defined $return;
	}
	#### <where> - returning lower_ref: $lower_ref
	return $lower_ref;
}

sub _restore_attributes{
    my ( $self, ) = @_;
	my ( $answer, ) = (0, );
    ### <where> - reached _restore_attributes ...
	my 	$attribute_ref = $self->_get_saved_attribute_level;
	for my $attribute ( keys %$attribute_ref ){
		### <where> - restoring: $attribute
		$attribute =~ /^(_)?([^_].*)/;
		my ( $writer, $clearer ) = ( "set_$2", "clear_$2", );
		if( defined $1 ){
			( $writer, $clearer ) = ( "_$writer", "_$clearer" );
		}
		### <where> - possible clearer: $clearer
		### <where> - possible writer: $writer
		$self->$clearer;
		if( defined $attribute_ref->{$attribute} ){
			### <where> - resetting attribute value: $attribute_ref->{$attribute}
			$self->$writer( $attribute_ref->{$attribute} );
		}
		### <where> - finished restoring: $attribute
	}
	return 1;
}

sub _item_down_level_type{
	my ( $key	) = @_;
	return sub{ 
		my ( $self, $passed_ref, ) = @_;
		return $self->_extracted_ref_type(
			$key, $passed_ref,
		);
	}
}

sub _extracted_ref_type{
    my ( $self, $ref_key, $passed_ref, ) = @_;
    ### <where> - made it to _extracted_ref_type ...
    my $ref_type;
	if( exists $passed_ref->{$ref_key} ){
		$ref_type = ref $passed_ref->{$ref_key};
		if( exists $discover_type_dispatch->{$ref_type} ){
			### <where> - confirmed ref: $ref_type
		}else{
			CHECKALLTYPES: for my $key ( @$supported_type_list ){
				### <where> - testing: $key
				if( $self->_dispatch_method( 
						$discover_type_dispatch,
						$key,
						$passed_ref->{$ref_key},
					) 							){
					### <where> - found a match for: $key
					$ref_type = $key;
					last CHECKALLTYPES;
				}
				### <where> - no match ...
			}
		}
	}else{
		$ref_type = 'DNE';
	}
	##### <where> - ref type is: $ref_type
	if( !$ref_type ){
		confess "Attempting to parse the unsupported node type -" .
			( ref $passed_ref ) . "-";
	}
    ### <where> - returning: $ref_type
    return $ref_type;
}

sub _ref_matching{
	my ( $self, $passed_ref, ) = @_;
	### <where> - reached _ref_matching ...
	### <where> - matching for type: $passed_ref->{branch_ref}->[-1]->[0]
	##### <where> - passed items: @_
	my	$match = 'NO';
	if( $passed_ref->{secondary_type} eq 'DNE' ){
		### <where> - nothing to match ...
	}elsif( $passed_ref->{secondary_type} ne $passed_ref->{primary_type} ){
		### <where> - failed a type match ...
	}else{
		### <where> - The obvious match issues pass - testing deeper ...
		$match = $self->_dispatch_method(
			$secondary_match_dispatch, $passed_ref->{primary_type},
			$passed_ref, @{$passed_ref->{branch_ref}->[-1]}[1,2],
		);
	}
	### <where> - returning: $match
	return $match;
}

sub _will_parse_next_ref{
    my ( $self, $passed_ref, ) = @_;
    ### <where> - Made it to _will_parse_next_ref ...
    #### <where> - Passed ref: $passed_ref
	my  $skip = 'NO';
	if(	$self->has_skipped_nodes and
		$self->check_skipped_node( $passed_ref->{primary_type} ) ){
		### <where> - skipping the current nodetype: $passed_ref->{primary_type}
		$skip = 'YES';
	}elsif($self->has_skip_level and
			$self->get_skip_level == 
			( ( $passed_ref->{branch_ref}->[-1]->[3] ) + 1 ) ){
		### <where> - skipping the level: ( $passed_ref->{branch_ref}->[-1]->[3] + 1 )
		$skip = 'YES';
	}elsif( $self->has_skip_node_tests ){
		my	$current_branch = $passed_ref->{branch_ref}->[-1];
		### <where> - found skip tests: $self->get_skip_node_tests
		SKIPNODE: for my $test ( @{$self->get_skip_node_tests} ){
			### <where> - running test: $test
			$skip = $self->_general_skip_node_test( 
						$test, $current_branch,
					);
			last SKIPNODE if $skip eq 'YES';
		}
	}
	### <where> - returning skip eq: $skip
	return $skip;
}

sub _general_skip_node_test{
    my ( $self, $test_ref, $branch_ref, ) = @_;
	my	$match_level= 0;
    ### <where> - reached _general_skip_node_test ...
	### <where> - test_ref: $test_ref
	### <where> - branch_ref: $branch_ref
	my $item = $branch_ref->[1];
	### <where> - item: $item
	$match_level++ if
		(	$test_ref->[0] eq $branch_ref->[0] );
	### <where> - match level after type match: $match_level
	$match_level++ if
		( 
			( $test_ref->[1] eq 'ARRAY' ) or
			( $test_ref->[1] =~ /^(any|all)$/i	) or
			( $item and
				( 	
					$test_ref->[1] eq $item or
					$test_ref->[1] =~ /$item/		
				) 	
			)
		);
	### <where> - match level after item match: $match_level
	$match_level++ if
		(	$test_ref->[2] =~ /^(any|all)$/i or
			( 	is_Num( $test_ref->[2] ) and 
				$test_ref->[2] == $branch_ref->[2] ) );
	### <where> - match level after position match: $match_level
	$match_level++ if
		(	$test_ref->[3] =~ /^(any|all)$/i or
			( 	is_Num( $test_ref->[3] ) and 
				$test_ref->[3] == $branch_ref->[3] ) );
	### <where> - match level after depth match: $match_level
	my	$answer = ( $match_level == 4 ) ? 'YES' : 'NO' ;
	### <where> - answer: $answer
	return $answer;
}

sub _get_lower_refs{
	my ( $self, $upper_ref, $lower_ref, $item, $position, $level ) = @_;
	### <where> - reached _get_lower_refs ...
	##### <where> - passed: @_
	for my $key ( @data_key_list ){
		### <where> - running key: $key
		my $test = 1;
		if( $key eq 'secondary_ref' ){
			###<where> - secondary ref check ...
			$test = $self->_dispatch_method(
						$secondary_ref_exists_dispatch,
						$upper_ref->{primary_type},
						$upper_ref, $item, $position,
					);
			### <where> - secondary ref exists result: $test
		}
		if(	$test ){
			### <where> - loading lower ref needed ...
			$lower_ref->{$key} = $self->_dispatch_method(
				$sub_ref_dispatch,
				$upper_ref->{primary_type},
				$upper_ref->{$key}, $item, $position,
			);
		}
		##### <where> - lower_ref: $lower_ref
	}
	push @{$lower_ref->{branch_ref}}, [
		$upper_ref->{primary_type},
		$item, $position, $level,
	];
	#### <where> - returning: $lower_ref
	return $lower_ref;
}

sub _get_object_element{
    my ( $self, $data_reference, $item, $position, ) = @_;
    ### <where> - Made it to _get_object_attributes ...
	#### <where> - data reference: $data_reference
	#### <where> - data reference: $item
	#### <where> - data reference: $position
	my $item_ref;
	if( $item eq 'attributes' ){
		my $scalar_util_val = reftype( $data_reference );
		$scalar_util_val //= 'DEFAULT';
		### <where> - Scalar-Util-reftype: $scalar_util_val
		$item_ref = $self->_dispatch_method(
			$object_extraction_dispatch,
			$scalar_util_val,
			$data_reference,
		);
	}if( $item eq 'methods' ){
		$item_ref = Class::Inspector->function_refs( 
			ref $data_reference 
		);
	}else{
		confess "Get -$item- element not written yet";
	}
	### <where> - the attribute list is: $item_ref
	return $item_ref;
}

sub _load_hash_up{
    my ( $self, $key, $branch_ref_item, $passed_ref, $lower_passed_ref, ) = @_;
    ### <where> - Made it to _load_hash_up for the: $key
	### <where> - the branch ref is: $branch_ref_item
	##### <where> - passed info: @_
	$passed_ref->{$key}->{$branch_ref_item->[1]} = 
		$lower_passed_ref->{$key};
	##### <where> - the new passed_ref is: $passed_ref
	return $passed_ref;
}

sub _load_array_up{
    my ( $self, $key, $branch_ref_item, $passed_ref, $lower_passed_ref, ) = @_;
    ### <where> - Made it to _load_array_up for the: $key
	### <where> - the branch ref is: $branch_ref_item
	##### <where> - lower ref: $lower_passed_ref
	$passed_ref->{$key}->[$branch_ref_item->[2]] = 
		$lower_passed_ref->{$key};
	##### <where> - the new passed_ref is: $passed_ref
	return $passed_ref;
}

sub _rebuild_hash_level{
    my ( $self, $item_ref, $base_ref, ) = @_;
    ### <where> - Made it to _rebuild_hash_level
    ### <where> - item ref  : $item_ref
    ### <where> - base ref  : $base_ref
	return { $item_ref->[1] => $base_ref };
}

sub _rebuild_array_level{
    my ( $self, $item_ref, $base_ref, ) = @_;
    ### <where> - Made it to _rebuild_array_level
    ### <where> - item ref  : $item_ref
    ### <where> - base ref  : $base_ref
	my  $array_ref = [];
	$array_ref->[$item_ref->[2]] = $base_ref;
	return $array_ref;
}

#########1 Phinish Strong     3#########4#########5#########6#########7#########8#########9

no Moose;
__PACKAGE__->meta->make_immutable;

1;
# The preceding line will help the module return a true value

#########1 Main POD starts    3#########4#########5#########6#########7#########8#########9

__END__

=head1 NAME

Data::Walk::Extracted - An extracted dataref walker

=head1 SYNOPSIS

This is a contrived example!  For more functional (complex/useful) examples see the 
roles in this package.

	package Data::Walk::MyRole;
	use Moose::Role;
	requires '_process_the_data';
	use MooseX::Types::Moose qw(
			Str
			ArrayRef
			HashRef
		);
	my $mangle_keys = {
		Hello_ref => 'primary_ref',
		World_ref => 'secondary_ref',
	};

	#########1 Public Method      3#########4#########5#########6#########7#########8

	sub mangle_data{
		my ( $self, $passed_ref ) = @_;
		@$passed_ref{ 'before_method', 'after_method' } = 
			( '_mangle_data_before_method', '_mangle_data_after_method' );
		### Start recursive parsing
		$passed_ref = $self->_process_the_data( $passed_ref, $mangle_keys );
		### End recursive parsing with: $passed_ref
		return $passed_ref->{Hello_ref};
	}

	#########1 Private Methods    3#########4#########5#########6#########7#########8

	### If you are at the string level merge the two references
	sub _mangle_data_before_method{
		my ( $self, $passed_ref ) = @_;
		if( 
			is_Str( $passed_ref->{primary_ref} ) and 
			is_Str( $passed_ref->{secondary_ref} )		){
			$passed_ref->{primary_ref} .= " " . $passed_ref->{secondary_ref};
		}
		return $passed_ref;
	}

	### Strip the reference layers on the way out
	sub _mangle_data_after_method{
		my ( $self, $passed_ref ) = @_;
		if( is_ArrayRef( $passed_ref->{primary_ref} ) ){
			$passed_ref->{primary_ref} = $passed_ref->{primary_ref}->[0];
		}elsif( is_HashRef( $passed_ref->{primary_ref} ) ){
			$passed_ref->{primary_ref} = $passed_ref->{primary_ref}->{level};
		}
		return $passed_ref;
	}

	package main;
	use Modern::Perl;
	use MooseX::ShortCut::BuildInstance qw(
			build_instance
		);
	my 	$AT_ST = build_instance( 
			package		=> 'Greeting',
			superclasses	=> [ 'Data::Walk::Extracted' ],
			roles		=> [ 'Data::Walk::MyRole' ],
		);
	print $AT_ST->mangle_data( {
			Hello_ref =>{ level =>[ { level =>[ 'Hello' ] } ] },
			World_ref =>{ level =>[ { level =>[ 'World' ] } ] },
		} ) . "\n";
	
	
    
	#################################################################################
	#     Output of SYNOPSIS
	# 01:Hello World
	#################################################################################
	
=head1 DESCRIPTION

This module takes a data reference (or two) and 
L<recursivly|http://en.wikipedia.org/wiki/Recursion_(computer_science)> 
travels through it(them).  Where the two references diverge the walker follows the 
primary data reference.  At the L<beginning|/Assess and implement the before_method> 
and L<end|/Assess and implement the after_method> of each L</node> the code will 
attempt to call a L<method|/Extending Data::Walk::Extracted> using data from the 
current location of the node.

=head2 Acknowledgement of MJD

This is an implementation of the concept of extracted data walking from 
L<Higher-Order-Perl|http://hop.perl.plover.com/book/> Chapter 1 by 
L<Mark Jason Dominus|https://metacpan.org/author/MJD>.  I<The book is well worth the 
money!>  With that said I diverged from MJD purity in two ways. This is object oriented 
code not functional code. Second, like the MJD equivalent, the code does 
L<nothing on its own|/Extending Data::Walk::Extracted>.   Unlike the MJD equivalent it 
looks for methods provided in a role or class extention at the appropriate places for action.  
The MJD equivalent expects to use a passed CodeRef at the action points.  There is clearly 
some overhead associated with both of these differences.  I made those choices consciously 
and if that upsets you L<do not hassle MJD|/AUTHOR>!

=head2 What is the unique value of this module?

With the recursive part of data walking extracted the various functionalities desired 
when walking the data can be modularized without copying this code.  The Moose 
framework also allows diverse and targeted data parsing without dragging along a 
L<kitchen sink|http://en.wiktionary.org/wiki/everything_but_the_kitchen_sink> API 
for every implementation of this Class.

=head2 Extending Data::Walk::Extracted

All action taken during the data walking must be initiated by implementation of action 
methods that do not exist in this class.  They can be added with a traditionally 
incorporated Role L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles>, by 
L<extending the class|https://metacpan.org/module/Moose::Manual::Classes>, or 
L<joined|/$AT_ST = build_instance> to the class later. See   
L<MooseX::ShortCut::BuildInstance|http://search.cpan.org/~jandrew/MooseX-ShortCut-BuildInstance/lib/MooseX/ShortCut/BuildInstance.pm>.
or L<Moose::Util|https://metacpan.org/module/Moose::Util> for more class building 
information.  See the L</Recursive Parsing Flow> to understand the details of how the 
methods are used.

=head3 Requirements to build a role that uses this class

First build either or both of the L<before|/Assess and implement the before_method> 
and L<after|/Assess and implement the after_method> action methods.  Then create the 
'action' method for the role.  This would preferably be named something descriptive 
like 'mangle_data'.  Remember if more than one role is added to Data::Walk::Extracted 
then all methods should be named with consideration for other (future?) method names.  
The 'mangle_data' method should 
L<gather|/@$passed_ref{ 'before_method', 'after_method' }> any action methods and 
data references into a $passed_ref the pass this reference and possibly a 
L</$conversion_ref> to be used by 
L<_process_the_data|/_process_the_data( $passed_ref, $conversion_ref )> .  
Then the 'action' method should call;

	$passed_ref = $self->_process_the_data( $passed_ref, $conversion_ref );

See the L</Recursive Parsing Flow> for the details of this action.

Finally, L<Write some tests for your role!|http://www.perlmonks.org/?node_id=918837>

=head1 Recursive Parsing Flow

=head2 Assess and implement the before_method

The class next checks for an available 'before_method'.  Using the test; 

	exists $passed_ref->{before_method};

If the test passes then the next sequence is run.

	$method = $passed_ref->{before_method};
	$passed_ref = $self->$method( $passed_ref );

If the $passed_ref is modified by the 'before_method' then the recursive parser will 
parse the new ref and not the old one.

=head2 Identify node elements

If the next node type is not skipped then a list is generated for all paths within that 
lower node.  For example a 'HASH' node would generate a list of hash keys for that node.  
SCALARs are handled as a list with one element single element and UNDEFs are an empty list.  
If the list L<should be sorted|/sorted_nodes> then the list is sorted. B<ARRAYS 
are hard sorted.> This means that the actual items in the (primary) passed data ref are 
permanantly sorted.

=head2 Iterate through each element

For each element a new 
L<$passed_ref|/B<$passed_ref> this ref contains key value pairs as follows;> 
is generated containing the data below that element.  The down level secondary_ref is 
only constructed if it has a matching type/element to the primary ref.  Matching for 
hashrefs is done by key matching only.  Matching for arrayrefs is done by position 
exists testing only.  I<No position content compare is done!> Scalars are matched on 
content.  The list of items generated for this element is as follows;

=over

=item B<before_method =E<gt>> --E<gt>name of before method for this role hereE<lt>--

=item B<after_method =E<gt>> --E<gt>name of after method for this role hereE<lt>--

=item B<branch_ref =E<gt>> L<An array ref of array refs|/A position trace is generated>

=item B<primary_ref =E<gt>> the piece of the primary data ref below this element

=item B<primary_type =E<gt>> the lower primary 
L<ref type|/_extracted_ref_type( $test_ref )>

=item B<match =E<gt>> YES|NO (This indicates if the secondary ref meets matching critera

=item B<skip =E<gt>> YES|NO Checks L<the three skip attributes|/skipped_nodes> against 
the lower primary_ref node.  This can also be adjusted in a 'before_method' upon arrival 
at that node.

=item B<secondary_ref =E<gt>> if match eq 'YES' then built like the primary ref

=item B<secondary_type =E<gt>> if match eq 'YES' then calculated like the primary type

=back

=head2 A position trace is generated

The current node list position is then documented using an internally managed key of the 
$passed_ref labeled B<'branch_ref'>.  The array reference stored in branch_ref can be 
thought of as the stack trace that documents the node elements directly between the 
current position and the initial (or zeroth) level of the parsed primary data_ref.  
Past completed branches and future pending branches are not maintained.  Each element 
of the branch_ref contains four positions used to describe the node and selections 
used to traverse that node level.  The values in each sub position are; 

	[
		ref_type, #The node reference type
		the list item value or '' for ARRAYs,
			#key name for hashes, scalar value for scalars
		element sequence position (from 0),
			#For hashes this is only relevent if sort_HASH is called
		level of the node (from 0),
			`#The zeroth level is the passed data ref
	]

=head2 Going deeper in the data

The down level ref is then passed as a new data set to be parsed and it starts 
at L</Assess and implement the before_method>.

=head2 Actions on return from recursion

When the values are returned from the recursion call the last branch_ref element is 
L<pop|http://perldoc.perl.org/functions/pop.html>ed off and the returned data ref 
is used to L<replace|/fixed_primary> the sub elements of the primary_ref and secondary_ref 
associated with that list element in the current level of the $passed_ref.  If there are 
still pending items in the node element list then the program returns to 
L</Iterate through each element> else it moves to 
L</Assess and implement the after_method>.


=head2 Assess and implement the after_method

The class checks for an available 'after_method' using the test;

	exists $passed_ref->{after_method};

If the test passes then the following sequence is run.

	$method = $passed_ref->{after_method};
	$passed_ref = $self->$method( $passed_ref );

If the $passed_ref is modified by the 'after_method' then the recursive parser will 
parse the new ref and not the old one.

=head2 Go up

The updated $passed_ref is passed back up to the next level.

=head1 Attributes

Data passed to -E<gt>new when creating an instance.  For modification of these attributes 
see L</Public Methods>.  The -E<gt>new function will either accept fat comma lists or a 
complete hash ref that has the possible attributes as the top keys.  Additionally some 
attributes that meet L<certain criteria|/[attribute name]> can be passed to 
L<_process_the_data|/B<[attribute name]> - attribute names are> and will be adjusted 
for just the run of that method call.  These are called 
L<one shot|/Supported one shot attributes> attributes.  Nested calls to _process_the_data 
will be tracked and the attribute will remain in force until the parser returns to the 
calling 'one shot' level.  Previous attribute values are restored after the 'one shot' 
attribute value expires.

=head2 sorted_nodes

=over

=item B<Definition:> This attribute is set to sort (or not) the 
L<list of items|/Identify node elements> in each node.

=item B<Default> {} #Nothing is sorted

=item B<Range> This accepts a HashRef.

The keys are only used if they match a node type identified by the function 
L<_extracted_ref_type|/_extracted_ref_type( $test_ref )>.  The value for the 
key can be anything, but if it is a CODEREF it will be treated as a 
L<sort|http://perldoc.perl.org/functions/sort.html> function in perl.  In general 
it is sorting a list of strings not the data structure itself. The sort will be 
applied as follows.

	@node_list = sort $coderef @node_list

I<For the type 'ARRAY' the node is sorted (permanantly) as well as the list.  This means 
that if the array contains a list of references it will effectivly sort in memory pointer 
order.  Additionally the 'secondary_ref' node is not sorted, so prior alignment may break.  
In general ARRAY sorts are not recommended.>

=item B<Example:>

	sorted_nodes =>{
		ARRAY	=> 1,#Will sort the primary_ref only
		HASH	=> sub{	$b cmp $a }, #reverse sort the keys
	}
	
=back

=head2 skipped_nodes

=over

=item B<Definition:> This attribute is set to skip (or not) node parsing by type.  If the 
current node type matches (eq) the L<primary_type|/primary_type => then the 
'before_method' and 'after_method' are run at that node but no parsing is done.

=item B<Default> {} #Nothing is skipped

=item B<Range> This accepts a HashRef.

The keys are only used if they match a node type identified by the function 
L<_extracted_ref_type|/_extracted_ref_type( $test_ref )>.  The value for the 
key can be anything.
    
=back

=head2 skip_level

=over

=item B<Definition:> This attribute is set to skip (or not) node parsing at a given 
level.  Because the process doesn't start checking until after it enters the data ref 
it effectivly ignores a skip_level set to 0 (The base node level).

=item B<Default> undef #Nothing is skipped

=item B<Range> This accepts an integer
    
=back

=head2 skip_node_tests

=over

=item B<Definition:> This attribute contains a list of test conditions used to skip 
certain targeted nodes.  The test can target, array position, match a hash key, even 
restrict the test to only one level.  The test is run against the 
L<branch_ref|/A position trace is generated> so it skips the node below the matching 
conditions not the node at the matching conditions.  Matching is done with either 'eq' 
or '=~'.  The attribute is passed an ArrayRef of ArrayRefs.  Each sub_ref contains the 
following;

=over

=item B<$type> - this is any of the L<identified|/_extracted_ref_type( $test_ref )> 
reference node types

=item B<$key> - this is either a scalar or regexref to use for matching a hash key

=item B<$position> - this is used to match an array position can be an integer or 'ANY'

=item B<$level> - this restricts the skipping test usage to a specific level only or 'ANY'

=back
    
=item B<Example>
	
	[ 
		[ 'HASH', 'KeyWord', 'ANY', 'ANY'], 
		# Skip the node below the value of any hash key eq 'Keyword'
		[ 'ARRAY', 'ANY', '3', '4'], ], 
		# Skip the nodes below arrays at position three on level four
	]

=item B<Range> an infinite number of skip tests added to an array

=item B<Default> [] = no nodes are skipped

=back

=head2 change_array_size

=over

=item B<Definition:> This attribute will not be used by this class directly.  However 
the L<Data::Walk::Prune> Role and the L<Data::Walk::Graft> Role both use it so it is 
placed here so there will be no conflicts.

=item B<Default> 1 (This usually means that the array will grow or shrink when a position 
is added or removed)

=item B<Range> Boolean values.

=back

=head2 fixed_primary

=over

=item B<Definition:> This means that no changes made at lower levels will be passed 
upwards into the final ref.

=item B<Default> 0 = The primary ref is not fixed (and can be changed) I<0 
effectively deep clones the portions of the primary ref that are traversed.>

=item B<Range> Boolean values.

=back

=head1 Methods

=head2 Methods used to write Roles

=head3 _process_the_data( $passed_ref, $conversion_ref )

=over

=item B<Definition:> This method is the core access to the recursive parsing of 
Data::Walk::Extracted.  It should only be used by a method in consuming roles or classes.  
It should not be used by the end user.  This method scrubs the inputs and then sends them 
to the recursive function.

=item B<Accepts:> ( $passed_ref, $conversion_ref )

=over 

=item B<$passed_ref> this ref contains key value pairs as follows;

=over

=item B<primary_ref> - a dataref that the walker will walk.  This L<can be renamed
|/$conversion_ref This allows a public> with a $conversion_ref - required

=item B<secondary_ref> - a dataref that is used for comparision while walking.  (L<can be 
renamed|/$conversion_ref This allows a public>) - optional

=item B<before_method> - a method name that will perform some action at the beginning 
of each node - optional

=item B<after_method> - a method name that will perform some action at the end 
of each node - optional

=item B<[attribute name]> - attribute names are accepted with temporary attribute settings.  
These settings are temporarily set for a single "_process_the_data" call and then the original 
attribute values are restored.  For this to work the the attribute must have the following 
prefixed methods; get_$name, set_$name, clear_$name, and has_$name. - optional

=back

=item B<$conversion_ref> This allows a public method to accept different key names for the 
various keys listed above and then convert them later to the generic terms used by this class. 
- optional

=item B<Example>

	$passed_ref ={
		print_ref =>{ 
			First_key => [
				'first_value',
				'second_value'
			],
		},
		match_ref =>{
			First_key 	=> 'second_value',
		},
		before_method	=> '_print_before_method',
		after_method	=> '_print_after_method',
		sorted_nodes	=>{ Array => 1 },#One shot attribute setter
	}

	$conversion_ref ={
		primary_ref	=> 'print_ref',# generic_name => role_name,
		secondary_ref	=> 'match_ref',
	}

=back

=item B<Action:> This method begins by scrubing the top level of the inputs and 
ensures that the minimum requirements for the recursive data parser are met.  
If needed it will use a conversion ref (also provided by the caller) to change 
input hash keys to the generic hash keys used by this class.  This function then 
calls the actual recursive function.  For a better understanding of the recursive 
steps see L</Recursive Parsing Flow>.

=item B<Returns:> the $passed_ref (only) with the key names restored to their 
L<original|/B<$conversion_ref> This allows a public> versions.

=back

=head3 _build_branch( $seed_ref, @arg_list )

=over

=item B<Definition:> There are times when a role will wish to reconstruct the data branch 
that lead from the 'zeroth' node to where the data walker is currently at.  This private 
method takes a seed reference and uses the  L<branch ref|/A position trace is generated> 
to recursivly append to the front of the seed until a complete branch to the zeroth 
node is generated.

=item B<Accepts:> a list of arguments starting with the $seed_ref to build from.  
The remaining arguments are just the array elements of the 'branch ref'.

=item B<Example>

	$ref = $self->_build_branch( 
		$seed_ref, 
		@{ $passed_ref->{branch_ref}},
	);

=item B<Returns:> a data reference with the current path back to the start pre-pended 
to the $seed_ref

=back

=head3 _extracted_ref_type( $test_ref )

=over

=item B<Definition:> In order to manage data types necessary for this class a data 
walker compliant 'Type' tester is provided.  This is necessary to support a few non 
perl-standard types not generated in standard perl typing systems.  First, 'undef' 
is the UNDEF type.  Second, strings and numbers both return as 'SCALAR' (not '' or undef).  
B<Much of the code in this package runs on dispatch tables that are built around these 
specific type definitions.>

=item B<Accepts:> This method expects to be called by $self.  It receives a data 
reference that can include/be undef.

=item B<Returns:> a data walker type or it confesses.  (For more details see 
$discover_type_dispatch in the code)

=back

=head3 _get_had_secondary

=over

=item B<Definition:> during the initial processing of data in 
L<_process_the_data|/_process_the_data( $passed_ref, $conversion_ref )> the existence 
of a passed secondary ref is tested and stored in the attribute '_had_secondary'.  On 
occasion a role might need to know if a secondary ref existed at any level if it it is 
not represented at the current level.

=item B<Accepts:> nothing

=item B<Returns:> True|1 if the secondary ref ever existed

=back

=head3 _get_current_level

=over

=item B<Definition:> on occasion you may need for one of the methods to know what 
level is currently being parsed.  This will provide that information in integer 
format.

=item B<Accepts:> nothing

=item B<Returns:> the integer value for the level

=back

=head3 [_private 'one shot' attributes]

=over

=item B<Definition:> private one shot attributes in roles are allowed as well.  
If you would like to implement a private one shot attribute that is not exposed to 
the end user then adding the '_' prefix to the attribute name and creating the 
appropriate _get, _set, _clear, and _has methods will enable this.

=back

=head2 Public Methods

=head3 add_sorted_nodes( NODETYPE => 1, )

=over

=item B<Definition:> This method is used to add nodes to be sorted to the walker by 
adjusting the attribute L</sorted_nodes>.

=item B<Accepts:> Node key => value pairs where the key is the Node name and the value is 
1.  This method can accept multiple key => value pairs.

=item B<Returns:> nothing

=back

=head3 has_sorted_nodes

=over

=item B<Definition:> This method checks if any sorting is turned on in the attribute 
L</sorted_nodes>.

=item B<Accepts:> Nothing

=item B<Returns:> the count of sorted node types listed

=back

=head3 check_sorted_nodes( NODETYPE )

=over

=item B<Definition:> This method is used to see if a node type is sorted by testing the 
attribute L</sorted_nodes>.

=item B<Accepts:> the name of one node type

=item B<Returns:> true if that node is sorted as determined by L</sorted_nodes>

=back

=head3 clear_sorted_nodes

=over

=item B<Definition:> This method will clear all values in the attribute 
L</sorted_nodes>.  I<and therefore turn off those sorts>.

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head3 remove_sorted_node( NODETYPE1, NODETYPE2, )

=over

=item B<Definition:> This method will clear the key / value pairs in L</sorted_nodes> 
for the listed items.

=item B<Accepts:> a list of NODETYPES to delete

=item B<Returns:> In list context it returns a list of values in the hash for the deleted 
keys. In scalar context it returns the value for the last key specified

=back

=head3 set_sorted_nodes( $hashref )

=over

=item B<Definition:> This method will completely reset the attribute L</sorted_nodes> to 
$hashref.

=item B<Accepts:> a hashref of NODETYPE keys with the value of 1.

=item B<Returns:> nothing

=back

=head3 get_sorted_nodes

=over

=item B<Definition:> This method will return a hashref of the attribute L</sorted_nodes>

=item B<Accepts:> nothing

=item B<Returns:> a hashref

=back

=head3 add_skipped_nodes( NODETYPE1 => 1, NODETYPE2 => 1 )

=over

=item B<Definition:> This method adds additional skip definition(s) to the 
L</skipped_nodes> attribute.

=item B<Accepts:> a list of key value pairs as used in 'skipped_nodes'

=item B<Returns:> nothing

=back

=head3 has_skipped_nodes

=over

=item B<Definition:> This method checks if any nodes are set to be skipped in the 
attribute L</skipped_nodes>.

=item B<Accepts:> Nothing

=item B<Returns:> the count of skipped node types listed

=back

=head3 check_skipped_node( $string )

=over

=item B<Definition:> This method checks if a specific node type is set to be skipped in  
the L</skipped_nodes> attribute.

=item B<Accepts:> a string

=item B<Returns:> Boolean value indicating if the specific $string is set

=back

=head3 remove_skipped_nodes( NODETYPE1, NODETYPE2 )

=over

=item B<Definition:> This method deletes specificily identified node skips from the 
L</skipped_nodes> attribute.

=item B<Accepts:> a list of NODETYPES to delete

=item B<Returns:> In list context it returns a list of values in the hash for the deleted 
keys. In scalar context it returns the value for the last key specified

=back

=head3 clear_skipped_nodes

=over

=item B<Definition:> This method clears all data in the L</skipped_nodes> attribute.

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head3 set_skipped_nodes( $hashref )

=over

=item B<Definition:> This method will completely reset the attribute L</skipped_nodes> to 
$hashref.

=item B<Accepts:> a hashref of NODETYPE keys with the value of 1.

=item B<Returns:> nothing

=back

=head3 get_skipped_nodes

=over

=item B<Definition:> This method will return a hashref of the attribute L</skipped_nodes>

=item B<Accepts:> nothing

=item B<Returns:> a hashref

=back

=head3 set_skip_level( $int)

=over

=item B<Definition:> This method is used to reset the L</skip_level>
attribute after the instance is created.

=item B<Accepts:> an integer (negative numbers and 0 will be ignored)

=item B<Returns:> nothing

=back

=head3 get_skip_level()

=over

=item B<Definition:> This method returns the current L</skip_level> 
attribute.

=item B<Accepts:> nothing

=item B<Returns:> an integer

=back

=head3 has_skip_level()

=over

=item B<Definition:> This method is used to test if the L</skip_level> attribute 
is set.

=item B<Accepts:> nothing

=item B<Returns:> $Bool value indicating if the 'skip_level' attribute has been set

=back

=head3 clear_skip_level()

=over

=item B<Definition:> This method clears the L</skip_level> attribute.

=item B<Accepts:> nothing

=item B<Returns:> nothing (always successful)

=back

=head3 set_skip_node_tests( ArrayRef[ArrayRef] )

=over

=item B<Definition:> This method is used to change (completly) the 'skip_node_tests' 
attribute after the instance is created.  See L</skip_node_tests> for an example.

=item B<Accepts:> an array ref of array refs

=item B<Returns:> nothing

=back

=head3 get_skip_node_tests()

=over

=item B<Definition:> This method returns the current master list from the 
L</skip_node_tests> attribute.

=item B<Accepts:> nothing

=item B<Returns:> an array ref of array refs

=back

=head3 has_skip_node_tests()

=over

=item B<Definition:> This method is used to test if the L</skip_node_tests> attribute 
is set.

=item B<Accepts:> nothing

=item B<Returns:> The number of sub array refs there are in the list

=back

=head3 clear_skip_node_tests()

=over

=item B<Definition:> This method clears the L</skip_node_tests> attribute.

=item B<Accepts:> nothing

=item B<Returns:> nothing (always successful)

=back

=head3 add_skip_node_tests( ArrayRef1, ArrayRef2 )

=over

=item B<Definition:> This method adds additional skip_node_test definition(s) to the the 
L</skip_node_tests> attribute list.

=item B<Accepts:> a list of array refs as used in 'skip_node_tests'.  These are 'pushed 
onto the existing list.

=item B<Returns:> nothing

=back

=head3 set_change_array_size( $bool )

=over

=item B<Definition:> This method is used to change the L</change_array_size> attribute 
after the instance is created.

=item B<Accepts:> a Boolean value

=item B<Returns:> nothing

=back

=head3 get_change_array_size()

=over

=item B<Definition:> This method returns the current state of the L</change_array_size> 
attribute.

=item B<Accepts:> nothing

=item B<Returns:> $Bool value representing the state of the 'change_array_size' 
attribute

=back

=head3 has_change_array_size()

=over

=item B<Definition:> This method is used to test if the L</change_array_size> 
attribute is set.

=item B<Accepts:> nothing

=item B<Returns:> $Bool value indicating if the 'change_array_size' attribute 
has been set

=back

=head3 clear_change_array_size()

=over

=item B<Definition:> This method clears the L</change_array_size> attribute.

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head3 set_fixed_primary( $bool )

=over

=item B<Definition:> This method is used to change the L</fixed_primary> attribute 
after the instance is created.

=item B<Accepts:> a Boolean value

=item B<Returns:> nothing

=back

=head3 get_fixed_primary()

=over

=item B<Definition:> This method returns the current state of the L</fixed_primary> 
attribute.

=item B<Accepts:> nothing

=item B<Returns:> $Bool value representing the state of the 'fixed_primary' attribute

=back

=head3 has_fixed_primary()

=over

=item B<Definition:> This method is used to test if the L</fixed_primary> attribute 
is set.

=item B<Accepts:> nothing

=item B<Returns:> $Bool value indicating if the 'fixed_primary' attribute has been set

=back

=head3 clear_fixed_primary()

=over

=item B<Definition:> This method clears the L</fixed_primary> attribute.

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head1 Definitions

=head2 node

Each branch point of a data reference is considered a node.  The original top level 
reference is the 'zeroth' node.  Recursion 'Base state' nodes are understood to have 
zero elements so an additional node called 'END' type is recognized after a scalar.

=head2 Supported node walking types

=over

=item ARRAY

=item HASH

=item SCALAR

=item UNDEF

=back

=head3 Other node support

Support for Objects is partially implemented and as a consequence '_process_the_data' 
won't immediatly die when asked to parse an object.  It will still die but on a 
dispatch table call that indicates where there is missing object support, not at the 
top of the node.  This allows for some of the L<skip attributes|/skipped_nodes> to 
use 'OBJECT' in their definitions.

=head2 Supported one shot attributes

=over

=item sorted_nodes

=item skipped_nodes

=item skip_level

=item skip_node_tests

=item change_array_size

=item fixed_primary

=item L<explanation|/Attributes>

=back

=head2 Dispatch Tables

This class uses the role L<Data::Walk::Extracted::Dispatch> to implement dispatch 
tables.  When there is a decision point, that role is used to make the class 
extensible.

=head1 Caveat utilitor

This is not an extention of L<Data::Walk|https://metacpan.org/module/Data::Walk>

The core class has no external effect.  All output comes from 
L<addtions to the class|/Requirements to build a role that uses this class>.

This module uses the 'L<defined or|http://perldoc.perl.org/perlop.html#Logical-Defined-Or>' 
(  //= ) and so requires perl 5.010 or higher.

This is a L<Moose|https://metacpan.org/module/Moose::Manual> based data handling class.  
Many coders will tell you Moose and data manipulation don't belong together.  They are 
most certainly right in speed intensive circumstances.

Recursive parsing is not a good fit for all data since very deep data structures will 
burn a fair amount of perl memory!  Meaning that as the module recursively parses through 
the levels perl leaves behind snapshots of the previous level that allow perl to keep 
track of it's location.

The L<primary_ref|/B<primary_ref> - a> and L<secondary_ref|/B<secondary_ref> - a> are 
effectivly deep cloned during this process.  To leave the primary_ref pointer intact see 
L</fixed_primary>

=head1 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> if the '-ENV' option is set.  The 'use' is 
encapsulated in an if block triggered by an environmental variable to comfort 
non-believers.  Setting the variable $ENV{Smart_Comments} in a BEGIN block will 
load and turn on smart comment reporting.  There are three levels of 'Smartness' 
available in this module '###',  '####', and '#####'.

=back

=head1 SUPPORT

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item * provide full recursion through Objects

=item * Support recursion through CodeRefs

=item * Add a Data::Walk::Diff Role to the package

=item * Add a Data::Walk::Top Role to the package

=item * Add a Data::Walk::Thin Role to the package

=item * Add a Data::Walk::Substitute Role to the package

=back

=head1 AUTHOR

=over

=item Jed Lund

=item jandrew@cpan.org

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 Dependencies

=over

=item L<5.010> (for use of 
L<defined or|http://perldoc.perl.org/perlop.html#Logical-Defined-Or> //)

=item L<Moose>

=item L<MooseX::StrictConstructor>

=item L<Class::Inspector>

=item L<Scalar::Util>

=item L<Carp>

=item L<MooseX::Types::Moose>

=item L<Data::Walk::Extracted::Types>

=item L<Data::Walk::Extracted::Dispatch>

=back

=head1 SEE ALSO

=over

=item L<Smart::Comments> - is used if the -ENV option is set

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dumper

=item L<YAML> - Dump

=item L<Data::Walk::Print> - available Data::Walk::Extracted Role

=item L<Data::Walk::Prune> - available Data::Walk::Extracted Role

=item L<Data::Walk::Graft> - available Data::Walk::Extracted Role

=item L<Data::Walk::Clone> - available Data::Walk::Extracted Role

=back

=cut

#########1 Main POD ends      3#########4#########5#########6#########7#########8#########9