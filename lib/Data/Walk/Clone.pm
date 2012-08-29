package Data::Walk::Clone;

use Moose::Role;
requires 
	'_process_the_data', 
	'_dispatch_method', 
	'_get_had_secondary';
use MooseX::Types::Moose qw(
        HashRef
        ArrayRef
        RegexpRef
		CodeRef
        Bool
        Str
        Ref
        Int
        Item
		Num
    );######<--------------------------------------------------------  ADD New types here
use version; our $VERSION = qv('0.005_005');
BEGIN{
	if( $ENV{ Smart_Comments } ){
		use Smart::Comments -ENV;
		### Smart-Comments turned on for Data-Walk-Clone
	}
}

###############  Package Variables  #####################################################

$| = 1;
my $clone_keys = {
    primary_ref		=> 'donor_ref',
};
my ( $wait );

###############  Dispatch Tables  #######################################################

my 	$skip_clone_test_dispatch ={######<------------------------------  ADD New types here
		ARRAY	=> \&_array_skip_clone_test,
		HASH	=> \&_general_skip_clone_test,
		OBJECT	=> \&_general_skip_clone_test,
		name 	=> 'skip_clone_test_dispatch',#Meta data
	};

my 	$seed_clone_dispatch ={
		ARRAY => sub{
			unless( exists $_[1]->{secondary_ref} ){
				$_[1]->{secondary_ref} = [];
			}
			return $_[1];
		},
		HASH => sub{
			unless( exists $_[1]->{secondary_ref} ){
				$_[1]->{secondary_ref} = {};
			}
			return $_[1];
		},
		SCALAR => sub{ 
			$_[1]->{secondary_ref} = $_[1]->{primary_ref};
			return $_[1];
		},
		END => sub{ 
			$_[1]->{secondary_ref} = undef;
			return $_[1];
		},
		name => 'seed_clone_dispatch',#Meta data
	};

###############  Public Attributes  #####################################################

has 'clone_level' =>(
	is			=> 'ro',
	isa			=> Int,
	predicate	=> 'has_clone_level',
	reader		=> 'get_clone_level',
	writer		=> 'set_clone_level',
	clearer		=> 'clear_clone_level',
);

has 'dont_clone_node_types' =>(
	is		=> 'ro',
	isa		=> ArrayRef,
	traits	=> ['Array'],
	reader	=> 'get_dont_clone_node_types',
	writer	=> 'set_dont_clone_node_types',
	default	=> sub{ [] },
    handles => {
        add_dont_clone_node_type	=> 'push',
		has_dont_clone_node_types	=> 'count',
		clear_dont_clone_node_types	=> 'clear',
    },
);

has 'skip_clone_tests' =>(
	is		=> 'ro',
	isa		=> ArrayRef[ArrayRef],
	traits	=> ['Array'],
	reader	=> 'get_skip_clone_tests',
	writer	=> 'set_skip_clone_tests',
	default	=> sub{ [] },
    handles => {
        add_skip_clone_test		=> 'push',
		has_skip_clone_tests	=> 'count',
		clear_skip_clone_tests	=> 'clear',
    },
);

has 'should_clone' =>(
	is			=> 'ro',
	isa			=> Bool,
	writer		=> 'set_should_clone',
	reader		=> 'get_should_clone',
	predicate	=> 'has_should_clone',
	default		=> 1,
);
	

###############  Public Methods  ########################################################

sub deep_clone{#Used to convert names for Data::Walk:Extracted
    ### <where> - Made it to deep_clone
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = 
		( @_ == 2 ) ?
			( 	( is_HashRef( $_[1] ) and exists $_[1]->{donor_ref} ) ? 
					$_[1] : { donor_ref =>  $_[1] } ) :
			{ @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
	@$passed_ref{ 
		'before_method', 'after_method',# 'fixed_primary',
	} = ( 
		'_clone_before_method',	'_clone_after_method',#	1,
	);
	##### <where> - Start recursive parsing with  : $passed_ref
	$passed_ref = $self->_process_the_data( $passed_ref, $clone_keys );
	### <where> - End recursive parsing with    : $passed_ref
	return $passed_ref->{secondary_ref};
}

sub clear_should_clone{
	### <where> - turn cloning back on at clear_should_clone ...
    my ( $self, ) = @_;
	$self->set_should_clone( 1 );
	return 1;
}

###############  Private Attributes  ####################################################

has '_clone_level_dispatch' =>(
	is			=> 'ro',
	isa		=> HashRef[CodeRef],
	init_arg	=> {
		predicate 	=> \&has_clone_level,
		clearer		=> \&clear_clone_level,
		writer		=> \&set_clone_level,
	},
	reader	=> '_get_clone_level_dispatch',
);

###############  Private Methods / Modifiers  ###########################################

sub _clone_before_method{
    my ( $self, $passed_ref ) = @_;
    my  $donor_ref  = $passed_ref->{primary_ref};
    ### <where> - reached _clone_before_method
    #### <where> - received input: $passed_ref
    ### <where> - doner_ref: $donor_ref
	##### <where> - self: $self
	if( exists $passed_ref->{branch_ref} and
		@{$passed_ref->{branch_ref}}			){
		### <where> - testing for a bounce condition ...
		if(  	$self->_went_too_deep( $passed_ref ) or
				$self->_dont_clone_node( $passed_ref ) or
				$self->_dont_clone_here( $passed_ref )		){
			### <where> - attaching the uncloned portion to the secondary_ref and then bouncing ...
			$passed_ref->{secondary_ref} =  $passed_ref->{primary_ref};
			$passed_ref->{bounce} = 1;
		}
		#### <where> - passed ref is: $passed_ref
	}else{
		### <where> perform a one time test for should_clone ...
		if( !$self->get_should_clone ){
			### <where> - bouncing now ...
			$passed_ref->{bounce} = 1;
			$passed_ref->{secondary_ref} =  $passed_ref->{primary_ref};
		}else{
			### <where> - turn on one element of cloning ...
			$self->_get_had_secondary( 1 );
		}
	}
    return $passed_ref;
}

sub _clone_after_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _clone_after_method
    #### <where> - received input: $passed_ref
	### <where> - current item: $passed_ref->{branch_ref}->[-1]
	### <where> - should clone?: $self->get_should_clone
	if( $self->get_should_clone ){
		my 	$next_ref = $self->_extracted_ref_type( 
				$passed_ref->{primary_ref} 
			);
		### <where> - seeding the clone as needed for: $next_ref
		$passed_ref = $self->_dispatch_method(
			$seed_clone_dispatch,
			$next_ref,
			$passed_ref,
		);
	}
    #### <where> - the new passed_ref is: $passed_ref
    return $passed_ref;
}

sub _went_too_deep{
    my ( $self, $passed_ref ) = @_;
	my  $answer = 0; #keep going - default
    ### <where> - reached _went_too_deep ...
	### <where> - current item: $passed_ref->{branch_ref}->[-1]
    #### <where> - received input: $passed_ref
	if( $self->has_clone_level and
		$self->get_clone_level == $passed_ref->{branch_ref}->[-1]->[3] ){
		### <where> - NONE SHALL PASS! ...
		$answer = 1;
	}
	### <where> - answer: $answer
	return $answer;
}

sub _dont_clone_node{
    my ( $self, $passed_ref ) = @_;
	my ( $answer, $current_branch ) = (0, $passed_ref->{branch_ref}->[-1]);
    ### <where> - reached _dont_clone_node ...
	### <where> - current item: $current_branch
    #### <where> - received input: $passed_ref
	if( $self->has_dont_clone_node_types ){
		### <where> - found node skip list: $self->get_dont_clone_node_types
		my $ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
		for my $test ( @{$self->get_dont_clone_node_types} ){
			### <where> - running test: $test
			if( $test eq $ref_type ){
				### <where> - Never on a sunday! ...
				$answer = 1;
				last;
			}
		}
	}
	### <where> - answer: $answer
	return $answer;
}

sub _dont_clone_here{
    my ( $self, $passed_ref ) = @_;
	my ( $answer, $current_branch ) = (0, $passed_ref->{branch_ref}->[-1]);
    ### <where> - reached _dont_clone_here ...
	### <where> - current item: $current_branch
    #### <where> - received input: $passed_ref
	if( $self->has_skip_clone_tests ){
		### <where> - found skip tests: $self->get_skip_clone_tests
		for my $test ( @{$self->get_skip_clone_tests} ){
			### <where> - running test: $test
			if( $self->_dispatch_method( 
					$skip_clone_test_dispatch,
					$test->[0], 
					$test,
					$current_branch,
				)										){
				### <where> - NONE SHALL PASS! ...
				$answer = 1;
				last;
			}
		}
	}
	### <where> - answer: $answer
	return $answer;
}

sub _array_skip_clone_test{
    my ( $self, $test_ref, $branch_ref ) = @_;
	my ( $answer, $match_level ) = ( 0, 0 );
    ### <where> - reached _array_skip_clone_test ...
	### <where> - test_ref: $test_ref
	### <where> - branch_ref: $branch_ref
	if( $branch_ref ){
		$match_level++ if
			(	$test_ref->[0] eq $branch_ref->[0] );
		$match_level++ if
			(	$test_ref->[2] =~ /^(any|all)$/i or
				$test_ref->[2] == $branch_ref->[2]);
		$match_level++ if
			(	$test_ref->[3] =~ /^(any|all)$/i or
				$test_ref->[3] == $branch_ref->[3] );
		### <where> - match level: $match_level
	}
	$answer = ( $match_level == 3 ) ? 1 : 0 ;
	### <where> - answer: $answer
	return $answer;
}

sub _general_skip_clone_test{
    my ( $self, $test_ref, $branch_ref ) = @_;
	my ( $answer, $match_level ) = ( 0, 0 );
    ### <where> - reached _general_skip_clone_test ...
	### <where> - test_ref: $test_ref
	### <where> - branch_ref: $branch_ref
	$wait = <> if $ENV{ special_variable };
	if( $branch_ref ){
		my $item = $branch_ref->[1];
		### <where> - item: $item
		$match_level++ if
			(	$test_ref->[0] eq $branch_ref->[0] );
		### <where> - match level after type match: $match_level
		$match_level++ if
			( 
				( 
					$test_ref->[1] =~ /^(any|all)$/i	
				) or
				( 
					$item and
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
	}
	$answer = ( $match_level == 4 ) ? 1 : 0 ;
	### <where> - answer: $answer
	return $answer;
}
	

#################### Phinish with a Phlourish ###########################################

no Moose::Role;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin #######################################

__END__

=head1 NAME

Data::Walk::Clone - deep data cloning with boundaries

=head1 SYNOPSIS
    
	#!perl
	use Modern::Perl;
	use Moose::Util qw( with_traits );
	use Data::Walk::Extracted v0.015;
	use Data::Walk::Clone v0.005;

	my  $dr_nisar_ahmad_wani = with_traits( 
			'Data::Walk::Extracted', 
			( 'Data::Walk::Clone',  ) 
		)->new( 
			skip_clone_tests =>[  [ 'HASH', 'LowerKey2', 'ALL',   'ALL' ] ],
		);
	my  $donor_ref = {
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
	my	$injaz_ref = $dr_nisar_ahmad_wani->deep_clone(
			donor_ref => $donor_ref,
		);
	if(
		$injaz_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2} eq
		$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2}		){
		print "The data is not cloned at the skip point\n";
	}
		
	if( 
		$injaz_ref->{Helping}->[1]->{MyKey}->{MiddleKey} ne
		$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey}		){
		print "The data is cloned above the skip point\n";
	}
    
    #####################################################################################
    #     Output of SYNOPSIS
    # 01 The data is not cloned at the skip point
    # 02 The data is cloned above the skip point
    #####################################################################################
    
=head1 DESCRIPTION

This L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> contains 
methods for implementing the method L<deep_clone|/deep_clone( %args )> using 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm>.  
This method is used to deep clone (clone many/all) levels of a data ref.  Deep cloning 
is accomplished by sending a 'donor_ref' that has data that you want copied into a 
different memory location.  In general Data::Walk::Extracted already deep clones any 
output as part of its data walking so the primary value of this role is to define 
deep cloning boundaries. It may be that some portion of the data should maintain common 
memory location pointers to the original memory locations and so two ways of defining 
where to stop deep cloning are provided.  First a L<level callout|/clone_level> where 
deep cloning can stop at a common level.  Second a L<matching tool|/skip_clone_tests> 
where key or node type matching can be done across multiple levels or only at targeted 
levels.

=head2 Caveat utilitor

=head3 Supported Node types

=over

=item B<ARRAY>

=item B<HASH>

=item B<SCALAR>

=back

=head3 Supported one shot L</Attributes>

=over

=item clone_level

=item skip_clone_tests

=item should_clone

=back

=head2 USE

This is a L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> and can be 
used as such.  One way to use this role with L<Data::Walk::Extracted>, is the method 
'with_traits' from L<Moose::Util|https://metacpan.org/module/Moose::Util#EXPORTED-FUNCTIONS>.  
Otherwise see L<Moose::Manual::Roles|https://metacpan.org/module/Moose::Manual::Roles>.

=head2 Methods

=head3 deep_clone( $arg_ref|%args )

=over

=item B<Definition:> This takes a 'donor_ref' and deep clones it.

=item B<Accepts:> either a single data reference or named arguments 
in a fat comma list or hashref

=over

=item B<named variable option> - if data comes in a fat comma list or as a hash ref 
and the keys include a 'donor_ref' key then the list is processed as such.

=over

=item B<donor_ref> - this is the data reference that should be deep cloned - required

=item B<[attribute name]> - attribute names are accepted with temporary attribute settings.  
These settings are temporarily set for a single "deep_clone" call and then the original 
attribute values are restored.  For this to work the the attribute must meet the 
L<necessary criteria|/get_$attribute, set_$attribute>.

=back

=item B<single variable option> - if only one data_ref is sent and it fails the test 
for "exists $data_ref->{donor_ref}" then the program will attempt to name it as 
donor_ref => $data_ref and then process the data as a fat comma list.

=back

=item B<Returns:> The deep cloned data reference

=back

=head3 has_clone_level

=over

=item B<Definition:> This will indicate if the attribute L<clone_level|/clone_level> is set

=item B<Accepts:> nothing

=item B<Returns:> 1 or 0

=back

=head3 get_clone_level

=over

=item B<Definition:> This will return the currently set L<clone_level|/clone_level> attribute value

=item B<Accepts:> nothing

=item B<Returns:> the level as an integer number or undef for nothing

=back

=head3 set_clone_level( $int )

=over

=item B<Definition:> This will set the L<clone_level|/clone_level> attribute

=item B<Accepts:> a positive integer

=item B<Returns:> nothing

=back

=head3 clear_clone_level

=over

=item B<Definition:> This will clear the L<clone_level|/clone_level> attribute

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head3 get_skip_clone_tests

=over

=item B<Definition:> This will return an ArrayRef[ArrayRef] with all skip tests for 
the L<skip_clone_tests|/skip_clone_tests> attribute

=item B<Accepts:> nothing

=item B<Returns:> an ArrayRef[ArrayRef]

=back

=head3 set_skip_clone_tests( [ [ $type, $key, $position, $level ], ] )

=over

=item B<Definition:> This will take an ArrayRef[ArrayRef] with all skip tests for 
the L<skip_clone_tests|/skip_clone_tests> attribute and replace any existing 
tests with the new list.

=item B<Accepts:>  ArrayRef[ArrayRef]

=item B<Returns:> nothing

=back

=head3 add_skip_clone_test( [ $type, $key, $position, $level ] )

=over

=item B<Definition:> This will add one array ref skip test callout to the 
L<skip_clone_tests|/skip_clone_tests> attribute list

=item B<Accepts:> [ $type, $key, $position, $level ]

=item B<Returns:> nothing

=back

=head3 has_skip_clone_tests

=over

=item B<Definition:> This will return the number of skip tests called out in 
the L<skip_clone_tests|/skip_clone_tests> attribute list

=item B<Accepts:> nothing

=item B<Returns:> a positive integer indicating how many array positions there are

=back

=head3 clear_skip_clone_tests

=over

=item B<Definition:> This will clear the the L<skip_clone_tests|/skip_clone_tests> 
attribute list

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head3 get_should_clone

=over

=item B<Definition:> This will get the current value of the attribute 
L<should_clone|/should_clone> 

=item B<Accepts:>  nothing

=item B<Returns:> a boolean value

=back

=head3 set_should_clone( $Bool )

=over

=item B<Definition:> This will set the attribute L<should_clone|/should_clone> 

=item B<Accepts:> a boolean value

=item B<Returns:> nothing

=back

=head3 has_should_clone

=over

=item B<Definition:> This will return true if the attribute L<should_clone|/should_clone>
is active

=item B<Accepts:> nothing

=item B<Returns:> a boolean value

=back

=head3 clear_should_clone

=over

=item B<Definition:> This will set the attribute L<should_clone|/should_clone> 
to on ( 1 ).  I<The name is awkward to accomodate one shot attribute changes.>

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head2 Attributes

Data passed to ->new when creating an instance using a class.  For modification of 
these attributes see L</Methods>.  The ->new function will either accept fat comma 
lists or a complete hash ref that has the possible appenders as the top keys.  
Additionally L<some attributes|/Supported one shot > that have all the following 
methods; get_$attribute, set_$attribute, has_$attribute, and clear_$attribute,
can be passed to L<deep_clone|/deep_clone( $arg_ref|%args )> and will be adjusted for 
just the run of that method call.  These are called 'one shot' attributes.

=head3 clone_level

=over

=item B<Definition:> When running a clone operation it is possible to stop cloning 
and use the actual data references in the original data structure below a certain 
level.  This sets the boundary for that level.

=item B<Default> undefined = everything is cloned

=item B<Range> positive integers (3 means clone to the 3rd level)
    
=back

=head3 skip_clone_tests

=over

=item B<Definition:> When running a clone operation it is possible to stop cloning 
and use the actual data references in the original data structure at clearly defined 
trigger points.  This is the way to define those points.  The definition can test against 
array position, match a hash key, also only test at a level 
L<I<(Testing at level 0 is not supported!)>|/should_clone( $Bool )>, and can use eq 
or =~ when matching.  The attribute is passed an ArrayRef of ArrayRefs.  Each sub_ref 
contains the following.

=over

=item B<$type> - this is any of the L<allowed|/Supported Node types> reference node 
types

=item B<$key> - this is either a scalar or regexref to use for matching a hash key

=item B<$position> - this is used to match an array position can be an integer or 'ANY'

=item B<$level> - this restricts the skipping test usage to a specific level only or 'ANY'

=back
    
=item B<Example>
	
	[ 
		[ 'HASH', 'KeyWord', 'ANY', 'ANY'], 
		# Dont clone the value of any hash key eq 'Keyword'
		[ 'ARRAY', 'ANY', '3', '4'], ], 
		#Don't clone the data in arrays at position three on level four
	]

=item B<Range> an infinite number of skip tests added to an array

=item B<Default> [] = no cloning is skipped

=back

=head3 should_clone

=over

=item B<Definition:> There are times when the cloning is built into code by adding the role 
to a class but you want to turn it off.  This attribute will cause the deep_clone function 
to return the donor_ref pointer as the cloned_ref.

=item B<Default> 1 = cloning occurs

=item B<Range> 1 | 0 = no cloning
    
=back

Attributes in 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 
can affect the output.

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

=item Support cloning through CodeRef nodes

=item Support cloning through Objects / Instances nodes

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

=item L<version|https://metacpan.org/module/version>

=item L<Moose::Role|https://metacpan.org/module/Moose::Role>

=item L<MooseX::Types::Moose|https://metacpan.org/module/MooseX::Types::Moose>

=back

=head1 SEE ALSO

=over

=item L<Smart::Comments> - is used if the -ENV option is set

=item L<Data::Walk|https://metacpan.org/module/Data::Walk>

=item L<Data::Walker|https://metacpan.org/module/Data::Walker>

=item L<Storable|https://metacpan.org/module/Storable> - dclone

=item L<Data::Walk::Print>

=item L<Data::Walk::Prune>

=item L<Data::Walk::Graft>

=back

=cut

#################### main pod documentation end #########################################