package Data::Walk::Graft;

use Moose::Role;
requires '_process_the_data';
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
use Carp;
use version; our $VERSION = qv('0.001_003');
use Smart::Comments -ENV;
$| = 1;
### Smart-Comments turned on for Data-Walk-Graft

my $graft_keys = {
    primary_ref     => 'scion_ref',
    secondary_ref   => 'tree_ref',
};

###############  Public Attributes  ####################################

###############  Public Methods  #######################################

sub graft_data{#Used to convert names
    ### <where> - Made it to graft_data
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    $passed_ref->{before_method} = '_graft_before_method';
    ##### <where> - Start recursive passing with  : $passed_ref
    $passed_ref = $self->_process_the_data( $passed_ref, $graft_keys );
    ### <where> - End recursive passing with    : $passed_ref
    return $passed_ref->{tree_ref};
}

###############  Private Attributes  ####################################



###############  Private Methods / Modifiers  ###########################

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
    if( !$tree_ref and $scion_ref and ($scion_ref ne 'IGNORE') ){
        ### <where> - Found a difference - adding new element ...
        $passed_ref->{secondary_ref} = $scion_ref;
        $passed_ref->{bounce} = 1;
    }elsif( is_HashRef( $scion_ref ) and !is_HashRef( $tree_ref ) ){
        ### <where> - The next node is not a Hash - changing ...
        $passed_ref->{secondary_ref} = $scion_ref;
        $passed_ref->{bounce} = 1;
    }elsif( is_ArrayRef( $scion_ref ) and !is_ArrayRef( $tree_ref ) ){
        ### <where> - The next node is not an Array - changing ...
        $passed_ref->{secondary_ref} = $scion_ref;
        $passed_ref->{bounce} = 1;
    }elsif( $scion_ref and
            !is_Ref( $scion_ref ) and 
            $scion_ref ne 'IGNORE' and
            $scion_ref ne $tree_ref){
        ### <where> - The next node is a different string - changing ...
        $passed_ref->{secondary_ref} = $scion_ref;
        $passed_ref->{bounce} = 1;
    }else{######<------------------------------------------------------  ADD New types here
        ### <where> - no action required - continue on
    }
    return $passed_ref;
}

#################### Phinish with a Phlourish ##########################

no Moose::Role;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin ###################

__END__

=head1 NAME

Data::Walk::Graft - A way to say what should be added

=head1 SYNOPSIS
    
    #! C:/Perl/bin/perl
    use Modern::Perl;
    use Moose::Util qw( with_traits );
    use Data::Walk::Extracted v0.007;
    use Data::Walk::Graft v0.001;
    use Data::Walk::Print v0.007;

    my  $gardener = with_traits( 
            'Data::Walk::Extracted', 
            ( 
                'Data::Walk::Graft', 
                'Data::Walk::Print' 
            ) 
        )->new();
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
                OtherKey => 'Something',
            },
            MyArray =>[
                'IGNORE',
                {
                    AnotherKey => 'Chicken_Butt!',
                },
                'IGNORE',
                'IGNORE',
                'ValueFive',
            ],
        }, 
        tree_ref  => $tree_ref,
    );
    $gardener->print_data( $tree_ref );
    
    #######################################
    #     Output of SYNOPSIS
    # 01 {
    # 02 	MyArray => [
    # 03 		'ValueOne',
    # 04 		{
    # 05 			AnotherKey => 'Chicken_Butt!',
    # 06 		},
    # 07 		'ValueThree',
    # 08 		,
    # 09 		'ValueFive',
    # 10 	],
    # 11 	Helping => {
    # 12 		OtherKey => 'Something',
    # 13 		KeyTwo => 'A New Value',
    # 14 		KeyThree => 'Another Value',
    # 15 	},
    # 16 },
    #######################################
    
=head1 DESCRIPTION

This L<Moose::Role> contains methods for implementing the method L</graft_data> using 
L<Data::Walk::Extracted>.  Grafting is accomplished by sending a 'scion_ref' that has 
additions that need to be made to the 'tree_ref'.

=head2 v0.001

=over

=item B<State> This code is still in Beta state and therefore is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.

=item B<Included> ArrayRefs and HashRefs are supported nodes for grafting.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to croak.

=back

=head2 Use

One way to join this role with L<Data::Walk::Extracted> is the method 
'with_traits' from L<Moose::Util>.  Otherwise see L<Moose::Manual::Roles>.

=head2 Attributes

=head3 L<Attributes in Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 

affect the output.

=head2 Methods

=head3 graft_data( %args )

=over

=item B<Definition:> This will take a 'scion_ref' and use it to prune a 'tree_ref'.  
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
can contain array_ref nodes, hash_ref nodes, strings, and numbers.  If no 'tree_ref' is 
passed then the 'scion_ref' is passed in it's entirety.  If an array position in the 
'scion_ref' containing is never evaluated (for example a replacment is done higher in the 
data tree) then the grafted tree will contain 'IGNORE' in that element of the array not 
undef.  See L<Data::Walk::Extracted/TODO> for future support.

=item B<Returns:> The $tree_ref with any changes

=back

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

=item L<Carp>

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

#################### main pod documentation end #####################