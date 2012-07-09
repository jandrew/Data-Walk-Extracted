package Data::Walk::Prune;

use Moose::Role;
requires 
	'_process_the_data', 
	'_dispatch_method', 
	'_build_branch', 
	'_extracted_ref_type';
use MooseX::Types::Moose qw(
        HashRef
        ArrayRef
        RegexpRef
        Bool
        Str
        Ref
        Int
        Item
    );######<-------------------------------------------------------  ADD New types here
use version; our $VERSION = qv('0.007_001');
use Smart::Comments -ENV;
### Smart-Comments turned on for Data-Walk-Prune

###############  Package Variables  #####################################################

$| = 1;
my $prune_keys = {
    primary_ref		=> 'slice_ref',
    secondary_ref	=> 'tree_ref',
};

###############  Dispatch Tables  #######################################################

my $prune_dispatch = {######<---------------------------------------  ADD New types here
    HASH	=> \&_remove_hash_key,
    ARRAY 	=> \&_clear_array_position,
};

my $remember_dispatch = {######<------------------------------------  ADD New types here
	HASH	=> \&_build_hash_cut,
    ARRAY	=> \&_build_array_cut,
};

my $prune_decision_dispatch = {######<------------------------------  ADD New types here
    HASH	=> \&_hash_cut_test,
    ARRAY	=> \&_array_cut_test,
	SCALAR	=> sub { return $_[2]; },#No cut signal for SCALARS
	END		=> sub { return $_[2]; },#No cut signal for END refs
};

###############  Public Attributes  #####################################################

has 'prune_memory'	=>(
    is			=> 'ro',
    isa     	=> Bool,
    writer  	=> 'set_prune_memory',
	reader		=> 'get_prune_memory',
	predicate	=> 'has_prune_memory',
	clearer		=> 'clear_prune_memory',
);

###############  Public Methods  ########################################################

sub prune_data{#Used to convert names
    ### <where> - Made it to prune_data
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    @$passed_ref{ 'before_method', 'after_method' } = 
        ( '_prune_before_method', '_prune_after_method' );
	$self->_clear_pruned_positions;
    ##### <where> - Start recursive parsing with: $passed_ref
    $passed_ref = $self->_process_the_data( $passed_ref, $prune_keys );
    ### <where> - End recursive parsing with: $passed_ref
    return $passed_ref->{tree_ref};
}

###############  Private Attributes  ####################################################

has '_prune_list' =>(
    is			=> 'ro',
    traits		=> ['Array'],
    isa			=> ArrayRef[ArrayRef[Item]],
    handles => {
        _add_prune_item		=> 'push',
        _next_prune_item	=> 'shift',
    },
    clearer		=> '_clear_prune_list',
    predicate	=> '_has_prune_list',
);

has '_pruned_positions' =>(
    is				=> 'ro',
    traits  		=> ['Array'],
    isa     		=> ArrayRef[HashRef],
    handles => {
        _remember_prune_item	=> 'push',
		number_of_cuts			=> 'count',
    },
    clearer		=> '_clear_pruned_positions',
    predicate	=> 'has_pruned_positions',
	reader		=> 'get_pruned_positions',
);


###############  Private Methods / Modifiers  ############################################


sub _prune_before_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached before_method
    #### <where> - received input: $passed_ref
    my  $slice_ref  = $passed_ref->{primary_ref};
    my  $tree_ref   =
        ( exists $passed_ref->{secondary_ref} ) ?
            $passed_ref->{secondary_ref} : undef ;
    ### <where> - slice_ref: $slice_ref
    ### <where> - tree_ref : $tree_ref
    if( !$tree_ref ){
        ### <where> - no matching tree_ref element so 'bounce' called ...
        $passed_ref->{bounce} = 1;
    }else{
		### <where> - determining if this is a prune location and then skip parsing the node ...
		$passed_ref = $self->_dispatch_method(
			$prune_decision_dispatch,
			$self->_extracted_ref_type( $slice_ref ),
			$slice_ref,
			$passed_ref,
		);
    }
	#### <where> - new passed ref; $passed_ref
    return $passed_ref;
}

sub _prune_after_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached after_method
    #### <where> - received input: $passed_ref
    my  $tree_ref   =
        ( exists $passed_ref->{secondary_ref} ) ?
            $passed_ref->{secondary_ref} : undef ;
    #~ my  $ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
    ### <where> - tree_ref   : $tree_ref
    ### <where> - Slice state: $self->_has_prune_list
    if( $tree_ref and $self->_has_prune_list ){
        while( my $item_ref = $self->_next_prune_item ){
			### <where> - item ref: $item_ref
			my  $tree_ref = $self->_prune_the_item( $item_ref, $tree_ref );
			#### <where> - tree ref: $tree_ref
			if(	$self->has_prune_memory and
				$self->get_prune_memory 	){
				### <where> - building the rememberance ref ...
				my $rememberance_ref = $self->_dispatch_method(
						$remember_dispatch,
						$item_ref->[0],
						$item_ref,
				);
				if( exists $passed_ref->{branch_ref} ){
					###  <where> - current branch ref is: $passed_ref->{branch_ref}
					$rememberance_ref = $self->_build_branch( 
						$rememberance_ref, 
						@{ $passed_ref->{branch_ref}},
					);
				}
				###  <where> - rememberance ref: $rememberance_ref
				$self->_remember_prune_item( $rememberance_ref );
				#### <where> - prune memory: $self->get_pruned_positions
			}
        }
        $passed_ref->{secondary_ref} = $tree_ref;
    }
    ### <where> - finished pruning at this node - clear the prune list
	#~ $wait = <>;
    $self->_clear_prune_list;
    return $passed_ref;
}

sub _prune_the_item{
    my ( $self, $item_ref, $tree_ref ) = @_;
    ### <where> - Made it to _prune_the_item
    ### <where> - item ref  : $item_ref
    ##### <where> - tree ref  : $tree_ref
	$tree_ref = $self->_dispatch_method( 
		$prune_dispatch, 
		$item_ref->[0],
		$item_ref,
		$tree_ref,
	);
    ### <where> - cut completed succesfully
    return $tree_ref;
}

sub _remove_hash_key{
    my ( $self, $item_ref, $tree_ref ) = @_;
    ### <where> - Made it to _remove_hash_key
    ##### <where> - self      : $self
    ### <where> - item ref  : $item_ref
    ##### <where> - tree ref  : $tree_ref
    delete $tree_ref->{$item_ref->[1]};
    ##### <where> - tree ref  : $tree_ref
    return $tree_ref;
}

sub _clear_array_position{
    my ( $self, $item_ref, $tree_ref ) = @_;
    ### <where> - Made it to _clear_array_position
    ### <where> - item ref  : $item_ref
    ##### <where> - tree ref  : $tree_ref
    if( $self->change_array_size ){
        ### <where> - splicing out position: $item_ref->[2]
        splice( @$tree_ref, $item_ref->[2]);
    }else{
        ### <where> - Setting undef at position: $item_ref->[2]
        $tree_ref->[$item_ref->[2]] = undef;
    }
    ##### <where> - tree ref  : $tree_ref
    return $tree_ref;
}

sub _build_hash_cut{
    my ( $self, $item_ref ) = @_;
    ### <where> - Made it to _build_hash_cut
    ### <where> - item ref  : $item_ref
	return { $item_ref->[1] => {} };
}

sub _build_array_cut{
    my ( $self, $item_ref ) = @_;
    ### <where> - Made it to _build_array_cut
    ### <where> - item ref  : $item_ref
	my  $array_ref;
	$array_ref->[$item_ref->[2]] = [];
    ### <where> - item ref  : $item_ref
	return $item_ref;
}

sub _hash_cut_test{
    my ( $self, $slice_ref, $passed_ref ) = @_;
    ### <where> - Made it to _hash_cut_signal ...
    ### <where> - slice ref: $slice_ref
	if( scalar( keys %$slice_ref ) == 0 ){
        ### <where> - Marking hash key for removal: $passed_ref->{branch_ref}->[-1]->[1]
        $self->_add_prune_item( $passed_ref->{branch_ref}->[-1] );
		$passed_ref->{bounce} = 1;
	}
    ##### <where> - passed ref: $passed_ref
	return $passed_ref;
}

sub _array_cut_test{
    my ( $self, $slice_ref, $passed_ref ) = @_;
    ### <where> - Made it to _array_cut_signal ...
    ### <where> - slice ref: $slice_ref
	if( scalar( @$slice_ref ) == 0 ){
        ### <where> - Marking array position for removal: $passed_ref->{branch_ref}->[-1]->[2]
        $self->_add_prune_item( $passed_ref->{branch_ref}->[-1] );
		$passed_ref->{bounce} = 1;
	}
    ##### <where> - passed ref: $passed_ref
	return $passed_ref;
}
	
	

#################### Phinish with a Phlourish ############################################

no Moose::Role;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin ########################################

__END__

=head1 NAME

Data::Walk::Prune - A way to say what should be removed

=head1 SYNOPSIS
    
	#! C:/Perl/bin/perl
	use Modern::Perl;
	use Moose::Util qw( with_traits );
	use Data::Walk::Extracted v0.011;
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
    
    ######################################################################################
    #     Output of SYNOPSIS
    # 01 {
    # 02 	Helping => [
    # 03 		'Somelevel',
    # 04 		{
    # 05 			MyKey => {
    # 06 				MiddleKey => {
    # 07 					LowerKey2 => {
    # 08 						BottomKey1 => 'bvalue1',
    # 09 						BottomKey2 => 'bvalue2',
    # 10 					},
    # 12 				},
    # 13 			},
    # 14 		},
    # 15 	],
    # 16 },
    ######################################################################################
    
=head1 DESCRIPTION

This L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> contains methods for 
implementing the method L</prune_data> using 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm>.  
By sending a L<slice_ref|/This will take a 'slice_ref'> that terminates in an empty 
hash_ref (no keys) or an empty array_ref (no positions) then the 
L<tree_ref|/use it to prune a 'tree_ref'.> will be pruned at that spot.  'prune_data' 
returns a deep cloned data ref that matches the 'tree_ref' with the 'slice_ref' bits 
taken off.

=head2 Caveat utilitor

Because this uses Data::Walk::Extracted the $result is a deep cloned ref with no data 
pointers matching the original $tree_ref.

=head3 Supported Node types

=over

=item B<ARRAY>

=item B<HASH>

=item B<SCALAR>

=back

=head3 Supported one shot L</Attributes>

=over

=item prune_memory

=back

=head2 USE

This is a L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> and can be 
used as such.  One way to use this role with  
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm>, 
is the method 'with_traits' from 
L<Moose::Util|https://metacpan.org/module/Moose::Util>.  Otherwise see 
L<Moose::Manual::Roles|https://metacpan.org/module/Moose::Manual::Roles>.

=head2 Methods

=head3 prune_data( %args )

=over

=item B<Definition:> This will take a 'slice_ref' and use it to prune a 'tree_ref'.  
The code looks for empty hash refs or array refs to show where to cut.  The cut is 
signaled by the location an empty hash ref or an empty node ref.  If the terminator 
is the value in a key => value pair of a hash node then the key is also deleted.  If 
the terminator is in a position in an array then the array position is 
L<deleted/cleared|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#change_array_size>.  
If the slice ref terminator is not a match for a node on the tree ref then no cutting 
occurs!

=item B<Accepts:> a hash ref with the keys 'slice_ref' and 'tree_ref' (both required).  
The slice ref can contain more than one terminator location in the data reference.

=item B<Returns:> The $tree_ref with any changes (Deep cloned)

=back

=head3 set_prune_memory( $Bool ) 

=over

=item B<Definition:> This will change the setting of the L</prune_memory> 
attribute.

=item B<Accepts:> 1 = remember | 0 = no memory

=item B<Returns:> nothing

=back

=head3 get_prune_memory

=over

=item B<Definition:> This will return the current setting of the L</prune_memory> 
attribute.

=item B<Accepts:> nothing

=item B<Returns:> A $Bool value for the current state

=back

=head3 has_prune_memory

=over

=item B<Definition:> This will indicate if the L</prune_memory> attribute is set

=item B<Accepts:> nothing

=item B<Returns:> A $Bool value 1 = defined, 0 = not defined

=back

=head3 clear_prune_memory

=over

=item B<Definition:> This will clear the L</prune_memory> attribute value 
(Not the actual prune memory)

=item B<Accepts:> nothing

=item B<Returns:> A $Bool value 1 = defined, 0 = not defined

=back

=head3 has_pruned_positions

=over

=item B<Definition:> This answers if any pruned positions were stored

=item B<Accepts:> nothing

=item B<Returns:> A $Bool value 1 = pruned cuts are stored, 0 = no stored cuts

=back

=head3 get_pruned_positions

=over

=item B<Definition:> This returns an array ref of stored pruning cuts

=item B<Accepts:> nothing

=item B<Returns:> an ArrayRef - even if the cuts were defined in one data ref 
this will return one data ref per cut.  Each ref will go to the root of the 
original data ref.

=back

=head3 number_of_cuts

=over

=item B<Definition:> This returns the number of cuts actually made

=item B<Accepts:> nothing

=item B<Returns:> an integer

=back

=head2 Attributes

=head3 prune_memory

=over

=item B<Definition:> When running a prune operation any branch called on the pruner 
that does not exist in the tree will not be used.  This attribute turns on tracking 
of the actual cuts made and stores them for review after the method is complete.  
This is a way to know if the cut was actually implemented.

=item B<Default> undefined

=item B<Range> 1 = remember the cuts | 0 = don't remember
    
=back

L<Attributes in Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 
 - also affect the output.

=head2 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> with the '-ENV' option so setting the variable 
$ENV{Smart_Comments} will turn on smart comment reporting.  There are three levels 
of 'Smartness' called in this module '### #### #####'.  See the L<Smart::Comments> 
documentation for more information.

=back

=head1 SUPPORT

=over

=item L<github Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item Support pruning through CodeRef nodes

=item Support pruning through Objects / Instances nodes

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

=item L<Data::Walk::Extracted>

=item L<version>

=item L<Moose::Role>

=item L<MooseX::Types::Moose>

=item L<Smart::Comments> - With the -ENV variable set

=back

=head1 SEE ALSO

=over

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::ModeMerge>

=back

=cut

#################### main pod documentation end ##########################################