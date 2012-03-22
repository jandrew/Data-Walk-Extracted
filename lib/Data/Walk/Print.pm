package Data::Walk::Print;

use Moose::Role;
use MooseX::Types::Moose qw(
        HashRef
        ArrayRef
        Bool
        Str
        Ref
    );######<------------------------------------------------------  ADD New types here
use Carp;
use version; our $VERSION = qv('0.05_01');
$| = 1;
use Smart::Comments -ENV;
requires '_has_secondary';
### Smart-Comments turned on for Data-Walk-Print

###############  Public Attributes  ####################################

has 'match_highlighting' =>(
    is      => 'ro',
    isa     => Bool,
    writer  => 'set_match_highlighting',
    default => 1,
);

###############  Public Methods  #######################################

sub before_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached before_method
    #### <where> - received input: $passed_ref
    #~ $self->_clear_match_string;
    my  $match_string =
            ($self->_has_match_string) ?
                $self->_match_string :
                '#<--- ' ;
    my  $branch_ref = $passed_ref->{branch_ref}->[-1];
    ### <where> - branch values             : $branch_ref
    ### <where> - current match highlighting: $self->match_highlighting
    my $should_print = 0;
    if( $branch_ref ){
        if( $branch_ref->[3] and $branch_ref->[0] ne 'TERMINATOR' ){
            $self->_add_to_pending_string( ("\t" x ($branch_ref->[3])) );
        }
        if( $branch_ref->[0] ne 'TERMINATOR' ){
            $self->_add_to_pending_string( $branch_ref->[1] );
        }
        if( $branch_ref->[0] eq 'HASH' ){######<------------------------------------------------------  ADD New types here
            $self->_add_to_pending_string( ' => ' );
            $match_string .=
                ( exists $passed_ref->{secondary_ref} ) ?
                    'Secondary Key Match - ' :
                    'Secondary Key Mismatch - ' ;
        }elsif( $branch_ref->[0] eq 'ARRAY' ){
            $match_string .=
                ( exists $passed_ref->{secondary_ref} ) ?
                    'Secondary Position Exists - ' :
                    'Secondary Position Does NOT Exist - ' ;
        }
    }
    ### <where> - match string is: $match_string
    if( is_HashRef( $passed_ref->{primary_ref} ) ){######<------------------------------------------------------  ADD New types here
        ### <where> - a HASH ref is next
        $self->_add_to_pending_string( '{' );
        $match_string .=
            ( exists $passed_ref->{secondary_ref} and
            is_HashRef( $passed_ref->{secondary_ref} ) ) ?
                'Ref Type Match' : 'Ref Type Mismatch' ;
        $should_print = 1;
    }elsif( is_ArrayRef( $passed_ref->{primary_ref} ) ){
        ### <where> - an ARRAY ref is next
        $self->_add_to_pending_string( '[' );
        $match_string .=
            ( exists $passed_ref->{secondary_ref} and
            is_ArrayRef( $passed_ref->{secondary_ref} ) ) ?
                'Ref Type Match' : 'Ref Type Mismatch' ;
        $should_print = 1;
    }elsif( $branch_ref and $branch_ref->[0] eq 'TERMINATOR' ){
        $self->_add_to_pending_string( "'$branch_ref->[1]'," );
        $match_string .= 
            ( exists $passed_ref->{secondary_ref} ) ?
                'Secondary Value Matches' : 
                'Secondary Value Does NOT Match' ;
        $should_print = 1;
    }
    if( ref $passed_ref->{primary_ref} ){
        my $skip_method = 'skip_' . (ref $passed_ref->{primary_ref}) . '_ref';
        if( $self->$skip_method ){
            $self->_add_to_pending_string( '# !!! SKIPPED !!!' );
        }
    }
    ### <where> - match string is   : $match_string
    ### <where> - match highlighting: $self->match_highlighting
    ### <where> - secondary prexist : $self->_had_secondary
    $self->_set_match_string( $match_string ) if $match_string;
    if( $should_print ){
        $self->_print_pending_string;
    }
    ### <where> - current string      : $self->_pending_string
    ### <where> - current match string: $self->_match_string
    ### <where> - leaving before_method
    return $passed_ref;
}

sub after_method{
    my ( $self, $passed_ref ) = @_;
    my  $branch_ref = $passed_ref->{branch_ref}->[-1];
    my  $match_string =
            ($self->_has_match_string) ?
                $self->_match_string :
            (!($self->_has_pending_string)) ?
                '#<--- ' : '' ;
    ### <where> - reached after_method
    ##### <where> - received input: $passed_ref
    ### <where> - branchvalues  : $branch_ref
    ### <where> - current match : $match_string
    if( $branch_ref ){
        if( !$self->_has_pending_string ){
            ### <where> - No currently pending string
            if( $branch_ref->[3] and is_Ref( $passed_ref->{primary_ref} ) ){
                $self->_add_to_pending_string( ("\t" x ($branch_ref->[3])) );
            }
        }
    }
    if( is_HashRef( $passed_ref->{primary_ref} ) ){######<------------------------------------------------------  ADD New types here
        ### <where> - a HASH ref is just completed
        $self->_add_to_pending_string( '}' );
        $match_string .=
            ( exists $passed_ref->{secondary_ref} and
            is_HashRef( $passed_ref->{secondary_ref} ) ) ?
                'Ref Type Match' : 'Ref Type Mismatch' ;
    }elsif( is_ArrayRef( $passed_ref->{primary_ref} ) ){
        ### <where> - an ARRAY ref is just completed
        $self->_add_to_pending_string( ']' );
        $match_string .=
            ( exists $passed_ref->{secondary_ref} and
            is_ArrayRef( $passed_ref->{secondary_ref} ) ) ?
                'Ref Type Match' : 'Ref Type Mismatch' ;
    }
    $self->_print_pending_string( ',' );
    ### <where> - after_method complete
    #### <where> - returning: $passed_ref
    return $passed_ref;
}

###############  Private Attributes  ###################################

has '_pending_string' =>(
    is          => 'ro',
    isa         => Str,
    writer      => '_set_pending_string',
    clearer     => '_clear_pending_string',
    predicate   => '_has_pending_string',
);

has '_match_string' =>(
    is          => 'ro',
    isa         => Str,
    writer      => '_set_match_string',
    clearer     => '_clear_match_string',
    predicate   => '_has_match_string',
);

###############  Private Methods / Modifiers  ##########################

sub _add_to_pending_string{
    my ( $self, $string ) = @_;
    ### <where> - reached add to pending string
    ### <where> - adding: $string
    $self->_set_pending_string( 
        (($self->_has_pending_string) ?
            $self->_pending_string : '') . 
        $string
    );
    return 1;
}

sub _print_pending_string{
    my ( $self, $string ) = @_;
    ### <where> - reached print pending string
    if( $self->_has_pending_string ){
        my  $new_string = $self->_pending_string;
            $new_string .= $string if $string;
            if( $self->match_highlighting and
                $self->_had_secondary and
                $self->_has_match_string        ){
                ### <where> - match_highlighting on - adding match string
                $new_string .= $self->_match_string;
            }
            $new_string .= "\n";
        ### <where> - printing string: $new_string
        print  $new_string;
    }
    $self->_clear_pending_string;
    $self->_clear_match_string;
    return 1;
}

#################### Phinish with a Phlourish ##########################

no Moose::Role;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin ######################

__END__

=head1 NAME

Data::Walk::Print - A data printing function

=head1 SYNOPSIS
    
    #! C:/Perl/bin/perl
    use Modern::Perl;
    use YAML::Any;
    use Moose::Util qw( with_traits );
    use lib '../lib';
    use Data::Walk::Extracted v0.05;
    use Data::Walk::Print v0.05;
    
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
                        BottomKey1: 12346
                        BottomKey2:
                        - bavalue1
                        - bavalue3'
    );
    # Apply the role
    my $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Print' ) );
    # Use the combined class to build an instance
    my $AT_ST = $newclass->new(
            match_highlighting => 1,#This is the default
            sort_HASH => 1,#To force order for demo purposes
    );
    # Walk the data with the Data walker
    $AT_ST->walk_the_data(
        primary_ref     =>  $firstref,
        secondary_ref   =>  $secondref,
    );
    
    #######################################
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
    #######################################

    
=head1 DESCRIPTION

This L<Moose::Role> is the default behaviour for L<Data::Walk::Extracted>.  It provides the 
methods L</before_method> and L</after_method> used by Data::Walk::Extracted.  Both 
L<Data::Dumper> - Dump and L<YAML> - Dump functions are more mature than the printing function 
included here.  This is largely a demonstation module.

If this Role is used with another Module it requires a '_has_secondary' Attribute in the class.  
This attribute is currently implemented in L<Data::Walk::Extracted>

=head2 v0.05

=over

=item B<State> This code is still in Beta state and therefore is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.

=item B<Included> ArrayRefs and HashRefs are supported nodes for printing.  Strings and Numbers 
are all currently treated as base states and printed as strings.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to croak.

=back

=head1 Use

This is an object oriented L<Moose> Role and generally behaves that way.

=head1 Attributes

Data passed to ->new when creating an instance using a class.  For modification of these attributes 
see L</Methods>.  The ->new function will either accept fat comma lists or a complete 
hash ref that has the possible appenders as the top keys.

=head3 match_highlighting

=over

=item B<Definition:> this determines if a comments string is added after each printed row that 
indicates how the primary_ref matches the secondary_ref (or not).

=item B<Default> True (1)

=item B<Range> This is a Boolean data type and generally accepts 1 or 0
    
=back

=head1 Methods

=head2 set_match_highlighting( $bool )

=over

=item B<Definition:> this is a way to change the match_highlighting attribute

=item B<Accepts:> a Boolean value

=item B<Returns:> 1

=back

=head2 before_method( $passed_ref )

=over

=item B<Definition:> this performs actions based on the current data state and position 
of the data walker prior to walking the current node.

=item B<Accepts:> the standard passed ref defined in L<Data::Walk::Extracted>

=item B<Returns:> The $passed_ref intact

=back

=head2 after_method( $passed_ref )

=over

=item B<Definition:> this performs actions based on the current data state and position 
of the data walker after walking the current node.

=item B<Accepts:> the standard passed ref defined in L<Data::Walk::Extracted>

=item B<Returns:> The the current instance of this package (not the full $passed_ref)

=back

=head1 BUGS

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item Support printing CodeRefs

=item Support printing Objects / Instances

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

=item L<version>

=item L<Moose::Role>

=item L<MooseX::Types::Moose>

=item L<Smart::Comments> - With the -ENV variable set

=back

=head1 SEE ALSO

=over

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dump

=item L<YAML> - Dump

=back

=cut

#################### main pod documentation end #####################
