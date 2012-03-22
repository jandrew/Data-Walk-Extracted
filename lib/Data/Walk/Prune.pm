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
use version; our $VERSION = qv('0.01_01');
use Smart::Comments -ENV;
$| = 1;
### Smart-Comments turned on for Data-Walk-Pruning

my $prune_keys = {
    slice_ref   => 'primary_ref',
    tree_ref    => 'secondary_ref',
};

my $cut_dispatch = {######<------------------------------------------------------  ADD New types here
    'HASH'  => \&_remove_hash_key,
    'ARRAY' => \&_clear_array_position,
};

###############  Public Attributes  ####################################

has 'splice_arrays' =>(
    is      => 'ro',
    isa     => Bool,
    writer  => 'change_splice_behavior',
    default => 1,
);

###############  Public Methods  #######################################

sub prune{#Used to convert names
    ### <where> - Made it to prune
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    $passed_ref = $self->_review_required_inputs( $passed_ref );
    ##### <where> - Start recursive passing with  : $passed_ref
    $passed_ref = $self->_walk_the_data( $passed_ref );
    ### <where> - End recursive passing with    : $passed_ref
    return $passed_ref->{secondary_ref};
}


sub before_method{
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
        $self->_remove_item( $passed_ref->{branch_ref}->[-1] );
        $passed_ref->{bounce} = 1;
    }elsif( is_ArrayRef( $slice_ref ) and
            @$slice_ref == 0                ){
        ### <where> - Marking array position for removal: $passed_ref->{branch_ref}->[-1]->[2]
        $self->_remove_item( $passed_ref->{branch_ref}->[-1] );
        $passed_ref->{bounce} = 1;
    }else{######<------------------------------------------------------  ADD New types here
        ### <where> - no action required - continue on
    }
    return $passed_ref;
}

sub after_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached after_method
    #### <where> - received input: $passed_ref
    my  $tree_ref   =
        ( exists $passed_ref->{secondary_ref} ) ?
            $passed_ref->{secondary_ref} : undef ;
    my  $ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
    ### <where> - tree_ref   : $tree_ref
    ### <where> - Slice state: $self->_has_cut_list
    if( $tree_ref and $self->_has_cut_list ){
        while( my $item = $self->_next_item ){
            $tree_ref = $self->_cut_the_item( $item, $tree_ref );
        }
        $passed_ref->{secondary_ref} = $tree_ref;
    }
    ### <where> - finished pruning at this node - clear the prune list
    $self->_clear_cut_list;
    return $passed_ref;
}

###############  Private Attributes  ####################################

has '_cut_list' =>(
    is      => 'ro',
    traits  => ['Array'],
    isa     => ArrayRef[ArrayRef[Item]],
    handles => {
        _remove_item    => 'push',
        _next_item      => 'shift',
    },
    clearer     => '_clear_cut_list',
    predicate   => '_has_cut_list',
);


###############  Private Methods / Modifiers  ##########################

sub _review_required_inputs{
    my ( $self, $passed_ref ) = @_;
    ### <where> - Made it to _has_required_inputs
    ##### <where> - Passed ref    : $passed_ref
    for my $key ( keys %$prune_keys ){
        if( $passed_ref->{$key} ){
            ### <where> - Required value exists for: $key
        }else{
            croak "The key -$key- is a required value and cannot be undefined";
        }
    }
    for my $key ( keys %$passed_ref ){
        if( $prune_keys->{$key} ){
            ### <where> - passed value is approved: $key
            $passed_ref->{$prune_keys->{$key}} = $passed_ref->{$key};
            delete $passed_ref->{$key};
        }else{
            croak "The key -$key- is not a supported parameter";
        }
    }
    $self->_has_secondary( 1 );
    ##### <where> - Passed ref    : $passed_ref
    return $passed_ref;
}

sub _cut_the_item{
    my ( $self, $item_ref, $tree_ref ) = @_;
    ### <where> - Made it to _cut_the_item
    ### <where> - item ref  : $item_ref
    ##### <where> - tree ref  : $tree_ref
    if( exists $cut_dispatch->{$item_ref->[0]} ){
        my $action  = $cut_dispatch->{$item_ref->[0]};
        ##### <where> - the action is: $action
        $tree_ref   = $self->$action( $item_ref, $tree_ref );
        ##### <where> - new tree ref : $tree_ref
    }else{
        croak "Currently the 'prune' function cannot be performed the " . 
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
    if( $self->splice_arrays ){
        splice( @$tree_ref, $item_ref->[2]);
    }else{
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
    use YAML::Any;
    use Moose::Util qw( with_traits );
    use lib '../lib';

    $| = 1;

    use Data::Walk::Extracted v0.05;
    use Data::Walk::Prune v0.01;

    my  $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Prune' ) );
    my  $edward_scissorhands = $newclass->new( splice_arrays => 1, );
    my  $firstref = Load(
            '---
            Helping:
                - Somelevel
                - MyKey:
                    MiddleKey:
                        LowerKey1: lvalue1
                        LowerKey2:
                            BottomKey1: bvalue1
                            BottomKey2: bvalue2'
        );
    $edward_scissorhands->prune(
            tree_ref    => $firstref, 
            slice_ref   => Load(
                '---
                Helping:
                - Somelevel
                - MyKey:
                    MiddleKey:
                        LowerKey1: []' 
            ),
        );
    say Dump( $firstref );
    
    #######################################
    #     Output of SYNOPSIS
    # 01 ---
    # 02 Helping:
    # 03 - Somelevel
    # 04 - MyKey:
    # 05     MiddleKey:
    # 06       LowerKey2:
    # 07         BottomKey1: bvalue1
    # 08         BottomKey2: bvalue2
    # 09     
    #######################################
    
=head1 DESCRIPTION

This L<Moose::Role> contains methods for implementing the method L</prune> using 
L<Data::Walk::Extracted>.  By sending a prune data ref that terminates in an empty 
hash_ref (no keys) or an empty array_ref (no positions) for the relevant data node 
reference type then the tree ref will be pruned at that spot.

The 'slice_ref' is passed to the 'primary_ref' in L<Data::Walk::Extracted> and the 
'tree_ref' is passed to the 'secondary_ref' in that class.  All additional attributes 
and methods for the class work as described in the documentation.

=head2 v0.01

=over

=item B<State> This code is still in Beta state and therefore is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.

=item B<Included> ArrayRefs and HashRefs are supported nodes for pruning.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to croak.

=back

=head1 Use

This is an object oriented L<Moose> Role and generally behaves that way.

=head1 Attributes

Data passed to ->new when creating an instance using a class.  For modification of these attributes 
see L</Methods>.  The ->new function will either accept fat comma lists or a complete 
hash ref that has the possible appenders as the top keys.

=head3 splice_arrays

=over

=item B<Definition:> when an array element is removed the position can remain as undef or be 
spliced out of the array.  This flag will determine that behavior (1 = splice).

=item B<Default> True (1)

=item B<Range> This is a Boolean data type and generally accepts 1 or 0
    
=back

=head1 Methods

=head2 change_splice_behavior( $bool )

=over

=item B<Definition:> this is a way to change the splice_arrays flag

=item B<Accepts:> a Boolean value

=item B<Returns:> 1

=back

=head2 prune( $passed_ref )

=over

=item B<Definition:> This will take a L</slice_ref> and use it to prune a L</tree_ref>

=item B<Accepts:> a hash ref with the keys slice_ref and tree_ref (both required).  
The data_refs can contain array_ref nodes, hash_ref nodes, strings, and Numbers.  
See L<Data::Walk::Extracted/TODO> for future support.

=item B<Returns:> The $tree_ref with any changes

=back

=head1 BUGS

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item Support pruning through CodeRef nodes

=item Support pruning through Objects / Instances nodes

=back

=head1 SUPPORT

=over

=item jandrew@cpan.org

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

=back

=cut

#################### main pod documentation end #####################