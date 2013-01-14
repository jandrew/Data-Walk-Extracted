package Data::Walk::Clone;
use Moose::Role;
requires 
	'_process_the_data', 
	'_dispatch_method', 
	'_get_had_secondary';
use MooseX::Types::Moose qw(	
        HashRef
        ArrayRef
        Bool
    );######<--------------------------------------------------------  ADD New types here
use version; our $VERSION = qv('0.011_003');
if( $ENV{ Smart_Comments } ){
	use Smart::Comments -ENV;
	### Smart-Comments turned on for Data-Walk-Clone
}

#########1 Package Variables  3#########4#########5#########6#########7#########8#########9

$| = 1;
my $clone_keys = {
    donor_ref => 'primary_ref',
};

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9

my 	$seed_clone_dispatch ={######<------------------------------------  ADD New types here
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
		OBJECT => sub{
			unless( exists $_[1]->{secondary_ref} ){
				$_[1]->{secondary_ref} = bless( {}, ref $_[1]->{primary_ref} );
			}
			return $_[1];
		},
		SCALAR => sub{ 
			$_[1]->{secondary_ref} = $_[1]->{primary_ref};
			return $_[1];
		},
		name => 'seed_clone_dispatch',#Meta data
	};

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9

has 'should_clone' =>(
	is			=> 'ro',
	isa			=> Bool,
	writer		=> 'set_should_clone',
	reader		=> 'get_should_clone',
	predicate	=> 'has_should_clone',
	default		=> 1,
);

sub clear_should_clone{
	### <where> - turn cloning back on at clear_should_clone ...
    my ( $self, ) = @_;
	$self->set_should_clone( 1 );
	return 1;
}

#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

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
		'before_method', 'after_method',
	} = ( 
		'_clone_before_method',	'_clone_after_method',
	);
	##### <where> - Start recursive parsing with  : $passed_ref
	$passed_ref = $self->_process_the_data( $passed_ref, $clone_keys );
	$self->_set_first_pass( 1 );# Re-set
	### <where> - End recursive parsing with    : $passed_ref
	return $passed_ref->{secondary_ref};
}

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has '_first_pass' =>(
	is			=> 'ro',
	isa			=> Bool,
	writer		=> '_set_first_pass',
	reader		=> '_get_first_pass',
	default		=> 1,
);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _clone_before_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _clone_before_method
    #### <where> - received input: $passed_ref
    ### <where> - doner_ref: $passed_ref->{primary_ref}
	##### <where> - self: $self
	if( $self->_get_first_pass ){
		### <where> perform a one time test for should_clone ...
		if( !$self->get_should_clone ){
			### <where> - skipping level now ...
			$passed_ref->{skip} = 'YES';
		}else{
			### <where> - turn on one element of cloning ...
			$self->_set_had_secondary( 1 );
		}
		$self->_set_first_pass( 0 );
	}
    return $passed_ref;
}

sub _clone_after_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _clone_after_method
    #### <where> - received input: $passed_ref
	### <where> - current item: $passed_ref->{branch_ref}->[-1]
	### <where> - should clone?: $self->get_should_clone
	if( $self->get_should_clone and
		$passed_ref->{skip} eq 'NO'	){
		### <where> - seeding the clone as needed for: $passed_ref->{primary_type}
		$passed_ref = $self->_dispatch_method(
			$seed_clone_dispatch,
			$passed_ref->{primary_type},
			$passed_ref,
		);
	}else{
		# Eliminating the clone at this level
		$passed_ref->{secondary_ref} =  $passed_ref->{primary_ref};
	}
    #### <where> - the new passed_ref is: $passed_ref
    return $passed_ref;
}

#########1 Phinish Strong     3#########4#########5#########6#########7#########8#########9

no Moose::Role;

1;
# The preceding line will help the module return a true value

#########1 Main POD starts    3#########4#########5#########6#########7#########8#########9

__END__

=head1 NAME

Data::Walk::Clone - deep data cloning with boundaries

=head1 SYNOPSIS
    
	#!perl
	use Modern::Perl;
	use Moose::Util qw( with_traits );
	use Data::Walk::Extracted 0.019;
	use Data::Walk::Clone 0.011;

	my  $dr_nisar_ahmad_wani = with_traits( 
			'Data::Walk::Extracted', 
			( 'Data::Walk::Clone',  ) 
		)->new( 
			skip_node_tests =>[  [ 'HASH', 'LowerKey2', 'ALL',   'ALL' ] ],
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
methods for implementing the method L<deep_clone|/deep_clone( $arg_ref|%args|$data_ref )> using 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm>.  
This method is used to deep clone (clone many/all) levels of a data ref.  Deep cloning 
is accomplished by sending a 'donor_ref' that has data nodes that you want copied into a 
different memory location.  In general Data::Walk::Extracted already deep clones any 
output as part of its data walking so the primary value of this role is to manage 
deep cloning boundaries. It may be that some portion of the data should maintain common 
memory references to the original memory references and so all of the Data::Walk::Extracted 
skip methods will be recognized and supported.  Meaning that if a node is skipped the 
data reference will be copied directly rather than cloned.

=head2 USE

This is a L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles>. One way to 
incorporate this role into 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm>. 
is 
L<MooseX::ShortCut::BuildInstance|http://search.cpan.org/~jandrew/MooseX-ShortCut-BuildInstance/lib/MooseX/ShortCut/BuildInstance.pm>.
or read L<Moose::Util|https://metacpan.org/module/Moose::Util> for more class building 
information.

=head1 Attributes

Data passed to -E<gt>new when creating an instance.  For modification of these attributes 
see L</Methods>.  The -E<gt>new function will either accept fat comma lists or a 
complete hash ref that has the possible attributes as the top keys.  Additionally 
L<some attributes|/Supported one shot attributes> that have all the following 
methods; get_$attribute, set_$attribute, has_$attribute, and clear_$attribute,
can be passed to L<prune_data|/prune_data( %args )> and will be 
adjusted for just the run of that method call.  These are called 'one shot' 
attributes.

=head2 should_clone

=over

=item B<Definition:> There are times when the cloning needs to be turned off.  This 
is the switch.  If this is set to 0 then deep_clone just passes the doner ref back.

=item B<Default> undefined = everything is cloned

=item B<Range> Boolean values (0|1)
    
=back

Attributes in 
L<Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes>
 - also affect the output.

=head1 Methods

=head2 deep_clone( $arg_ref|%args|$data_ref )

=over

=item B<Definition:> This takes a 'donor_ref' and deep clones it.

=item B<Accepts:> either a single data reference or named arguments 
in a fat comma list or hashref

=over

=item B<Hash option> - if data comes in a fat comma list or as a hash ref 
and the keys include a 'donor_ref' key then the list is processed as such.

=over

=item B<donor_ref> - this is the data reference that should be deep cloned - required

=item B<[attribute name]> - attribute names are accepted with temporary attribute 
settings.  These settings are temporarily set for a single "deep_clone" call and 
then the original attribute values are restored.  For this to work the the attribute 
must meet the L<necessary criteria|/get_$attribute, set_$attribute>.

=back

=item B<single data reference option> - if only one data_ref is sent and it fails 
the test;

	exists $data_ref->{donor_ref}

then the program will attempt to name it as donor_ref => $data_ref and then process 
the data as a fat comma list.

=back

=item B<Returns:> The deep cloned data reference

=back

=head2 get_should_clone

=over

=item B<Definition:> This will get the current value of the attribute 
L<should_clone|/should_clone> 

=item B<Accepts:>  nothing

=item B<Returns:> a boolean value

=back

=head2 set_should_clone( $Bool )

=over

=item B<Definition:> This will set the attribute L<should_clone|/should_clone> 

=item B<Accepts:> a boolean value

=item B<Returns:> nothing

=back

=head2 has_should_clone

=over

=item B<Definition:> This will return true if the attribute L<should_clone|/should_clone>
is active

=item B<Accepts:> nothing

=item B<Returns:> a boolean value

=back

=head2 clear_should_clone

=over

=item B<Definition:> This will set the attribute L<should_clone|/should_clone> 
to one ( 1 ).  I<The name is awkward to accomodate one shot attribute changes.>

=item B<Accepts:> nothing

=item B<Returns:> nothing

=back

=head1 Caveat utilitor

=head2 Supported Node types

=over

=item B<ARRAY>

=item B<HASH>

=item B<SCALAR>

=back

=head2 Supported one shot attributes

=over

=item clone_level

=item L<explanation|/Attributes>

=back

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

=item L<github Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item * Support cloning through Objects / Instances nodes

=item * Support cloning through CodeRef nodes

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

=item L<Data::Walk::Extracted::Dispatch>

=item L<MooseX::Types::Moose>

=item L<version>

=item L<Moose::Role>

=over

=item B<requires>

=over

=item _process_the_data

=item _get_had_secondary

=item _dispatch_method

=back

=back

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

#########1 Main POD ends      3#########4#########5#########6#########7#########8#########9