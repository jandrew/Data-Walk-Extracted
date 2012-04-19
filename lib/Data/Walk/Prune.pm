package Data::Walk::Prune;

use Moose::Role;
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
use version; our $VERSION = qv('0.003_003');
use Smart::Comments -ENV;
$| = 1;
### Smart-Comments turned on for Data-Walk-Prune

my $prune_keys = {
    primary_ref     => 'slice_ref',
    secondary_ref   => 'tree_ref',
};

my $prune_dispatch = {######<------------------------------------------------------  ADD New types here
    'HASH'  => \&_remove_hash_key,
    'ARRAY' => \&_clear_array_position,
};

###############  Public Attributes  ####################################

###############  Public Methods  #######################################

sub prune_data{#Used to convert names
    ### <where> - Made it to prune_data
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    @$passed_ref{ 'before_method', 'after_method' } = 
        ( '_prune_before_method', '_prune_after_method' );
    ##### <where> - Start recursive passing with  : $passed_ref
    $passed_ref = $self->_process_the_data( $passed_ref, $prune_keys );
    ### <where> - End recursive passing with    : $passed_ref
    return $passed_ref->{tree_ref};
}

###############  Private Attributes  ####################################

has '_prune_list' =>(
    is      => 'ro',
    traits  => ['Array'],
    isa     => ArrayRef[ArrayRef[Item]],
    handles => {
        _add_prune_item     => 'push',
        _next_prune_item    => 'shift',
    },
    clearer     => '_clear_prune_list',
    predicate   => '_has_prune_list',
);


###############  Private Methods / Modifiers  ##########################


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
    }elsif( is_HashRef( $slice_ref ) and
        ( keys %$slice_ref ) == 0   ){
        ### <where> - Marking hash key for removal: $passed_ref->{branch_ref}->[-1]->[1]
        $self->_add_prune_item( $passed_ref->{branch_ref}->[-1] );
        $passed_ref->{bounce} = 1;
    }elsif( is_ArrayRef( $slice_ref ) and
            @$slice_ref == 0                ){
        ### <where> - Marking array position for removal: $passed_ref->{branch_ref}->[-1]->[2]
        $self->_add_prune_item( $passed_ref->{branch_ref}->[-1] );
        $passed_ref->{bounce} = 1;
    }else{######<------------------------------------------------------  ADD New types here
        ### <where> - no action required - continue on
    }
    return $passed_ref;
}

sub _prune_after_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached after_method
    #### <where> - received input: $passed_ref
    my  $tree_ref   =
        ( exists $passed_ref->{secondary_ref} ) ?
            $passed_ref->{secondary_ref} : undef ;
    my  $ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
    ### <where> - tree_ref   : $tree_ref
    ### <where> - Slice state: $self->_has_prune_list
    if( $tree_ref and $self->_has_prune_list ){
        while( my $item = $self->_next_prune_item ){
            $tree_ref = $self->_prune_the_item( $item, $tree_ref );
        }
        $passed_ref->{secondary_ref} = $tree_ref;
    }
    ### <where> - finished pruning at this node - clear the prune list
    $self->_clear_prune_list;
    return $passed_ref;
}

sub _prune_the_item{
    my ( $self, $item_ref, $tree_ref ) = @_;
    ### <where> - Made it to _prune_the_item
    ### <where> - item ref  : $item_ref
    ##### <where> - tree ref  : $tree_ref
    if( exists $prune_dispatch->{$item_ref->[0]} ){
        my $action  = $prune_dispatch->{$item_ref->[0]};
        ##### <where> - the action is: $action
        $tree_ref   = $self->$action( $item_ref, $tree_ref );
        ##### <where> - new tree ref : $tree_ref
    }else{
        croak "Currently the 'prune' function cannot be performed on the " . 
            $item_ref->[0] . '-ref node for position ' . $item_ref->[2];
    }
    ### <where> - cut completed succesfully
    return $tree_ref;
}

sub _remove_hash_key{
    my ( $self, $item_ref, $tree_ref ) = @_;
    ### <where> - Made it to _remove_hash_key
    ##### <where> - self      : $item_ref
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

#################### Phinish with a Phlourish ##########################

no Moose::Role;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin ###################

__END__

=head1 NAME

Data::Walk::Prune - A way to say what should be removed

=head1 SYNOPSIS
    
    #! C:/Perl/bin/perl
    use Modern::Perl;
    use Moose::Util qw( with_traits );
    $| = 1;
    use Data::Walk::Extracted v0.007;
    use Data::Walk::Prune v0.003;
    use Data::Walk::Print v0.007;

    my  $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Prune', 'Data::Walk::Print' ) );
    my  $edward_scissorhands = $newclass->new( change_array_size => 1, );#Default
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
    $edward_scissorhands->prune_data(
            tree_ref    => $firstref, 
            slice_ref   => {
                Helping => [
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
    $edward_scissorhands->print_data( $firstref );
    
    #######################################
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
    # 11 					LowerKey1 => 'low_value1',
    # 12 				},
    # 13 			},
    # 14 		},
    # 15 	],
    # 16 },
    #######################################
    
=head1 DESCRIPTION

This L<Moose::Role> contains methods for implementing the method L</prune_data> using 
L<Data::Walk::Extracted>.  By sending a 'slice_ref' that terminates in an empty 
hash_ref (no keys) or an empty array_ref (no positions) for the relevant data node 
reference type then the 'tree_ref' will be pruned at that spot.  L</prune_data> returns 
the resulting 'tree_ref' after pruning.

=head2 v0.003

=over

=item B<State> This code is still in Beta state and therefore is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.

=item B<Included> ArrayRefs and HashRefs are supported nodes for pruning.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to croak.

=back

=head2 Use

One way to incorporate this role into L<Data::Walk::Extracted> and then use it is the method 
'with_traits' from L<Moose::Util>.  Otherwise see L<Moose::Manual::Roles>.

=head2 Attributes

=head3 L<Attributes in Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 

affect the output.

=head2 Methods

=head3 prune_data( %args )

=over

=item B<Definition:> This will take a 'slice_ref' and use it to prune a 'tree_ref'.  
The code looks for empty hash refs or array refs to show where to cut.  If a key 
has an empty ref value then the key is deleted.  If the array position has an empty 
ref then the array position is 
L<deleted/cleared|http://search.cpan.org/~jandrew/Data-Walk-Extracted-v0.05_07/lib/Data/Walk/Extracted.pm#change_array_size>

=item B<Accepts:> a hash ref with the keys 'slice_ref' and 'tree_ref' (both required).  
The data_refs can contain array_ref nodes, hash_ref nodes, strings, and numbers.  
See L<Data::Walk::Extracted/TODO> for future support.

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

=item Support pruning through CodeRef nodes

=item Support pruning through Objects / Instances nodes

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