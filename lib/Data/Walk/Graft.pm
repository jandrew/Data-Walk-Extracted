package Data::Walk::Graft;

use Moose::Role;
requires 
	'_process_the_data',
	'_dispatch_method',
	'_build_branch';
use MooseX::Types::Moose qw(
        HashRef
        ArrayRef
        RegexpRef
        Bool
        Str
        Ref
        Int
        Item
    );######<------------------------------------------------------  ADD New types here
use version; our $VERSION = qv('0.007_001');
use Smart::Comments -ENV;
### Smart-Comments turned on for Data-Walk-Graft

###############  Package Variables  #####################################################

$| = 1;
my $graft_keys = {
    primary_ref		=> 'scion_ref',
    secondary_ref	=> 'tree_ref',
};

###############  Dispatch Tables  #######################################################

###############  Public Attributes  #####################################################

has 'graft_memory' =>(
    is			=> 'ro',
    isa			=> Bool,
    writer		=> 'set_graft_memory',
	reader		=> 'get_graft_memory',
	predicate	=> 'has_graft_memory',
	clearer		=> 'clear_graft_memory',
);

###############  Public Methods  ########################################################

sub graft_data{#Used to convert names
    ### <where> - Made it to graft_data
    ##### <where> - Passed input: @_
    my  $self = $_[0];
    my  $passed_ref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    $passed_ref->{before_method} = '_graft_before_method';
	$self->_clear_grafted_positions;
    ##### <where> - Start recursive parsing with: $passed_ref
    $passed_ref = $self->_process_the_data( $passed_ref, $graft_keys );
    ### <where> - End recursive parsing with: $passed_ref
    return $passed_ref->{tree_ref};
}

###############  Private Attributes  ####################################################

has '_grafted_positions' =>(
    is			=> 'ro',
    traits  	=> ['Array'],
    isa     	=> ArrayRef[HashRef],
    handles => {
        _remember_graft_item	=> 'push',
		number_of_scions		=> 'count',
    },
    clearer		=> '_clear_grafted_positions',
    predicate   => 'has_grafted_positions',
	reader		=> 'get_grafted_positions',
);

###############  Private Methods / Modifiers  ###########################################

sub _graft_before_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached before_method
    #### <where> - received input: $passed_ref
    my  $scion_ref  = $passed_ref->{primary_ref};
    my  $tree_ref   =
        ( exists $passed_ref->{secondary_ref} ) ?
            $passed_ref->{secondary_ref} : undef ;
    ### <where> - scion_ref: $scion_ref
    ### <where> - tree_ref : $tree_ref
    if( $self->_check_graft_state( $tree_ref, $scion_ref ) ){
        ### <where> - Found a difference - adding new element ...
		$passed_ref->{secondary_ref} = 
			( $self->can( 'deep_clone' ) ) ?
				$self->deep_clone( $scion_ref ) : $scion_ref ;
		if( $self->get_graft_memory ){
			### <where> - recording the most recent grafted scion ...
			my 	$rememberance_ref = ( $self->can( 'deep_clone' ) ) ?
					$self->deep_clone( $scion_ref ) : $scion_ref ;
			if( exists $passed_ref->{branch_ref} ){
				###  <where> - current branch ref is: $passed_ref->{branch_ref}
				$rememberance_ref = $self->_build_branch( 
					$rememberance_ref, 
					@{$passed_ref->{branch_ref}},
				);
			}
			###  <where> - rememberance ref: $rememberance_ref
			$self->_remember_graft_item( $rememberance_ref );
			#### <where> - graft memory: $self->get_grafted_positions
		}else{
			#### <where> - forget this graft - whats done is done ...
		}
        $passed_ref->{bounce} = 1;
    }else{
        ### <where> - no action required - continue on
    }
	### <where> - the current passed ref is: $passed_ref
    return $passed_ref;
}

sub _check_graft_state{
	my ( $self, $tree_ref, $scion_ref ) = @_;
	my	$answer = 0;
	### <where> - reached _check_graft_state ...
    if( !$tree_ref and $scion_ref and ($scion_ref ne 'IGNORE') ){
        ### <where> - no tree_ref here - adding scion_ref ...
		$answer = 1;
    }elsif( ref $scion_ref ne ref $tree_ref ){
        ### <where> - The tree_ref and scion_ref are not the same type ...
		### <where> - the scion_ref will replace the tree_ref...
		$answer = 1;
    }elsif( $scion_ref and
            !is_Ref( $scion_ref ) and 
            $scion_ref ne 'IGNORE' and
            $scion_ref ne $tree_ref){
        ### <where> - The next scion node doesn't match the tree branch - changing to the scion_ref...
		$answer = 1;
    }
	### <where> - the current answer is: $answer
	return $answer;
}

#################### Phinish with a Phlourish ###########################################

no Moose::Role;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin #######################################

__END__

=head1 NAME

Data::Walk::Graft - A way to say what should be added

=head1 SYNOPSIS
    
    #!perl
	use Modern::Perl;
	use Moose::Util qw( with_traits );
	use Data::Walk::Extracted v0.011;
	use Data::Walk::Graft v0.007;
	use Data::Walk::Print v0.007;

	my  $gardener = with_traits( 
			'Data::Walk::Extracted', 
			( 
				'Data::Walk::Graft', 
				'Data::Walk::Clone',
				'Data::Walk::Print',
			) 
		)->new(
			sort_HASH => 1,# For demonstration consistency
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
    
    #####################################################################################
    #     Output of SYNOPSIS
    # 01 {
    # 02 	Helping => {
    # 03 		KeyThree => 'Another Value',
    # 04 		KeyTwo => 'A New Value',
    # 05 		OtherKey => 'Otherthing',
    # 06 	},
    # 07 	MyArray => [
    # 08 		'ValueOne',
    # 09 		{
    # 10 			What => 'Chicken_Butt!',
    # 11 		},
    # 12 		'ValueThree',
    # 13 		,
    # 14 		'ValueFive',
    # 15 	],
    # 16 },
    #####################################################################################
    
=head1 DESCRIPTION

This L<Moose::Role> contains methods for adding a new branch ( or three ) to an 
existing data ref.  The primary method is L</graft_data> which uses 
L<Data::Walk::Extracted>.  Grafting is accomplished by sending a 
L<scion_ref|/ 'scion_ref' and use it to graft> that has additions that need to be 
made to a L<tree_ref|/to graft to a 'tree_ref'>.  

=head2 Caveat utilitor

=head3 Supported Node types

=over

=item B<ARRAY>

=item B<HASH>

=item B<SCALAR>

=back

=head3 Supported L<one shot|/Attributes> Attributes

=over

=item graft_memory

=back

=head3 Deep Cloning the graft

In general grafted data is safer if the grafted portion is deep cloned prior to 
grafting.  To facilitate this the graft_data method will call deep_clone at the 
point of graft if the method is available to the instance.  One easy way to do 
this is by adding the 
L<Data::Walk::Clone|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Clone.pm> 
Role when building the instance.  This will provide all of the full deep cloning 
and partial cloning availabe in that Role with no additional work.  If this module 
finds that deep_clone is not available then the data reference memory location 
pointer for the graft point of the 'scion_ref' will be passed directly.  The other 
possibility is to deep_clone the entire scion_ref prior to sending it to the 
'graft_data' method so that later if you change that same reference somewhere else 
in the program it won't populate through to the scion graft on the data tree.  
Adding a 'deep_clone' method on your own is another possiblity.  The call used is;

	$scion_ref = $self->deep_clone( $scion_ref );

=head2 USE

One way to join this role with 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm> 
is the method 'with_traits' from 
L<Moose::Util|https://metacpan.org/module/Moose::Util>.  Otherwise see 
L<Moose::Manual::Roles|https://metacpan.org/module/Moose::Manual::Roles>.

=head2 Methods

=head3 graft_data( %args )

=over

=item B<Definition:> This will take a 'scion_ref' and use it to graft to a 'tree_ref'.  
Where the 'scion_ref' matches the 'tree_ref' no changes are made.  When the 'scion_ref' 
has something different than that portion of the 'tree_ref' then that portion of the 
'scion_ref' replaces that portion of the 'tree_ref'.  The word 'IGNORE' can be 
used for positions in array nodes that are effectivly don't care states for the 
'scion_ref'.  For example if you wish to change the third element of an array node then 
placing 'IGNORE' in the first two positions will cause L</graft_data> to skip the analysis 
of those positions (This saves replacating deep references in an array position).  If a 
'scion_ref' adds a position past the end of an array then all the remaining positions 
in the 'tree_ref' will be undefined.

=item B<Accepts:> a hash ref with the keys 'scion_ref' and 'tree_ref'.  The data_refs 
can contain any L<supported|/Supported Node types> node types.  If no 'tree_ref' is 
passed then the 'scion_ref' is returned in it's entirety.  If an array position set to 'IGNORE' 
in the 'scion_ref' is never evaluated (for example a replacment is done higher in the 
data tree) then the grafted tree will contain 'IGNORE' in that element of the array not 
undef.  See L</TODO> for future support.

=item B<Returns:> The $tree_ref with any changes (possibly deep cloned)

=back

=head3 has_graft_memory

=over

=item B<Definition:> This will indicate if the attribute L</graft_memory> is set

=item B<Accepts:> nothing

=item B<Returns:> 1 or 0

=back

=head3 set_graft_memory

=over

=item B<Definition:> This will set the L</graft_memory> attribute.

=item B<Accepts:> 1 or 0

=item B<Returns:> nothing

=back

=head3 get_graft_memory

=over

=item B<Definition:> This will return the current value for the L</graft_memory> attribute.

=item B<Accepts:> nothing

=item B<Returns:> 1 or 0

=back

=head3 clear_graft_memory

=over

=item B<Definition:> This will un-set the L</graft_memory> attribute.

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head3 number_of_scions

=over

=item B<Definition:> This will return the number of scion points grafted in the most recent 
graft action if the L</graft_memory> attribute is on.

=item B<Accepts:> nothing

=item B<Returns:> a positive integer

=back

=head3 has_grafted_positions

=over

=item B<Definition:> This will indicate if any grafted positions were saved.

=item B<Accepts:> nothing

=item B<Returns:> 1 or 0

=back

=head3 get_grafted_positions

=over

=item B<Definition:> This will return any saved grafted positions.

=item B<Accepts:> nothing

=item B<Returns:> an ARRAY ref of grafted positions.  This will include 
one full data branch to the root for each position actually grafted.

=back

=head2 Attributes

Data passed to ->new when creating an instance.  For modification of these attributes 
see L</Methods>.  The ->new function will either accept fat comma lists or a complete 
hash ref that has the possible appenders as the top keys.  Additionally 
L<some attributes|/Supported one shot > that meet the criteria can be passed to 
L<graft_data|/graft_data( %args )> and will be adjusted for just that run of the method.

=head3 graft_memory

=over

=item B<Definition:> When running a 'graft_data' operation any branch of the scion_ref 
that does not terminate past the end of the tree ref or differ from the tree_ref 
will not be used.  This attribute turns on tracking of the actual grafts made and 
stores them for review after the method is complete.  This is a way to know if a graft 
was actually implemented.

=item B<Default> undefined

=item B<Range> 1 = remember the cuts | 0 = don't remember
    
=back

=head3 See Also

Attributes in 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 
affect the output.

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

=item Support grafting through CodeRef nodes

=item Support grafting through Objects / Instances nodes

=back

=head1 AUTHOR

=over

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

=item L<Data::Walk::Clone> - manufacturers reccommendation

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::ModeMerge>

=back

=cut

#################### main pod documentation end #############################################################