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
use version; our $VERSION = qv('0.009_003');
use Carp qw( cluck );
BEGIN{
	if( $ENV{ Smart_Comments } ){
		use Smart::Comments -ENV;
		### Smart-Comments turned on for Data-Walk-Graft
	}
}

###############  Package Variables  #####################################################

$| = 1;
my $graft_keys = {
    primary_ref		=> 'scion_ref',
    secondary_ref	=> 'tree_ref',
};
my 	$wait;

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
	if( $passed_ref->{scion_ref} ){
		$passed_ref->{before_method} = '_graft_before_method';
		$self->_clear_grafted_positions;
		##### <where> - Start recursive parsing with: $passed_ref
		$passed_ref = $self->_process_the_data( $passed_ref, $graft_keys );
	}else{
		cluck "No scion was provided to graft";
	}
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
    ### <where> - reached _graft_before_method
    #### <where> - received input: $passed_ref
    my  $scion_ref  = $passed_ref->{primary_ref};
    my  $tree_ref   =
        ( exists $passed_ref->{secondary_ref} ) ?
            $passed_ref->{secondary_ref} : undef ;
    ### <where> - scion_ref: $scion_ref
    ### <where> - tree_ref : $tree_ref
    if( $self->_check_graft_state( $tree_ref, $scion_ref ) ){
        ### <where> - Found a difference - adding new element ...
		my $clone_value = ( $self->can( 'deep_clone' ) ) ?
				$self->deep_clone( $scion_ref ) : $scion_ref ;
		### <where> - clone value: $clone_value
		$passed_ref->{secondary_ref} = $clone_value;
		if( $self->has_graft_memory ){
			### <where> - recording the most recent grafted scion ...
			if( exists $passed_ref->{branch_ref} ){
				###  <where> - current branch ref is: $passed_ref->{branch_ref}
				$clone_value = $self->_build_branch( 
					$clone_value, 
					@{$passed_ref->{branch_ref}},
				);
			}
			###  <where> - rememberance ref: $clone_value
			$self->_remember_graft_item( $clone_value );
			#### <where> - graft memory: $self->get_grafted_positions
		}else{
			#### <where> - forget this graft - whats done is done ...
		}
		$wait = <> if $ENV{ special_variable };
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
	### <where> - tree_ref: $tree_ref
	### <where> - scion_ref: $scion_ref
    if( !$tree_ref and $scion_ref and ($scion_ref ne 'IGNORE') ){
        ### <where> - no tree_ref here - adding scion_ref ...
		$answer = 1;
    }elsif(
		is_Ref( $scion_ref ) and
		ref $scion_ref ne ref $tree_ref ){
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
	use lib '../lib', 'lib';
	use Data::Walk::Extracted v0.015;
	use Data::Walk::Graft v0.009;
	use Data::Walk::Print v0.009;

	my  $gardener = with_traits( 
			'Data::Walk::Extracted', 
			( 
				'Data::Walk::Graft', 
				'Data::Walk::Clone',
				'Data::Walk::Print',
			) 
		)->new(
			sort_HASH => 1,# For demonstration consistency
			#Until Data::Walk::Extracted and ::Graft support these types
			#(watch Data-Walk-Extracted on github)
			dont_clone_node_types =>[ 
				'OBJECT',
				'CODEREF',
			],
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
	# 17 Now a list of -3- grafted positions
	# 18 [
	# 19 	{
	# 20 		Helping => {
	# 21 			OtherKey => 'Otherthing',
	# 22 		},
	# 23 	},
	# 24 	{
	# 25 		MyArray => [
	# 26 			,
	# 27 			{
	# 28 				What => 'Chicken_Butt!',
	# 29 			},
	# 30 		],
	# 31 	},
	# 32 	{
	# 33 		MyArray => [
	# 34 			,
	# 35 			,
	# 36 			,
	# 37 			,
	# 38 			'ValueFive',
	# 39 		],
	# 40 	},
	# 41 ],
	#####################################################################################
    
=head1 DESCRIPTION

This L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> contains methods for 
adding a new branch ( or three ) to an existing data ref.  The primary method is 
L</graft_data> which uses L<Data::Walk::Extracted>.  Grafting is accomplished by sending a 
L<scion_ref|/ 'scion_ref' and use it to graft> that has additions that need to be 
made to a L<tree_ref|/to graft to a 'tree_ref'>.

=head2 Caveat utilitor

=head3 Supported Node types

=over

=item B<ARRAY>

=item B<HASH>

=item B<SCALAR>

=back

=head3 Other node support

Support for Objects is partially implemented and as a consequence _process_the_data won't 
immediatly die when asked to parse an object.  It will still die but on a dispatch table 
call that indicates where there is missing object support not at the top of the node.

=head3 Supported one shot L</Attributes>

=over

=item graft_memory

=back

=head3 Deep cloning the graft

In general grafted data refs are subject to external modification by changing the data 
in that ref in another location of the code.  This module assumes that you don't want 
to do that!  As a consequence it checks to see if a 'deep_clone' method has been provided to 
the class that consumes this role.  If so it calls that method on the data ref to be 
grafted.  One possiblity is to add the Role L<Data::Walk::Clone> to your object so that 
a deep_clone method is automatically available (all compatability testing complete).  
If you choose to add your own deep_clone method it will be called like this;

	my $clone_value = ( $self->can( 'deep_clone' ) ) ?
				$self->deep_clone( $scion_ref ) : $scion_ref ;
	
Where $self is the active object instance.

=head3 Grafting unsupported node types

If you want to add data from another ref to a current ref and the current ref only 
contains supported node types but the grafted portion does not there a big caveat.  
If you use L<Data::Walk::Clone> then you will be restricted by the node 
capability of that role.  The role does contain attributes that will allow for cloning of 
everything but the unsupported areas.

=head3 L</COPYRIGHT>

is down lower.

=head2 USE

This is a L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> and can be 
used as such.  One way to use this role with L<Data::Walk::Extracted>, is the method 
'with_traits' from L<Moose::Util|https://metacpan.org/module/Moose::Util#EXPORTED-FUNCTIONS>.  
Otherwise see L<Moose::Manual::Roles|https://metacpan.org/module/Moose::Manual::Roles>.

=head2 Methods

=head3 graft_data( %args )

=over

=item B<Definition:> This is a method to remove targeted parts of a data reference.

=item B<Accepts:> a hash ref with the keys 'scion_ref' and 'tree_ref'.  The scion 
ref can contain more than one place that will be grafted to the tree data.

=over

=item B<tree_ref> This is the primary data ref that will be manipulated and returned 
changed.  If an empty 'tree_ref' is passed then the 'scion_ref' is returned in it's 
entirety.

=item B<scion_ref> This is a data ref that will be used to graft to the 'tree_ref'.  
During data walking when a difference is found graft_data will attempt to 
clone that portion of the 'scion_ref' and then the result will be grafted to the 
'tree_ref' at that point.  If L</graft_memory> is on then a full recording of the 
graft with a map to the data root will be saved in the object.  The word 'IGNORE' can 
be used in either an array position or the value for a key in a hash ref.  This 
tells the program to ignore differences (in depth) past that point.  For example 
if you wish to change the third element of an array node then placing 'IGNORE' in 
the first two positions will cause 'graft_data' to skip the analysis of those 
positions.  This saves replicating deep references in the scion_ref so it will not 
prune the unreplicated data.  If an array position in the scion_ref is set to 
'IGNORE' in the 'scion_ref' but a graft is made below the node with IGNORE then 
the grafted tree will contain 'IGNORE' in that element of the array (not undef).  
Any root positions that exist in the tree_ref that do not exist in the scion_ref 
will be ignored.  If an empty 'scion_ref' is sent then the code will L<cluck|Carp> 
and then return the 'tree_ref'. 

=item B<[attribute name]> - attribute names are accepted with temporary attribute settings.  
These settings are temporarily set for a single "graft_data" call and then the original 
attribute values are restored.  For this to work the the attribute must meet the 
L<necessary criteria|/get_$attribute, set_$attribute>.

=item B<Example>

	$grafted_tree_ref = $self->graft_data(
		tree_ref => $tree_data,
		scion_ref => $addition_data,
		graft_memory => 0,
	);

=back

=item B<Accepts:> a hash ref with the keys 'scion_ref' and 'tree_ref'.  The data_refs 
can contain any L<supported|/Supported Node types> node types.  This method will also accept any 'one shot' attributes 
available to the class when the instance was built. (by attribute name not accessor)

=item B<Returns:> The $tree_ref with any changes (possibly deep cloned)

=back

=head3 has_graft_memory

=over

=item B<Definition:> This will indicate if the attribute L</graft_memory> is set

=item B<Accepts:> nothing

=item B<Returns:> 1 or 0

=back

=head3 set_graft_memory( $Bool )

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

Data passed to ->new when creating an instance using a class.  For modification of 
these attributes see L</Methods>.  The ->new function will either accept fat comma 
lists or a complete hash ref that has the possible appenders as the top keys.  
Additionally L<some attributes|/Supported one shot > that have all the following 
methods; get_$attribute, set_$attribute, has_$attribute, and clear_$attribute,
can be passed to L<graft_data|/graft_data( %args )> and will be adjusted for 
just the run of that method call.  These are called 'one shot' attributes.  These 
methods nest so if an attribute is set in the 'graft_data' method call then when 
L<deep_clone|/Deep cloning the graft> is called internal to 'graft_data' the attribute 
is still in force for the clone action but will terminate after the 'graft_data' method 
finishes and any other method called on the object will not be handled by that temporary
setting.

=head3 graft_memory

=over

=item B<Definition:> When running a 'graft_data' operation any branch of the scion_ref 
that does not terminate past the end of the tree ref or differ from the tree_ref 
will not be used.  This attribute turns on tracking of the actual grafts made and 
stores them for review after the method is complete.  This is a way to know if a graft 
was actually implemented.  The potentially awkward wording of the memory toggle accessors 
above is done to make this a possible 'one shot' attribute.

=item B<Default> undefined = don't remember the grafts

=item B<Range> 1 = remember the grafts | 0 = don't remember
    
=back

Attributes in 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 
affect the output.

=head2 GLOBAL VARIABLES

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

=item L<github Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item * Support grafting through CodeRef nodes

=item * Support grafting through Objects / Instances nodes

=item * A possible depth check to ensure the scion is deeper than the tree_ref

Implemented with an attribute that turns the feature on and off.  The goal 
would be to eliminate unintentional swapping of small branches for large branches.  
This feature has some overhead downside and may not be usefull so I'm not sure 
if it makes sence yet.

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

=item L<Data::Walk::Extracted>

=item L<version>

=item L<Moose::Role>

=item L<MooseX::Types::Moose>

=item L<Carp>

=back

=head1 SEE ALSO

=over

=item L<Smart::Comments> - is used if the -ENV option is set

=item L<Data::Walk::Clone> - manufacturers recommendation

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::ModeMerge>

=back

=cut

#################### main pod documentation end #############################################################