package Data::Walk::Extracted;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use Class::Inspector;
use Scalar::Util qw( reftype );
use version; our $VERSION = qv('0.015_005');
use Carp qw( carp croak confess cluck );
use Smart::Comments -ENV;
use MooseX::Types::Moose qw(
        ArrayRef
        HashRef
        Object
        CodeRef
        RegexpRef
        ClassName
        RoleName
        Ref
        Str
        Int
        Bool
    );
BEGIN{
	if( $ENV{ Smart_Comments } ){
		use Smart::Comments -ENV;
		### Smart-Comments turned on for Data-Walk-Graft
	}
}
### Smart-Comments turned on for Data-Walk-Extracted ...

###############  Package Variables  #####################################################

$| = 1;
my 	$wait;
my 	$walk_the_data_keys = {
		primary_ref		=> 1,#Required
		secondary_ref   => 0,#Optional
		before_method	=> 2,#One or the other of two required
		after_method	=> 2,#One or the other of two required
		branch_ref		=> 0,#Don't generally use
	};
my	@data_ref_names = qw(
		primary_ref
		secondary_ref
	);

# This is also the order of type investigaiton testing
# This is the maximum list if the types are also not listed in the appropriate dispatch 
# tables, then it still won't parse
my 	$supported_type_list = [ qw(
		END SCALAR ARRAY HASH CODEREF OBJECT
	) ];######<------------------------------------------------------  ADD New types here

###############  Dispatch Tables  #######################################################
	
my 	$discover_type_dispatch = {######<-------------------------------  ADD New types here
		END			=> sub{ !$_[1] },
		SCALAR		=> sub{ is_Str( $_[1] ) },
		ARRAY		=> sub{ is_ArrayRef( $_[1] ) },
		HASH		=> sub{ is_HashRef( $_[1] ) },
		OBJECT		=> sub{ is_Object( $_[1] ) },
		CODEREF		=> sub{ is_CodeRef( $_[1] ) },
	};

my  $reconstruction_dispatch = {######<-----------------------------  ADD New types here
		name 	=> 'reconstruction_dispatch',#Meta data
		HASH	=> \&_rebuild_hash_level,
		ARRAY 	=> \&_rebuild_array_level,
	};

my  $node_list_dispatch = {######<----------------------------------  ADD New types here
		name 		=> 'node_list_dispatch',#Meta data
		HASH		=> sub{ [ keys %{$_[1]} ] },
		ARRAY		=> sub{
			my $list;
			map{ push @$list, 1 } @{$_[1]};
			return $list;
		},
		SCALAR		=> sub{ [ $_[1] ] },
		OBJECT		=> \&_get_object_list,
		#~ METHOD		=> \&_get_object_methods,
		#~ ATTRIBUTE	=> \&_get_object_attributes,
		END			=> sub{ return [] },
		###### Receives: a data reference or scalar
		###### Returns: an array reference of list items
	};

my  $sub_ref_dispatch = {######<------------------------------------  ADD New types here
    name	=> 'sub_ref_dispatch',#Meta data
    HASH	=> sub{ return $_[1]->{$_[2]} },
    ARRAY	=> sub{ return $_[1]->[$_[3]] },
    SCALAR	=> sub{ return undef; },
	OBJECT	=> \&_get_object_element,
};

my $branch_ref_item_dispatch = {######<-----------------------------  ADD New types here
    name 	=> 'branch_ref_item_dispatch',#Meta data
    HASH	=> sub{ return $_[1]; },
    DEFAULT	=> sub{ return undef; },
    SCALAR	=> sub{ return $_[1]; },
	OBJECT	=> sub{ return $_[1]; },
};

my $secondary_match_dispatch = {######<-----------------------------  ADD New types here
	name	=> 'secondary_match_dispatch',#Meta data
    HASH	=> 	sub{
		### <where> - passed: @_
		return (
			( exists $_[1]->{secondary_ref} ) and
			( ref $_[1]->{secondary_ref} eq 'HASH' ) and
			( exists $_[1]->{secondary_ref}->{$_[2]} )
		) ?	1 : 0 ;
	},
    ARRAY	=> sub{
		### <where> - passed: @_
		return (
			( exists $_[1]->{secondary_ref} ) and
			( ref $_[1]->{secondary_ref} eq 'ARRAY' ) and
			( $#{$_[1]->{secondary_ref}} >= $_[3] )
		) ?	1 : 0 ;
	},
    SCALAR	=> sub{
		### <where> - passed: @_
		return (
			( exists $_[1]->{secondary_ref} ) and
			( $_[1]->{primary_ref} eq $_[1]->{secondary_ref} )
		) ?	1 : 0 ;
	},
    OBJECT	=> 	sub{
		### <where> - passed: @_
		return (
			( exists $_[1]->{secondary_ref} ) and
			( ref $_[1]->{secondary_ref} ) and
			( ref( $_[1]->{secondary_ref} ) eq $_[2] )
		) ?	1 : 0 ;
	},
};

my 	$up_ref_dispatch = {######<--------------------------------------  ADD New types here
	name 	=> 'up_ref_dispatch',#Meta data
    HASH	=> \&_load_hash_up,
    ARRAY 	=> \&_load_array_up,
	SCALAR	=> sub{
		### <where> - made it to SCALAR ref upload ...
		$_[3]->{$_[1]} = $_[2]->[1];
		### <where> - returning: $_[3]
		return $_[3];
	},
	#~ OBJECT	=> \&_load_object_up,
};

my	$object_extraction_dispatch ={######<----------------------------  ADD New types here
	name	=> 'object_extraction_dispatch',
	HASH	=> sub{ return {%{$_[1]}} },
	ARRAY	=> sub{ return [@{$_[1]}] },
	DEFAULT => sub{ return ${$_[1]} },
	###### Receives: an object reference
	###### Returns: a reference or string of the blessed data in the object
};

###############  Public Attributes  #####################################################

for my $type ( @$supported_type_list ){
	#~ next if $type eq 'END';
    my $sort_attribute = 'sort_' . $type;
    has $sort_attribute =>(
        is			=> 'ro',
        isa    		=> Bool|CodeRef,
        default 	=> 0,
		predicate	=> 'has_' . $sort_attribute,
		reader		=> 'get_' . $sort_attribute,
		writer		=> 'set_' . $sort_attribute,
		clearer		=> 'clear_' . $sort_attribute,
    );
    my $skip_attribute = 'skip_' . $type . '_ref';
    has $skip_attribute =>(
        is      	=> 'rw',
        isa     	=> Bool,
        default 	=> 0,
		predicate	=> 'has_' . $skip_attribute,
		reader		=> 'get_' . $skip_attribute,
		writer		=> 'set_' . $skip_attribute,
		clearer		=> 'clear_' . $skip_attribute,
    );
}

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

###############  Public Methods  ########################################################

###############  Private Attributes  ####################################################

has '_had_secondary' =>(
    is			=> 'ro',
    isa     	=> Bool,
	writer		=> '_set_had_secondary',
	reader		=> '_get_had_secondary',
	predicate	=> '_has_had_secondary',
    default		=> 0,
);

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

has '_caller_stack' =>(
	is		=> 'ro',
	isa		=> ArrayRef,
	traits	=> ['Array'],
	reader	=> '_get_caller_stack',
	default	=> sub{ [] },
    handles => {
        _add_caller		=> 'push',
		_count_callers	=> 'count',
		_clear_callers	=> 'clear',
		_get_last_caller=> 'pop',
    },
);

###############  Private Methods to be used by consuming roles / classes  ###############

sub _process_the_data{#Used to scrub high level input
    ### <where> - Made it to _process_the_data
    ##### <where> - Passed input  : @_
    my ( $self, $passed_ref, $conversion_ref ) = @_;
    ### <where> - Passed hashref: $passed_ref
    ### <where> - review the ref keys for requirements and conversion
    $passed_ref = $self->_has_required_inputs( $passed_ref, $conversion_ref );
	##### <where> - Passed hashref: $passed_ref
	### <where> - completing the starter branch_ref	...
	my	$ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
	$passed_ref->{branch_ref} = 
		( exists $passed_ref->{branch_ref} ) ?
			$passed_ref->{branch_ref} :
			[ [	$ref_type,
				$self->_dispatch_method(
				$branch_ref_item_dispatch,
					$ref_type, undef, 
					$passed_ref->{primary_ref},
				), 0, 0,],							];
	##### <where> - branch ref: $passed_ref->{branch_ref}
	### <where> - setting the secondary flag as needed ...
	if( exists $passed_ref->{secondary_ref} ){
		$self->_set_had_secondary( 1 );
	}
    ##### <where> - Start recursive parsing with: $passed_ref
	$passed_ref = $self->_walk_the_data( $passed_ref );
    delete $passed_ref->{branch_ref};
    ### <where> - convert the data keys back to the Role names
    for my $old_key ( keys %$conversion_ref ){
        if( exists $passed_ref->{$old_key} ){
            $passed_ref->{$conversion_ref->{$old_key}} = $passed_ref->{$old_key};
            delete $passed_ref->{$old_key};
        }
    }
    ### <where> - restoring instance clone attributes as needed ...
	$self->_restore_attributes;
	$self->_clear_had_secondary;
	##### <where> - End recursive passing with: $passed_ref
    return $passed_ref;
}

sub _build_branch{
    my ( $self, $base_ref, @arg_list ) = @_;
    ### <where> - Made it to _build_branch;
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

sub _extracted_ref_type{
    my ( $self, $passed_ref ) = @_;
    ### <where> - made it to _extracted_ref_type ...
    ##### <where> - the passed ref is: $passed_ref
	my $scalar_util_val = reftype( $passed_ref );
	### <where> - Scalar-Util-reftype returns: $scalar_util_val
	my $ref_type;
	for my $key ( @$supported_type_list ){
		### <where> - testing: $key
		if( $self->_dispatch_method( 
				$discover_type_dispatch,
				$key,
				$passed_ref
			) 							){
			### <where> - found a match for: $key
			$ref_type = $key;
			last;
		}
		### <where> - no match ...
	}
	if( !$ref_type ){
		confess "Attempting to parse the unsupported node type -" .
			( ref $passed_ref ) . "-";
	}
    ### <where> - returning: $ref_type
    return $ref_type;
}

sub _dispatch_method{
    my ( $self, $dispatch_ref, $call, @arg_list ) = @_;
    ### <where> - Made it to _dispatch_method
    ### <where> - calling: $call
    #### <where> - for dispatch ref: $dispatch_ref
    ##### <where> - the passed arguments: @arg_list
    if( exists $dispatch_ref->{$call} ){
        my $action  = $dispatch_ref->{$call};
        ##### <where> - the action is: $call
        return $self->$action( @arg_list );
    }elsif( exists $dispatch_ref->{DEFAULT} ){
        my $action  = $dispatch_ref->{DEFAULT};
        ##### <where> - running the DEFAULT action ...
        return $self->$action( @arg_list );
    }else{
		my 	$dispatch_name = 
				( exists $dispatch_ref->{name} ) ?
					$dispatch_ref->{name} : undef ;
		my	$string = "Failed to find the '$call' dispatch";
			$string .= " in the $dispatch_name" if $dispatch_name;
		### <where> - error string: $string
		#~ $wait = <> if $ENV{ special_variable };
        confess $string;
    }
}

###############  Private Methods / Modifiers  ###########################################

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
		if( !$passed_ref or exists $passed_ref->{bounce} ){
			### <where> - returning to the previous level without parsing this node!
			delete $passed_ref->{bounce};
			return $passed_ref;
		}
	}else{
		### <where> - No before_method found
	}
    
    ### <where> - See if the node should be parsed ...
	my $lower_ref_type;
    if(	$lower_ref_type = $self->_will_parse_next_ref( $passed_ref ) and
		$lower_ref_type														){
		### <where> - build the core of the lower ref .. .
		### <where> - next ref type is: $lower_ref_type
		my 	( $x, $sort_function, $lower_passed_ref, $list_ref ) = 
				( 0, sub{ $a cmp $b }, undef, undef );
		#~ $wait = <> if $ENV{ special_variable };
		map{ push @{$lower_passed_ref->{branch_ref}}, $_ } @{$passed_ref->{branch_ref}};
		if( exists $passed_ref->{before_method} ){
            $lower_passed_ref->{before_method} = $passed_ref->{before_method};
			### <where> - before_method loaded ...
        }
        if( exists $passed_ref->{after_method} ){
            $lower_passed_ref->{after_method} = $passed_ref->{after_method};
			### <where> - after_method loaded ...
        }
		$list_ref = $self->_dispatch_method( 
						$node_list_dispatch,
						$lower_ref_type,
						$passed_ref->{primary_ref},
					);
		### <where> - sorting the list as needed for: $list_ref
		my  $sort_attribute = 'get_sort_' . $lower_ref_type;
		### <where> - Sort attribute: $sort_attribute
		#### <where> - Sort setting: $self->$sort_attribute
		if(	$self->meta->find_method_by_name( $sort_attribute ) and
			$self->$sort_attribute									){
			### <where> - The list should be sorted ...
			$sort_function =  ( is_CodeRef(  $self->$sort_attribute ) ) ? ######## ONLY PARTIALLY TESTED !!!! ######
					$self->$sort_attribute : sub{ $a cmp $b } ;
			$list_ref = [ sort $sort_function @$list_ref ];
			if( $lower_ref_type eq 'ARRAY' ){
				### <where> - This is an array ref and the array ref will be sorted ...
				$passed_ref->{primary_ref} = [sort $sort_function @{$passed_ref->{primary_ref}}];
			}
		}
		### <where> - running the list: $list_ref
		for my $item ( @{$list_ref} ){
			### <where> - now parsing: $item
			my 	$secondary_match = $self->_dispatch_method(
					$secondary_match_dispatch,
					$lower_ref_type,
					$passed_ref,
					$item, $x,
				);
			push @{$lower_passed_ref->{branch_ref}}, [	
					$lower_ref_type,
					$self->_dispatch_method(
						$branch_ref_item_dispatch,
						$lower_ref_type, $item,
						$passed_ref->{primary_ref},
					), 
					$x, 
					( $passed_ref->{branch_ref}->[-1]->[3] + 1 ),
				];
			### <where> - lower branch ref: $lower_passed_ref->{branch_ref}
			for my $key ( @data_ref_names ) {
				### <where> - building lower ref for key: $key
				my $run = 1;
				if( ($key eq 'secondary_ref') and !$secondary_match ){
					$run = 0;
					delete $lower_passed_ref->{$key};
				}
				if( $run ){
					$lower_passed_ref->{$key} = $self->_dispatch_method(
						$sub_ref_dispatch,
						$lower_ref_type,
						$passed_ref->{$key},
						$item, $x,
					);
				}
			}
			##### <where> - Passing the data: $lower_passed_ref
			$lower_passed_ref = $self->_walk_the_data( $lower_passed_ref );
			my	$old_branch_ref = pop @{$lower_passed_ref->{branch_ref}};
			
			### <where> - pass any data reference adjustments upward ...
			#### <where> - using branch ref: $old_branch_ref
			for my $key ( @data_ref_names ){
				### <where> - processing: $key
				if( $key eq 'primary_ref' and
					$self->has_fixed_primary and
					$self->get_fixed_primary 		){
					### <where> - the primary ref is fixed and no changes will be passed upwards ...
				}elsif( exists $lower_passed_ref->{$key} 	){
					### <where> - a lower ref was identified and will be passed upwards for: $key
					$passed_ref = $self->_dispatch_method(
						$up_ref_dispatch,
						$old_branch_ref->[0],
						$key,
						$old_branch_ref,
						$passed_ref,
						$lower_passed_ref,
					);
				}
				#### <where> - new passed ref: $passed_ref
			}
			$x++;
		}
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

sub _will_parse_next_ref{
    my ( $self, $passed_ref ) = @_;
    ### <where> - Made it to _will_parse_next_ref ...
    ##### <where> - Passed ref: $passed_ref
    my  $ref_type = $self->_extracted_ref_type( 
			$passed_ref->{primary_ref},
			$passed_ref->{branch_ref},
	);
    my  $skip_attribute = 'get_skip_' . $ref_type . '_ref';
    ### <where> - The current ref type is : $ref_type
    ### <where> - Skip attribute is       : $skip_attribute
	##### <where> - self: $self
    if( $self->$skip_attribute ){# or $ref_type eq 'SCALAR'
        ### <where> - returning skip -0-
        return 0;
    }
	### <where> - returning: $ref_type
	return $ref_type;
}

sub _has_required_inputs{
    my ( $self, $passed_ref, $lookup_ref ) = @_;
    ### <where> - Made it to _has_required_inputs
    ##### <where> - Passed ref    : $passed_ref
    my ( $fail_ref, $pass_ref, $key_ref );
    for my $key ( keys %$walk_the_data_keys ){
        if( $walk_the_data_keys->{$key} ){
            ### <where> - Found a possibly required value for: $key
            if( (   exists $lookup_ref->{$key} and 
                    exists $passed_ref->{$lookup_ref->{$key}} ) or
                ( !( exists $lookup_ref->{$key} ) and 
                    exists $passed_ref->{$key}          )           ){
				### <where> - passing key: $key
                $pass_ref->{$walk_the_data_keys->{$key}} = 1;
                delete $fail_ref->{$walk_the_data_keys->{$key}};
            }elsif( !( exists $pass_ref->{$walk_the_data_keys->{$key}} ) ){
				### <where> - provisionally failing key: $key
                push @{$fail_ref->{$walk_the_data_keys->{$key}}}, 
                    ( (exists $lookup_ref->{$key}) ?
                        $lookup_ref->{$key} : $key );
            }
        }
		if( exists $passed_ref->{$key} ){
			$key_ref->{$key} = 1;
		}elsif( 	exists $lookup_ref->{$key} and 
					exists $passed_ref->{$lookup_ref->{$key}} ){
			$key_ref->{$lookup_ref->{$key}} = 1;
		}
    }
    my @message;
	#### <where> - fail ref: $fail_ref
	#### <where> - lookup ref: $lookup_ref
	#### <where> - passed ref: $passed_ref
	#### <where> - current message list: @message
	### <where> - the current pass_ref is: $pass_ref
	### <where> - the current key_ref is : $key_ref
	my $attributes_at_level = {};
	for my $key ( keys %$passed_ref ){
		#### <where> - testing for possible attribute adjustments from: $key
		if( exists $key_ref->{$key} or
			( 	exists $lookup_ref->{$key} and
				exists $key_ref->{$lookup_ref->{$key}} ) ){
			#### <where> - No need to investigate: $key
		}else{
			### <where> - checking if there is an attribute named: $key
			if( $self->meta->find_attribute_by_name( $key )  ){#has_attribute
				### <where> - found a one shot attribute setter !!! ...
				my ( $predicate, $writer, $reader, $clearer ) = 
						( $key =~ /^_/ ) ? ( '_', '_', '_', '_', ) : () ;
				$predicate 	.= 	('has_' . $key);
				$writer		.=	('set_' . $key);
				$reader		.=	('get_' . $key);
				$clearer	.= 	('clear_' . $key);
				### <where> - possible predicate: $predicate
				### <where> - possible reader: $reader
				### <where> - possible writer: $writer
				### <where> - possible clearer: $clearer
				my @error_list;
				push @error_list, 'predicate' 	if !$self->can( $predicate );
				push @error_list, 'reader'		if !$self->can( $reader );
				push @error_list, 'writer' 		if !$self->can( $writer );
				push @error_list, 'clearer' 	if !$self->can( $clearer );
				if( @error_list ){
					cluck "The attribute -$key- does not have correctly named methods for the " .
						(join " and the ", @error_list) . " method(s) to allow for auto setting";
				}else{
					### <where> - loading attributes now ...
					if( $self->$predicate ){
						### <where> - First save the old settings ...
						$attributes_at_level->{$key} = $self->$reader;
					}else{
						$attributes_at_level->{$key} = undef;
					}
					### <where> - attribute storage: $attributes_at_level
					### <where> - load the new settings: $passed_ref->{$key}
					$self->$writer( $passed_ref->{$key} );
					delete $passed_ref->{$key};
					##### <where> - self: $self
				}
			}
		}
	}
	for my $item ( keys %$fail_ref ){
		### $item
        my $list = join '- or -', @{$fail_ref->{$item}};
		### $list
        if( @{$fail_ref->{$item}} == 1 ){
            push @message, "The key -$list- is required and must have a value";
        }else{
            push @message, "One or more of the keys -$list- must be passed with a value";
        }
    }
	### <where> - current message list: @message
	confess (join "\n", @message) if @message;
    ### <where> - Made it to _test_inputs
	##### <where> - The current ref state is: $passed_ref
    my %ref_lookup = reverse %$lookup_ref;
    for my $key ( keys %$passed_ref ){
        ### <where> - Testing key: $key
        if( exists $walk_the_data_keys->{$key} ){
            ### <where> - Acceptable passed key: $key
        }elsif( $ref_lookup{$key} and
                exists $walk_the_data_keys->{$ref_lookup{$key}} ){
            ### <where> - Need to modify the key to: $ref_lookup{$key}
			##### <where> - The current ref state is: $passed_ref
            $passed_ref->{$ref_lookup{$key}} = $passed_ref->{$key};
			##### <where> - The current ref state is: $passed_ref
            delete $passed_ref->{$key};
			##### <where> - The current ref state is: $passed_ref
        }else{
            confess "The passed key -$key- is not supported by " . __PACKAGE__;
        }
		#### <where> - Finished testing key: $key
    }
	$self->_add_saved_attribute_level( $attributes_at_level );
    ##### <where> - Final ref state is: $passed_ref
    return $passed_ref;
}
    

sub _secondary_ref_match{
    my ( 	$self, $position, 
			$primary_list_ref,
			$primary_ref_type, 
			$secondary_ref_type, 
			$passed_ref,		) = @_;
    ### <where> - made it to _secondary_ref_match ...
    ### <where> - the passed values are: @_
	### <where> - run the basic match questions first ...
    if(!$self->_had_secondary ){
		### <where> - failed for no pre-existing secondary ...
		return undef;
	}elsif( $primary_ref_type ne $secondary_ref_type ){
		### <where> - failed for mismatched secondary ref type ...
		return undef;
	}elsif( !exists $passed_ref->{secondary_ref} ){
		### <where> - failed for missing secondary ref ...
		return undef;
	}
	### <where> - running the by type matches ...
	my $result = $self->_dispatch_method(
		$secondary_match_dispatch,
		$primary_ref_type,
		$passed_ref->{primary_ref},
		$passed_ref->{secondary_ref},
		$position, $primary_list_ref,
	);
	### <where> - returning: $result
	return $result;
}

sub _restore_attributes{
    my ( $self, ) = @_;
	my ( $answer, ) = (0, );
    ### <where> - reached _restore_attributes ...
	my 	$attribute_ref = $self->_get_saved_attribute_level;
	for my $attribute ( keys %$attribute_ref ){
		### <where> - restoring: $attribute
		my ( $clearer, $writer, ) = (
			('clear_' . $attribute), ('set_' . $attribute),
		);
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

sub _rebuild_hash_level{
    my ( $self, $item_ref, $base_ref ) = @_;
    ### <where> - Made it to _rebuild_hash_level
    ### <where> - item ref  : $item_ref
    ### <where> - base ref  : $base_ref
	return { $item_ref->[1] => $base_ref };
}

sub _rebuild_array_level{
    my ( $self, $item_ref, $base_ref ) = @_;
    ### <where> - Made it to _rebuild_array_level
    ### <where> - item ref  : $item_ref
    ### <where> - base ref  : $base_ref
	my  $array_ref = [];
	$array_ref->[$item_ref->[2]] = $base_ref;
	return $array_ref;
}

sub _load_hash_up{
    my ( $self, $key, $branch_ref_item, $passed_ref, $lower_passed_ref ) = @_;
    ### <where> - Made it to _load_hash_up for the: $key
	### <where> - the branch ref is: $branch_ref_item
	##### <where> - passed info: @_
	$passed_ref->{$key}->{$branch_ref_item->[1]} = 
		$lower_passed_ref->{$key};
	##### <where> - the new passed_ref is: $passed_ref
	return $passed_ref;
}

sub _load_array_up{
    my ( $self, $key, $branch_ref_item, $passed_ref, $lower_passed_ref ) = @_;
    ### <where> - Made it to _load_array_up for the: $key
	### <where> - the branch ref is: $branch_ref_item
	$passed_ref->{$key}->[$branch_ref_item->[2]] = 
		$lower_passed_ref->{$key};
	##### <where> - the new passed_ref is: $passed_ref
	return $passed_ref;
}

sub _clear_had_secondary{
	my ( $self, ) = @_;
	### <where> - setting _had_secondary to 0 ...
	$self->_set_had_secondary( 0 );
	return 1;
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

sub _get_object_methods{
    my ( $self, $data_reference ) = @_;
    ### <where> - Made it to _object_has_methods ...
	##### <where> - passed reference: $data_reference
	my $list_ref;
	if( $data_reference->can( 'meta' ) ){
		### <where > - moose object found ...
		confess "Moose objects are not yet supported for parsing";
	}else{
		### <where> - not a moose object ...
		my	$method_ref = Class::Inspector->methods( 
				ref( $data_reference ), 
		);
		### <where> - all methods: $method_ref
		return $method_ref;
	}
	return [];
	my $scalar_util_val = reftype( $data_reference );
	### <where> - Scalar-Util-reftype: $scalar_util_val
}

sub _get_object_attributes{
    my ( $self, $data_reference ) = @_;
    ### <where> - Made it to _get_object_attributes ...
	##### <where> - passed reference: $data_reference
	my $list_ref;
	my $scalar_util_val = reftype( $data_reference );
	### <where> - Scalar-Util-reftype: $scalar_util_val
	my $attribute_list_ref = $self->_dispatch_method(
		$node_list_dispatch,
		$scalar_util_val,
		$data_reference,
	);
	### <where> - the attribute list is: $attribute_list_ref
	return $attribute_list_ref;
}

sub _get_object_element{
    my ( $self, $data_reference, $item, $position ) = @_;
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
	}else{
		confess "Get methods element not written yet";
	}
	### <where> - the attribute list is: $item_ref
	$wait = <>;
	return $item_ref;
}


#################### Phinish with a Phlourish ###########################################

no Moose;
__PACKAGE__->meta->make_immutable;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin #######################################

__END__

=head1 NAME

Data::Walk::Extracted - An extracted dataref walker

=head1 SYNOPSIS
    
	#!perl
	use Modern::Perl;
	use YAML::Any;
	use Moose::Util qw( with_traits );
	use Data::Walk::Extracted v0.015;
	use Data::Walk::Print v0.009;

	$| = 1;

	#Use YAML to compress writing the data ref
	my  $firstref = Load(
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
						BottomKey1: 12345
						BottomKey2:
						- bavalue1
						- bavalue2
						- bavalue3'
	);
	my  $secondref = Load(
		'---
		Someotherkey:
			value
		Helping:
			- Somelevel
			- MyKey:
				MiddleKey:
					LowerKey1: lvalue1
					LowerKey2:
						BottomKey2:
						- bavalue1
						- bavalue2
						BottomKey1: 12354'
	);
	my $AT_ST = with_traits( 
			'Data::Walk::Extracted', 
			( 'Data::Walk::Print' ),
		)->new(
			match_highlighting => 1,#This is the default
		);
	$AT_ST->print_data(
		print_ref	=>  $firstref,
		match_ref	=>  $secondref,
		sort_HASH	=> 1,#To force order for demo purposes
	);
    
    ############################################################################
    #     Output of SYNOPSIS
    # 01:{#<--- Ref Type Match
    # 02:	Helping => [#<--- Secondary Key Match - Ref Type Match
    # 03:		'Somelevel',#<--- Secondary Position Exists - Secondary Value Matches
    # 04:		{#<--- Secondary Position Exists - Ref Type Match
    # 05:			MyKey => {#<--- Secondary Key Match - Ref Type Match
    # 06:				MiddleKey => {#<--- Secondary Key Match - Ref Type Match
    # 07:					LowerKey1 => 'lvalue1',#<--- Secondary Key Match - Secondary Value Matches
    # 08:					LowerKey2 => {#<--- Secondary Key Match - Ref Type Match
    # 09:						BottomKey1 => '12345',#<--- Secondary Key Match - Secondary Value Does NOT Match
    # 10:						BottomKey2 => [#<--- Secondary Key Match - Ref Type Match
    # 11:							'bavalue1',#<--- Secondary Position Exists - Secondary Value Matches
    # 12:							'bavalue2',#<--- Secondary Position Exists - Secondary Value Does NOT Match
    # 13:							'bavalue3',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match
    # 14:						],
    # 15:					},
    # 16:				},
    # 17:			},
    # 18:		},
    # 19:	],
    # 20:	Parsing => {#<--- Secondary Key Mismatch - Ref Type Mismatch
    # 21:		HashRef => {#<--- Secondary Key Mismatch - Ref Type Mismatch
    # 22:			LOGGER => {#<--- Secondary Key Mismatch - Ref Type Mismatch
    # 23:				run => 'INFO',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match
    # 24:			},
    # 25:		},
    # 26:	},
    # 27:	Someotherkey => 'value',#<--- Secondary Key Match - Secondary Value Matches
    # 28:},
    ##############################################################################

    
=head1 DESCRIPTION

This module takes a data reference (or two) and L<recursivly|http://en.wikipedia.org/wiki/Recursion_(computer_science)> 
travels through it(them).  Where the two references diverge the walker follows the 
primary data reference.  At the L<beginning|/Assess and implement the before_method> 
and L<end|/Assess and implement the after_method> of each L</node> the code will 
attempt to call a L<method|/Extending Data::Walk::Extracted> using data from the 
current location of the node.

=head2 Definitions

=head3 node

Each branch point of a data reference is considered a node.  The original top level 
reference is the 'zeroth' node.  Recursion 'Base state' nodes are understood to have 
zero elements so an additional node called 'END' type is recognized after a scalar.

=head2 Caveat utilitor

This is not an extention of L<Data::Walk|https://metacpan.org/module/Data::Walk>

This module uses the 'L<defined or|http://perldoc.perl.org/perlop.html#Logical-Defined-Or>' 
(  //= ) and so requires perl 5.010 or higher.

This is a L<Moose|https://metacpan.org/module/Moose::Manual> based data handling 
class.  Many L<software developers|http://en.wikipedia.org/wiki/Software_developer> will 
tell you Moose and data manipulation don't belong together.  They are most certainly right in 
startup-time critical circumstances.

Recursive parsing is not a good fit for all data since very deep data structures will consume a 
fair amount of computer memory!  The code leaves in memory a snapshot of the active data at 
the previous node when it travels down the data tree.  This means that the memory foot print of 
the originally passed primary ref and secondary ref (and a few other data points) are multiplied 
many times as a function of the depth of the data structure.

L<This class has no external effect!|/Extending Data::Walk::Extracted>  all output 
L<above|/SYNOPSIS> is from the role 
L<Data::Walk::Print>

The L<primary_ref|/B<primary_ref> - a> and L<secondary_ref|/B<secondary_ref> - a> are 
effectivly deep cloned during this process.  To leave the primary_ref pointer intact see 
L</fixed_primary>
 
The L</COPYRIGHT> is down lower.

=head3 Supported node walking types

=over

=item ARRAY

=item HASH

=item SCALAR

=back

=head3 Other node support

Support for Objects is partially implemented and as a consequence '_process_the_data' won't 
immediatly die when asked to parse an object.  It will still die but on a dispatch table 
call that indicates where there is missing object support not at the top of the node.

=head3 Supported one shot L</Attributes>

=over

=item sort_HASH

=item sort_ARRAY

=item skip_HASH_ref

=item skip_ARRAY_ref

=item skip_SCALAR_ref

=item change_array_size

=item fixed_primary

=back

=head2 What is the unique value of this module?

With the recursive part of data walking extracted the various functionalities desired 
when walking the data can be modularized without copying this code.  The Moose 
framework also allows diverse and targeted data parsing without dragging along a 
L<kitchen sink|http://en.wiktionary.org/wiki/everything_but_the_kitchen_sink> API 
for every implementation of this Class.

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

=head2 Extending Data::Walk::Extracted

All action taken during the data walking must be initiated by implementation of action methods 
that do not exist in this class.  They can be added with a traditionally incorporated Role 
L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles>, by L<extending the 
class|https://metacpan.org/module/Moose::Manual::Classes>, or attaching a role with the 
needed functionality at run time using 'with_traits' from 
L<Moose::Util|https://metacpan.org/module/Moose::Util>.  See the internal method 
L<_process_the_data|/_process_the_data( $passed_ref, $conversion_ref ) - internal> to see 
the detail of how these methods are incorporated and review the L</Recursive Parsing Flow> 
to understand the details of how the methods are used.

=head3 What is the recomended way to build a role that uses this class?

First build a method to be used when the class L<reaches|/Assess and implement the before_method> 
a data L</node> and another to be used when the class L<leaves|/Assess and implement the after_method> 
a data node (as needed).   Then create the 'action' method for the role.  This would preferably 
be named something descriptive like 'mangle_data'.  Remember if more than one role is added to 
Data::Walk::Extracted then all methods should be named with all method names considered.  This 
method should L<compose|/An Example> any required node action methods and data references into a 
$passed_ref and possibly a $conversion_ref to be used by L<_process_the_data|/_process_the_data( 
$passed_ref, $conversion_ref ) - internal> .  Then the 'action' method should call;

	$passed_ref = $self->_process_the_data( $passed_ref, $conversion_ref );

Afterwards returning anything from the $passed_ref of interest.

Finally, L<Write some tests for your role!|http://www.perlmonks.org/?node_id=918837>

=head1 Methods

=head2 Methods used to write Roles

=head3 _process_the_data( $passed_ref, $conversion_ref ) - internal

=over

=item B<Definition:> This method is the core access to the recursive parsing of 
Data::Walk::Extracted.  While the method is listed as a private (leading underscore) 
method it is intended to be used by consuming roles or classes.  To use this method 
you compose this class with a role or inherit this class and then send the needed 
information from your code to this method and this method will scub the data inputs 
and send them to the recusive parser.  Extentions or roles that use this method are 
expected to compose and pass the following data to this method.

=item B<Accepts:> ( $passed_ref, $conversion_ref )

=over 

=item B<$passed_ref> this ref contains key value pairs as follows;

=over 

=item B<primary_ref> - a dataref that the walker will walk - required

=item B<secondary_ref> - a dataref that is used for comparision while walking - 
optional

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
			First_key => 'second_value',
		},
		before_method	=> '_print_before_method',
		after_method	=> '_print_after_method',
		sort_Array	=> 1,#One shot attribute setter
	}

	$conversion_ref ={
		primary_ref	=> 'print_ref',# generic_name => role_name,
		secondary_ref	=> 'match_ref',
	}

=back

=item B<Action:> This method begins by scrubing the top level of the inputs and 
ensures that the minimum requirements for the recursive data parser are met.  
If needed it will use a conversion ref (also provided by the caller) to change 
input hash keys to the generic hash keys used by this class.  When the recursive 
data walker is called it walks through the passed 
L<primary_ref|/B<primary_ref> - a dataref that the walker will walk> data structure.  
Each time the walker reaches a L</node> it will attempt to call a provided 
L<before_method|/Assess and implement the before_method>.  It will then check if the 
L<secondary_ref|/B<secondary_ref> -> matches, See the L</Recursive Parsing Flow> for 
more information.  At this point it will recursivly walk the node.  After the node 
has been processed it will attempt to call an 
L<after_method|/Assess and implement the after_method>.  The before_method and 
after_method are allowed to change the primary_ref and secondary_ref.


=item B<Returns:> the $passed_ref (only) with the key names restored to their 
L<original|/B<$conversion_ref> This allows a public> versions.

=back

=head3 _build_branch( $seed_ref, @arg_list ) - internal

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

=head3 _extracted_ref_type( $test_ref ) - internal

=over

=item B<Definition:> In order to manage data types necessary for this class a data 
walker compliant type tester is provided.  This is necessary to support a few non 
perl-standard types.  First, the base state 'END' is treated as a data type and is not generated 
in the normal perl data typing systems.  Second, strings and numbers both return as 
'SCALAR' (not '' or undef).  B<For the purposes of this class you should always call 
this attribute to get the correct data type when using dispatch tables!>

=item B<Accepts:> This method expects to be called by $self.  It receives a data 
reference that can include undef.

=item B<Returns:> a data walker type or it confesses.  (For more details see 
$discover_type_dispatch in the code)

=back

=head3 _dispatch_method( $dispatch_ref, $call, @arg_list ) - internal

=over

=item B<Definition:> To make this class extensible, the majority of the decision points 
are managed by dispatch (hash) tables.  In order to have the dispatch behavior common across 
all methods the dispatch call is provided for all consuming classes and rolls.

=item B<Accepts:> This method expects to be called by $self.  It first receives the dispatch 
table (hash) as a data reference. Next, the L<data type|/_extracted_ref_type( $test_ref ) - internal> 
is accepted as $call.  Finally, any arguments needed by the dispatch table are passed through in 
@arg_list.

=item B<Returns:> defined by the dispatch table

=back

=head2 Public Methods

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

=head1 Attributes

Data passed to ->new when creating an instance.  For modification of these attributes 
see L</Public Methods>.  The ->new function will either accept fat comma lists or a complete 
hash ref that has the possible appenders as the top keys.  Additionally some attributes 
that meet the criteria can be passed to 
L<_process_the_data|/B<[attribute name]> - attribute names are> and will be adjusted 
for just the run of that method call.  These are called L<one shot|/Supported one shot > 
attributes.

=head3 sort_HASH 

=over

=item B<Definition:> This attribute is set to sort (or not) Hash Ref keys prior to walking the 
Hash Ref node.

=item B<Default> 0 (No sort)

=item B<Range> Boolean values and L<sort|http://perldoc.perl.org/functions/sort.html> coderefs.
    
=back

=head3 sort_ARRAY

=over

=item B<Definition:> This attribute is set to sort (or not) Array values prior to walking the 
Array Ref node.  B<Warning> this will permanantly sort the actual data in the passed ref 
permanently.  If a secondary ref also exists it will NOT be sorted!  Sorting Arrays is 
not recommended.

=item B<Default> 0 (No sort)

=item B<Range> Boolean values and L<sort|http://perldoc.perl.org/functions/sort.html> coderefs.

=back

=head3 skip_HASH_ref

=over

=item B<Definition:> This attribute is set to skip (or not) the processing of HASH Ref nodes.

=item B<Default> 0 (Don't skip)

=item B<Range> Boolean values.

=back

=head3 skip_ARRAY_ref

=over

=item B<Definition:> This attribute is set to skip (or not) the processing of ARRAY Ref nodes.

=item B<Default> 0 (Don't skip)

=item B<Range> Boolean values.

=back

=head3 skip_SCALAR_ref

=over

=item B<Definition:> This attribute is set to skip (or not) the processing of SCALAR's 
of ref branches.

=item B<Default> 0 (Don't skip)

=item B<Range> Boolean values.

=back

=head3 change_array_size

=over

=item B<Definition:> This attribute will not be used by this class directly.  However 
the L<Data::Walk::Prune> Role and the L<Data::Walk::Graft> Role both use it so it is 
placed here so there will be no conflicts.

=item B<Default> 1 (This usually means that the array will grow or shrink when a position 
is added or removed)

=item B<Range> Boolean values.

=back

=head3 fixed_primary

=over

=item B<Definition:> This attribute will leaved the primary_ref data ref intact rather 
than deep cloning it.  This also means that no changes made at lower levels will be passed 
upwards.

=item B<Default> 0 = The primary ref is not fixed (and will be changed / deep cloned)

=item B<Range> Boolean values.

=back

=head1 Recursive Parsing Flow

=head2 Assess and implement the before_method

When the recursive process is called, the class checks for an available 'before_method'.  Using the test; 

	exists $passed_ref->{before_method};

If the test passes then the next sequence is run.

	$method = $passed_ref->{before_method};
	$passed_ref = $self->$method( $passed_ref );

Then if the new $passed_ref contains the key $passed_ref->{bounce} or is undef the 
program deletes the key 'bounce' from the $passed_ref (as needed) and then returns 
$passed_ref directly back up the data tree.  I<Do not pass 'Go' do not collect $200.>  
Otherwise the $passed_ref is sent on to the node parser.  If the $passed_ref is modified 
by the 'before_method' then the node parser will parse the new ref and not the old one. 

=head2 Determine node type

The current node is examined to determine it's reference type. A node type below SCALAR 
called 'END' is generated to manage the 'before_method' and 'after_method' implementation.  
The relevant L<skip attribute|/skip_HASH_ref> is consulted and if this node should be 
skipped then the program goes directly to the L</Assess and implement the after_method> 
step.

=head2 Identify node elements

If the node type is not skipped then a list is generated for all paths within a node.  
For example a 'HASH' node would generate a list of hash keys for that node.  SCALARs 
are considered 'SCALAR' types and are handled as single element nodes with the scalar 
value as the only item in the list.  'END' nodes always have the empty set for this 
step. If the list L<should be sorted|/sort_HASH> then the list is sorted. The node is 
then tested for an empty set.  If the set is empty this is considered a 'base state' 
and the code skips to the L</Assess and implement the after_method> step else the code 
sends the list to L</Iterate through each element>.

=head2 Iterate through each element

For each element a new L<$passed_ref|/B<$passed_ref> this ref contains key value pairs as follows;> 
is generated containing the data below that element.  The secondary_ref is only constructed 
if it has a matching element to the primary ref.  Matching for hashrefs is done by key 
matching only.  Matching for arrayrefs is done by testing if the secondary_ref has the 
same array position available as the primary_ref. I<No position content compare is done!>  

=head3 A position trace is generated

The current node list position is then documented using an internally managed key of the 
$passed_ref labeled B<branch_ref>.  The array reference stored in branch_ref can be thought of 
as the stack trace that documents the node elements directly between the current position and 
the top (or zeroth) level of the parsed data_ref.  Past completed branches and future pending 
branches are not shown.  Each element of the branch_ref contains four positions used to describe 
the node and selections used to traverse that node level.  The values in each sub position are; 

	[
		ref_type, #The node reference type
		the list item value or '' for ARRAYs, #key name for hashes, scalar value for scalars
		element sequence position (from 0),#For hashes this is only relevent if sort_HASH is called
		level of the node (from 0),#The zeroth level is the passed data ref
	]

=head2 Going deeper in the data

The new (sub) $passed_ref is then passed as a new data set to be parsed and it starts 
at L</Assess and implement the before_method>. 

=head2 Actions on return from recursion

When the values are returned from the recursion call the last branch_ref element is 
L<pop|http://perldoc.perl.org/functions/pop.html>ed off and the returned value(s) 
is(are) used to L<replace|/fixed_primary> the sub elements of the primary_ref and secondary_ref 
associated with that list element in the current $passed_ref.  If there are still pending items in 
the node element list then the program returns to L</Iterate through each element> else it moves to 
L</Assess and implement the after_method>.


=head2 Assess and implement the after_method

The class checks for an available 'after_method' using the test;

	exists $passed_ref->{after_method};

If the test passes then the following sequence is run.

	$method = $passed_ref->{after_method};
	$passed_ref = $self->$method( $passed_ref );

=head2 Go up

The updated $passed_ref is passed back up to the next level.

=head1 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> if the '-ENV' option is set.  The 'use' is 
encapsulated in a BEGIN block triggered by the environmental variable to comfort 
non-believers.  Setting the variable $ENV{Smart_Comments} will load and turn 
on smart comment reporting.  There are three levels of 'Smartness' available 
in this module '### #### #####'.

=back

=head1 SUPPORT

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item * Support recursion through CodeRefs

=item * Support recursion through Objects

=item * Add a Data::Walk::Top Role to the package

=item * Add a Data::Walk::Thin Role to the package

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

=item L<5.010>

=item L<version>

=item L<Carp>

=item L<Moose>

=item L<MooseX::StrictConstructor>

=item L<MooseX::Types::Moose>

=item L<Scalar::Util>

=item L<Class::Inspector>

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

#################### main pod documentation end #########################################