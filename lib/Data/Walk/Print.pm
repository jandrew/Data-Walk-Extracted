package Data::Walk::Print;

use Moose::Role;
requires '_has_secondary', '_process_the_data';
use MooseX::Types::Moose qw(
        HashRef
        ArrayRef
        Bool
        Str
        Ref
    );######<------------------------------------------------------  ADD New types here
use version; our $VERSION = qv('0.007_001');
$| = 1;
use Smart::Comments -ENV;
### Smart-Comments turned on for Data-Walk-Print

my $print_keys = {
    primary_ref     => 'print_ref',
    secondary_ref   => 'match_ref',
};

###############  Public Attributes  ####################################

has 'match_highlighting' =>(
    is      => 'ro',
    isa     => Bool,
    writer  => 'set_match_highlighting',
    default => 1,
);

###############  Public Methods  #######################################

sub print_data{
    ### <where> - Made it to print
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = 
            ( @_ == 2 and 
                (   ( is_HashRef( $_[1] ) and !( exists $_[1]->{print_ref} ) ) or
                    !is_HashRef( $_[1] )                                            ) ) ? 
                { print_ref => $_[1] }  :
            ( @_ == 2 and is_HashRef( $_[1] ) ) ? 
                $_[1] : 
                { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    @$passed_ref{ 'before_method', 'after_method' } = 
        ( '_print_before_method', '_print_after_method' );
    ##### <where> - Start recursive passing with  : $passed_ref
    $passed_ref = $self->_process_the_data( $passed_ref, $print_keys );
    ### <where> - End recursive passing with    : $passed_ref
    return 1;
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

sub _print_before_method{
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

sub _print_after_method{
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

sub _add_to_pending_string{
    my ( $self, $string ) = @_;
    ### <where> - reached add to pending string
    ### <where> - adding: $string
    $self->_set_pending_string( 
        (($self->_has_pending_string) ?
            $self->_pending_string : '') . 
        ( ( $string ) ? $string : '' )
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
    use Data::Walk::Extracted v0.007;
    use Data::Walk::Print v0.007;
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
    my $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Print' ) );
    my $AT_ST = $newclass->new(
            match_highlighting => 1,#This is the default
            sort_HASH => 1,#To force order for demo purposes
    );
    $AT_ST->print_data(
        print_ref   =>  $firstref,
        match_ref   =>  $secondref,
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

This L<Moose::Role> is mostly written for L<Data::Walk::Extracted>.  Both 
L<Data::Dumper> - Dump and L<YAML> - Dump functions are more mature than the printing function 
included here.  This is largely a demonstation module.

If this Role is used with another Module it requires a '_has_secondary' 
L<Attribute|https://metacpan.org/module/Moose::Manual::Attributes> in the class.  
This attribute is already implemented in L<Data::Walk::Extracted>

=head2 v0.007

=over

=item B<State> This code is still in Beta state and therefore is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.

=item B<Included> ArrayRefs and HashRefs are supported nodes for printing.  Strings and Numbers 
are all currently treated as base states and printed as strings.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to die.

=back

=head2 Use

One way to incorporate this role into L<Data::Walk::Extracted> and then use it is the method 
'with_traits' from L<Moose::Util>.  Otherwise see L<Moose::Manual::Roles>.

=head2 Attributes

Data passed to ->new when creating an instance using a class.  For modification of these attributes 
see L</Methods>.  The ->new function will either accept fat comma lists or a complete 
hash ref that has the possible appenders as the top keys.

=head3 match_highlighting

=over

=item B<Definition:> this determines if a comments string is added after each printed row that 
indicates how the 'print_ref' matches the 'match_ref' (or not).

=item B<Default> True (1)

=item B<Range> This is a Boolean data type and generally accepts 1 or 0
    
=back

=head3 L<Attributes in Data::Walk::Extracted|http://search.cpan.org/~jandrew/Data-Walk-Extracted/lib/Data/Walk/Extracted.pm#Attributes> 

also affect the output.

=head1 Methods

=head2 set_match_highlighting( $bool )

=over

=item B<Definition:> this is a way to change the match_highlighting attribute

=item B<Accepts:> a Boolean value

=item B<Returns:> 1

=back

=head2 print_data( $arg_ref|%args )

=over

=item B<Definition:> this is the method used to print a data reference

=item B<Accepts:> either a single variable or One or two named arguments

=over

=item B<single variable option> - if only one variable is sent and it fails the test 
for "exists $variable->{print_ref}" then the program will attempt to name it as 
print_ref => $variable

=item B<named variable options> - if variables are named including one with 'print_ref' 
then the following two named variables are accepted

=over

=item B<print_ref> - this is the data reference that should be printed in a perlish way 
- Required

=item B<match_ref> - this is a reference used to compare against the 'print_ref'
- Optional

=back

=back

=item B<Returns:> 1 (And prints out the data ref with matching assesment comments per 
L</match_highlighting>)

=back

=head1 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> with the '-ENV' option so setting the variable 
$ENV{Smart_Comments} will turn on smart comment reporting.  There are three levels 
of 'Smartness' called in this module '### #### #####'.  See the L<Smart::Comments> 
documentation for more information.

=back

=head1 TODO

=over

=item * Support printing CodeRefs

=item * Support printing Objects / Instances

=item * possibly adding an attribute, setter_method, and after method to allow printing 
output from other roles when they exit.  This falls in the "I'm not sure it's a good 
idea yet" catagory.

=back


=head1 SUPPORT

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

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

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dump

=item L<YAML> - Dump

=back

=cut

#################### main pod documentation end #####################
