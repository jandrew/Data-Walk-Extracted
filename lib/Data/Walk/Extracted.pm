package Data::Walk::Extracted;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use version; our $VERSION = qv('0.011_001');
use Carp qw( carp croak confess cluck );
use Smart::Comments -ENV;
use YAML::Any;
### Smart-Comments turned on for Data-Walk-Extracted
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

###############  Package Variables  #####################################################

$| = 1;
my $wait;
my $attribute_backup = {};

###############  Dispatch Tables  #######################################################
	
my $walk_the_data_keys = {
    primary_ref		=> 1,#Required
    secondary_ref   => 0,#Optional
    before_method	=> 2,#One or the other of two required
    after_method	=> 2,#One or the other of two required
    branch_ref		=> 0,#Don't generally use
};

my $supported_types = {######<--------------------------------------  ADD New types here
    'HASH'		=> 'is_HashRef',
    'ARRAY'		=> 'is_ArrayRef',
    'SCALAR'	=> 'is_Str',
    'END'		=> 1,
};

my  $reconstruction_dispatch = {######<-----------------------------  ADD New types here
    'HASH'	=> \&_rebuild_hash_level,
    'ARRAY' => \&_rebuild_array_level,
};

my  $node_list_dispatch = {######<----------------------------------  ADD New types here
    'HASH'		=> sub{ [ keys %{$_[1]} ] },
    'ARRAY'		=> sub{
						my $list;
						map{ push @$list, 1 } @{$_[1]};
						return $list;
					},
    'SCALAR'	=> sub{ [ $_[1] ] },
    'END'		=> sub{ return [] },
};

my  $sub_ref_dispatch = {######<------------------------------------  ADD New types here
    'HASH'		=> sub{ $_[1]->{$_[2]->[1]} },
    'ARRAY'		=> sub{ $_[1]->[$_[2]->[2]] },
    'SCALAR'	=> sub{ return undef; },
};

my $branch_ref_item_dispatch = {######<-----------------------------  ADD New types here
    'HASH'		=> sub{ return $_[1]; },
    'ARRAY'		=> sub{ return undef; },
    'SCALAR'	=> sub{ return $_[1]; },
};

my $secondary_match_dispatch = {######<-----------------------------  ADD New types here
	'HASH'		=> 	sub{
						return (
							( exists $_[1]->{$_[4]->[$_[3]]} ) and
							( exists $_[2]->{$_[4]->[$_[3]]} )
						) ?	1 : 0 ;
					},
    'ARRAY'		=> sub{
						return (
							( exists $_[1]->[$_[3]] ) and
							( exists $_[2]->[$_[3]] )
						) ?	1 : 0 ;
					},
    'SCALAR'	=> sub{
						return (
							$_[1] eq $_[2]
						) ?	1 : 0 ;
					},
};

my $up_ref_dispatch = {######<--------------------------------------  ADD New types here
	HASH	=> \&_load_hash_up,
    ARRAY 	=> \&_load_array_up,
	SCALAR	=> sub{
		### <where> - made it to SCALAR ref upload ...
		$_[3]->{$_[1]} = $_[2]->[1];
		### <where> - returning: $_[3]
		return $_[3];
	},
};

###############  Public Attributes  #####################################################

for my $type ( keys %$supported_types ){
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
    is		=> 'ro',
    isa     => Bool,
	writer	=> '_has_secondary',
    default	=> 0,
);

has '_single_pass_attributes' =>(
	is		=> 'ro',
	isa		=> ArrayRef,
	traits	=> ['Array'],
	reader	=> '_get_single_pass_attributes',
	default	=> sub{ [] },
    handles => {
        _add_single_pass_attribute		=> 'push',
		_count_single_pass_attributes	=> 'count',
		_clear_single_pass_set			=> 'clear',
    },
);

###############  Private Methods / Modifiers  ###########################################

sub _process_the_data{#Used to scrub high level input
    ### <where> - Made it to _process_the_data
    ##### <where> - Passed input  : @_
    my ( $self, $passed_ref, $conversion_ref ) = @_;
    ##### <where> - Passed hashref: $passed_ref
    ##### <where> - $self: $self
    ### <where> - review the ref keys for requirements and conversion
    $passed_ref = $self->_has_required_inputs( $passed_ref, $conversion_ref );
	##### <where> - Passed hashref: $passed_ref
	##### <where> - self: $self
    $self->_has_secondary( ( exists $passed_ref->{secondary_ref}) ? 1 : 0);
	### <where> - has secondary flag is: $self->_had_secondary
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
    ##### <where> - End recursive passing with: $passed_ref
	if( $self->_count_single_pass_attributes ){
		### <where> - restoring instance clone attributes ...
		$self->_restore_attributes;
	}
    return $passed_ref;
}

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
    my  $ref_type   = $self->_will_parse_next_ref( $passed_ref );
    if( $ref_type ){
		my  $secondary_ref_type = 
			$self->_extracted_ref_type( $passed_ref->{secondary_ref} );
		### <where> - Parse the node for type: $ref_type
		### <where> - Secondary ref type: $secondary_ref_type
		my $primary_list_ref = $self->_get_list( 
			$ref_type,
			$passed_ref->{primary_ref},
		);
		### <where> - Run the node list: $primary_list_ref
        $passed_ref = $self->_cycle_the_list( 
			$passed_ref,
			$primary_list_ref,
			$ref_type,
			$secondary_ref_type,
		);
		### <where> - back to _walk_the_data after going through the list ...
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
    ### <where> - Made it to _will_parse_next_ref
    ##### <where> - Passed ref: $passed_ref
    my  $ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
    my  $skip_attribute = 'get_skip_' . $ref_type . '_ref';
    my  $skip_ref       = $self->$skip_attribute;
    ### <where> - The current ref type is : $ref_type
    ### <where> - Skip attribute is       : $skip_attribute
    ### <where> - Skip attribute method call: $self->$skip_attribute
    ### <where> - Skip ref status is      : $skip_ref
    if( $skip_ref ){# or $ref_type eq 'SCALAR'
        ### <where> - returning skip -0-
        return 0;
    }elsif( exists $supported_types->{$ref_type} and
				$supported_types->{$ref_type}           			){
        ### <where> - returning: $ref_type
        return $ref_type;
    }else{
        croak "The passed reference type -$ref_type- cannot (yet) " .
			"be processed by " . __PACKAGE__;
    }
}

sub _cycle_the_list{
    my ( 
		$self, $passed_ref, $primary_list_ref,
		$primary_ref_type, $secondary_ref_type,
	) = @_;
	my ( $lower_passed_ref );
    ### <where> - Made it to _cycle_the_list
    ##### <where> - Passed ref	: $passed_ref
    ##### <where> - ref type	: $primary_ref_type
    ##### <where> - ref list	: $primary_list_ref
    ##### <where> - secondary ref: $secondary_ref_type
    ### <where> - running a list size of: scalar( @$primary_list_ref )
	map{ push @{$lower_passed_ref->{branch_ref}}, $_ } @{$passed_ref->{branch_ref}};
	my $x = 0;
	for my $item ( @$primary_list_ref ){
		### <where> - processing item: $item
		### <where> - building the next branch_ref item ...
		my	$branch_ref_item = [
            $primary_ref_type, 
			$self->_dispatch_method(
				$branch_ref_item_dispatch,
				$primary_ref_type,
				$item 
			),
            $x,
            ((exists $passed_ref->{branch_ref} and @{$passed_ref->{branch_ref}}) ?
                ($passed_ref->{branch_ref}->[-1]->[3] + 1) : 1),
		];
		#### <where> - next branch ref item is: $branch_ref_item
		push @{$lower_passed_ref->{branch_ref}}, $branch_ref_item;
		##### <where> - next passed ref so far: $lower_passed_ref
		### <where> - building the next level primary_ref item ...
		$lower_passed_ref->{primary_ref} = $self->_dispatch_method(
				$sub_ref_dispatch,
				$primary_ref_type,
				$passed_ref->{primary_ref},
				$branch_ref_item,
			);
		#### <where> - next primary_ref item is: $lower_passed_ref->{primary_ref}
		##### <where> - next passed ref so far: $lower_passed_ref
		### <where>checking if the secondary_ref is needed ...
        if( $self->_secondary_ref_match( 
			$x, $primary_list_ref,
			$primary_ref_type, 
			$secondary_ref_type, 
			$passed_ref, 				) ){
			### <where> - Matching secondary_ref found ...
			$lower_passed_ref->{secondary_ref} = $self->_dispatch_method(
					$sub_ref_dispatch,
					$secondary_ref_type,
					$passed_ref->{secondary_ref},
					$branch_ref_item,
				);
        }else{
			### <where> - The secondary_ref does not match ...
            delete $lower_passed_ref->{secondary_ref};
        }
		##### <where> - next passed ref so far: $lower_passed_ref
		if( exists $passed_ref->{before_method} ){
            $lower_passed_ref->{before_method} = $passed_ref->{before_method};
        }
        if( exists $passed_ref->{after_method} ){
            $lower_passed_ref->{after_method} = $passed_ref->{after_method};
        }
        ##### <where> - Passing the data: $lower_passed_ref
        my $lower_passed_ref = $self->_walk_the_data( $lower_passed_ref );
        ##### <where> - The current passed ref is: $passed_ref
		##### <where> - The current returned ref is: $lower_passed_ref
        ### <where> - pass any data reference adjustments upward ...
		#### <where> - using branch ref: $branch_ref_item
		for my $key ( 'primary_ref' , 'secondary_ref' ){
			### <where> - processing: $key
			if( $key eq 'primary_ref' and
				$self->has_fixed_primary and
				$self->get_fixed_primary 		){
				### <where> - the primary ref is fixed and no changes will be passed upwards ...
			}elsif( exists $lower_passed_ref->{$key} 	){
				### <where> - a lower ref was identified and will be passed upwards for: $key
				$passed_ref = $self->_dispatch_method(
					$up_ref_dispatch,
					$branch_ref_item->[0],
					$key,
					$branch_ref_item,
					$passed_ref,
					$lower_passed_ref,
				);
			}
			#### <where> - new passed ref: $passed_ref
		}
		pop @{$lower_passed_ref->{branch_ref}};
		$x++;
    }
    return $passed_ref;
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
	#### $fail_ref
	#### $lookup_ref
	#### $passed_ref
	#### @message
	### <where> - the current pass_ref is: $pass_ref
	### <where> - the current key_ref is : $key_ref
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
				my ( $predicate, $writer, $reader, $clearer ) = (
					('has_' . $key), ('set_' . $key), ('get_' . $key), ( 'clear_' . $key),
				);
				### <where> - possible predicate	: $predicate
				### <where> - possible reader		: $reader
				### <where> - possible writer			: $writer
				### <where> - possible clearer		: $clearer
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
						$attribute_backup->{$key} = $self->$reader;
					}
					### <where> - load the new settings: $passed_ref->{$key}
					$self->$writer( $passed_ref->{$key} );
					delete $passed_ref->{$key};
					$self->_add_single_pass_attribute( $key );
				}
			}else{
				for my $attr ( $self->meta->get_all_attributes ){
					### <where> - result of test: $attr->name
				}
				### <where> - Could not recognize the attribute: $key
				##### <where> - self: $self
			}
			#~ exit 1;
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
	### @message
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
	##### <where> - Final ref state is: $passed_ref
    return $passed_ref;
}

sub _extracted_ref_type{
    my ( $self, $passed_ref ) = @_;
    ### <where> - made it to _extracted_ref_type
    ##### <where> - the passed ref is: $passed_ref
    my  $response =
            ( !( defined $passed_ref ) ) ?
                'END' :
            is_Ref( $passed_ref ) ?
                ref $passed_ref : 
                'SCALAR' ;
	if( !( exists $supported_types->{$response} ) ){
		confess "Attempting to parse the unsupported node type -" .
			$response . "-";
	}
    ### <where> - returning: $response
    return $response;
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
    }else{
        confess "Failed to find the '$call' dispatch";
    }
}

sub _restore_attributes{
    my ( $self, ) = @_;
	my ( $answer, ) = (0, );
    ### <where> - reached _restore_attributes ...
	for my $attribute ( @{$self->_get_single_pass_attributes} ){
		### <where> - restoring: $attribute
		my ( $clearer, $writer, ) = (
			('clear_' . $attribute), ('set_' . $attribute),
		);
		### <where> - possible predicate	: $clearer
		### <where> - possible writer		: $writer
		$self->$clearer;
		if( exists $attribute_backup->{$attribute} ){
			### <where> - data exists to backup: $attribute_backup->{$attribute}
			$self->$writer( $attribute_backup->{$attribute} );
			delete $attribute_backup->{$attribute};
		}
		### <where> - finished restoring: $attribute
	}
	return 1;
}

sub _build_branch{
    my ( $self, $base_ref, @arg_list ) = @_;
    ### <where> - Made it to _build_branch;
    ### <where> - base ref : $base_ref
    ##### <where> - the passed arguments  : @arg_list
    if( @arg_list ){
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

sub _get_list{
    my ( $self, $ref_type, $data_ref ) = @_;
    ### <where> - Made it to _get_list for: $data_ref
	my 	$list_ref = $self->_dispatch_method( 
				$node_list_dispatch,
				$ref_type,
				$data_ref,
			);
	### <where> - checking if the list should be sorted for the type: $ref_type
	#### <where> - sorting the list as needed for: $list_ref
	my  $sort_attribute = 'get_sort_' . $ref_type;
	### <where> - Sort attribute: $sort_attribute
	### <where> - Sort setting  : $self->$sort_attribute
	if(	$self->meta->find_method_by_name( $sort_attribute ) and
		$self->$sort_attribute										){
		### <where> - The list should be sorted ...
		my $sort_function =  ( is_CodeRef(  $self->$sort_attribute ) ) ? ########   PARTIALLY TESTED !!!! ######
				$self->$sort_attribute : sub{ $a cmp $b };
		$list_ref = [ sort $sort_function @$list_ref ];
		if( is_ArrayRef( $data_ref ) ){
			### <where> - This is an array ref and the array ref will be sorted ...
			# THIS MAY BE LOCALIZED, BUT THE INTENT IS FOR IT TO BE GLOBAL!!!
			$data_ref = [sort $sort_function @$data_ref];
		}
	}else{
		### <where> - the list will not be sorted ...
	}
	### <where> - final list ref: $list_ref
	return $list_ref;
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
	use Data::Walk::Extracted v0.011;
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

This module takes a data reference (or two) and L<recursivly|/Recursive Parsing Flow> 
travels through it(them).  Where the two references diverge the walker follows the 
primary data reference.  At the L<beginning|/First> and L<end|/Fourth> of each 
L</node> the code will attempt to call a 
L<method|/Extending Data::Walk::Extracted> using data from the current location 
of the node.

=head2 Definitions

=head3 node

Each branch point of a data reference is considered a node.  The original top level reference 
is the 'zeroth' node.

=head2 Caveat utilitor

This is not an extention of L<Data::Walk|https://metacpan.org/module/Data::Walk>

This module uses the 'L<defined or|http://perldoc.perl.org/perlop.html#Logical-Defined-Or>' 
(  //= ) and so requires perl 5.010 or higher.

This is a L<Moose|https://metacpan.org/module/Moose::Manual> based data handling 
class.  Many L<software developers|http://en.wikipedia.org/wiki/Software_developer> will 
tell you Moose and data manipulation don't belong together.  They are most certainly right in 
startup-time critical circumstances.

Recursive parsing is not a good fit for all data since very deep data structures will consume a 
fair amount of computer memory!  As the module recursively parses through each level of data 
the code leaves behind a snapshot of the previous level that allows it to keep track of it's 
location.

L<This class has no external effect!|/Extending Data::Walk::Extracted>  all output 
L<above|/SYNOPSIS> is from 
L<Data::Walk::Print|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Print.pm>

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
L<Kitchen sink|http://en.wiktionary.org/wiki/everything_but_the_kitchen_sink> API 
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
that do not exist in this Class.  They can be added with a traditionally incorporated Role 
L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles>, by L<extending the 
class|https://metacpan.org/module/Moose::Manual::Classes>, or attaching a Role with the 
needed functionality at run time using 'with_traits' from 
L<Moose::Util|https://metacpan.org/module/Moose::Util>.  See the internal method 
L<_process_the_data|/_process_the_data( $passed_ref, $conversion_ref ) - internal> to see 
the detail of how these methods are incorporated and review the L</Recursive Parsing Flow> 
to understand the details of how the methods are used.

=head2 What is the recomended way to build a role that uses this class?

First build a method to be used when the Class L<reaches|/First> a data L</node> and another 
to be used when the Class L<leaves|/Fourth> a data node (as needed).   Then create the 'action' 
method for the role.  This would preferably be named something descriptive like 'mangle_data'.  
Remember if more than one Role is added to Data::Walk::Extracted then this method should be 
named with namespace considerations in mind.  This method should L<compose|/An Example> 
any required node action methods and data references into a $passed_ref and possibly a 
$conversion_ref to be used by L<_process_the_data|/_process_the_data( $passed_ref, 
$conversion_ref ) - internal> .  Then the 'action' method should call;

	$passed_ref = $self->_process_the_data( $passed_ref, $conversion_ref );

Afterwards returning anything from the $passed_ref of interest.

Finally, L<Write some tests for your role!|http://www.perlmonks.org/?node_id=918837>

=head1 Methods

=head2 Methods used to write Roles

=head3 _process_the_data( $passed_ref, $conversion_ref ) - internal

=over

=item B<Definition:> This method is the primary method call used when extending the 
class and implementing some public method that will act when walking through a data 
structure.  This module recursively walks through the passed 
L<primary_ref|/B<primary_ref> - a dataref that the walker will walk> data structure.  If 
provided it will check at each L</node> if a L<secondary_ref|/B<secondary_ref> - a 
dataref that is used> matches at that level.  Each time the walker reaches a L</node> 
it will see if it can call a L<before_method|/B<before_method> - a method name that 
will perform some>.  After the node has been processed it will attempt to call an 
L<after_method|/B<after_method> - a method name that will perform some>.  For more 
details see the L</Recursive Parsing Flow>.  Extentions or Roles that use this method are 
expected to compose and pass the following data to this method.

=item B<Accepts:> $passed_ref and $conversion_ref

=over 

=item B<$passed_ref> this ref contains key value pairs as follows;

=over 

=item B<primary_ref> - a dataref that the walker will walk

=item B<secondary_ref> - a dataref that is used for comparision while walking

=item B<before_method> - a method name that will perform some action at the beginning 
of each node

=item B<after_method> - a method name that will perform some action at the end 
of each node

=item B<[attribute name]> - attribute names are accepted with temporary attribute settings.  
These settings are temporarily set for a single "_process_the_data" call and then the original 
attribute values are restored.  For this to work the the attribute must have the following 
prefixed methods get_$name, set_$name, clear_$name, and has_$name.

=back

=item B<$conversion_ref> This allows a public method to accept different key names for the 
various keys listed above and then convert them later to the generic terms used by this Class.

=back

=item B<Action:> The passed data is first scrubbed were the minimum acceptable list of passed 
arguments are: 'primary_ref' and either of 'before_method' or 'after_method'.  The list can also 
contain a 'secondary_ref' and a 'branch_ref' but they are not required.  Any errors will be 
'confess'ed using the passed names not the data walker names.  B<When naming the 
before_method and after_method for the role keep in mind possible namespace collisions with 
other role methods.>  After the data scrubbing the $passed_ref is sent to the 
L<recursive|/Recursive Parsing Flow> data walker.  The before_method and after_method are 
allowed to change the primary_ref and secondary_ref.  For more details see the 
L</Recursive Parsing Flow>.

=item B<An example>

	$passed_ref ={
		print_ref =>{ 
			First_key => 'first_value',
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


=item B<Returns:> the $passed_ref (only) with the key names restored to the 
L<original|/B<$conversion_ref> This allows a public> versions.

=back

=head3 _build_branch( $base_ref, @arg_list )

=over

=item B<Definition:> There are times when a Role will wish to reconstruct the branch 
that lead to the current position that the Data Walker is at.  This private method takes 
a data reference and recursivly appends the branch to the front of it using the information 
in the L<branch ref|/B<branch_ref> in the $passed_ref.>

=item B<Accepts:> a list of arguments starting with the seed data reference $base_ref 
to build from.  The remaining arguments are just the array elements of the 
L<branch ref|/B<branch_ref> in the $passed_ref.> and example call would be;

	$ref = $self->_build_branch( 
		$seed_ref, 
		@{ $passed_ref->{branch_ref}},
	);

=item B<Returns:> a data reference with the current path back to the start appended 
to the $seed_ref

=back

=head2 Public Methods

=head3 set_change_array_size( $bool )

=over

=item B<Definition:> This method is used to change the L</change_array_size> attribute 
after the instance is created.  This attribute is not used by this class!  
However, it is provided here so multiple Roles can share behavior rather than each setting this 
attribute differently.  The intent is for this attribute to indicate if the array size should be 
changed when modifying an array.  The intent is that the array will be reduced when prune 
is called and expanded when graft is called if the attribute is positive.  If the attribute is 
negative the array dimensions will remain the same after the prune and graft operations.

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
for just the run of that method call.

=head3 sort_HASH 

=over

=item B<Definition:> This attribute is set to L<sort|http://perldoc.perl.org/functions/sort.html> 
(or not) Hash Ref keys prior to walking the Hash Ref node.

=item B<Default> 0 (No sort)

=item B<Range> Boolean values and sort coderefs.
    
=back

=head3 sort_ARRAY

=over

=item B<Definition:> This attribute is set to L<sort|http://perldoc.perl.org/functions/sort.html> 
(or not) Array values prior to walking the Array Ref node.  B<Warning> this will permanantly sort 
the actual data in the passed ref permanently.  If a secondary ref also exists it will be sorted 
as well!

=item B<Default> 0 (No sort)

=item B<Range> Boolean values and sort coderefs.

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

=head2 First 

B<before_method> The class checks for an available 'before_method'.  Using the test; 

	exists $passed_ref->{before_method};

If the test passes then the next sequence is run.

	$method = $passed_ref->{before_method};
	$passed_ref = $self->$method( $passed_ref );

Then if the new $passed_ref contains the key $passed_ref->{bounce} or is undef the 
program deletes the key 'bounce' from the $passed_ref (as needed) and then returns 
$passed_ref directly back up the data tree.  I<Do not pass 'Go' do not collect $200.>  
Otherwise the $passed_ref is sent on to the node parser.  If the $passed_ref is modified 
by the 'before_method' then the node parser will parse the new ref and not the old one. 

=head2 Second

B<Determine node type and elements> The current node is examined to determine it's 
reference type. The relevant L<skip attribute|/skip_HASH_ref> is consulted and 
if this node should be skipped then the program goes directly to the L</Fourth> step.  If 
the node type is not skipped then a list is generated for multi-element nodes.  SCALARs 
are considered 'SCALAR' types and are handled as single element nodes.  Next, if the 
list L<should be sorted|/sort_HASH> then the list is sorted. Finally the node is tested for 
an empty set.  If the set is empty this is considered a 'base state' and the code also skips 
to the L</Fourth> step else the code sends the list to the L</Third> step.

=head2 Third

B<Iterate through each element> For each element a new L<$passed_ref|/B<$passed_ref> 
this ref contains key value pairs as follows;> is generated.  Based on the data branch below 
that element.  The secondary_ref is only constructed if it has a matching element at that 
node with the primary_ref.  Non matching portions of the secondary_ref are discarded.  Node 
matching for hashrefs is done by string compares of the key only.  Node matching for arrayrefs 
is done by testing if the secondary_ref has the same array position available as the primary_ref.  
I<No position content compare is done!>  The current element is then documented by pushing 
an element to an array_ref kept as the key B<branch_ref> in the $passed_ref.  This branch_ref 
can be thought of as the stack trace that documents the node elements directly between the 
current position and the top level of the parsed data_ref.  Past completed branches and future 
pending branches are not shown.  The array element pushed to the branch_ref is an array_ref 
that contains four positions which describe the current element position.  The values in each 
position are; 

	[
		ref_type, 
		hash key name or '' for ARRAYs,
		element sequence position (from 0),#For hashes this is only relevent if sort_HASH is called
		level of the node (from 1),#The zeroth level is the passed data ref
	]

The new $passed_ref is then passed to the recursive (private) subroutine.

	my $alternative_passed_ref = $self->_walk_the_data( $new_passed_ref );

When the values are returned from the recursion call the last branch_ref element is 
L<pop|http://perldoc.perl.org/functions/pop.html>ed off and the returned value(s) 
is(are) used to L<replace|/fixed_primary> the passed primary_ref and secondary_ref values in 
the current $passed_ref.  The program then returns to the L</Third> step for the next element.

=head2 Fourth

B<after_method> The class checks for an available 'after_method' using the test;

	exists $passed_ref->{after_method};

If the test passes then the following sequence is run.

	$method = $passed_ref->{after_method};
	$passed_ref = $self->$method( $passed_ref ); 

=head2 Fifth

B<Go up> The $passed_ref is passed back up to the next level.  (with changes)

=head1 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> with the '-ENV' option so setting the variable 
$ENV{Smart_Comments} will turn on smart comment reporting.  There are three levels 
of 'Smartness' called in this module '### #### #####'.  See the L<Smart::Comments> 
documentation for more information.

=back

=head1 SUPPORT

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item Support recursion through CodeRefs

=item Support recursion through Objects

=item Add a Data::Walk::Top Role to the package

=item Add a Data::Walk::Thin Role to the package

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

=head1 Dependancies

=over

=item L<version>

=item L<Carp>

=item L<Moose>

=item L<MooseX::StrictConstructor>

=item L<MooseX::Types::Moose>

=item L<Smart::Comments> -ENV option set

=back

=head1 SEE ALSO

=over

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dump

=item L<YAML> - Dump

=item L<Data::Walk::Print> - or other action object

=item L<Data::Walk::Prune>

=item L<Data::Walk::Graft>

=item L<Data::Walk::Clone>

=back

=cut

#################### main pod documentation end #####################