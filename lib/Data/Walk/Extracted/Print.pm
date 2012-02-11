package Data::Walk::Extracted::Print;
use Moose;
use MooseX::Types::Moose qw(
        ArrayRef
        HashRef
        Bool
        Str
    );
use version; our $VERSION = qv('0.03_01');

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
    ### <where> - received input: $passed_ref
    my  $branch_ref = $passed_ref->{branchref}->[-1];
    ### <where> - branchvalues: $branch_ref
    my $tab_string = ( $passed_ref->{level} - 1 ) ?
                ("\t" x ($passed_ref->{level} - 1)) : '' ;
    my $match_string = ( !($passed_ref->{_has_secondary}) or !($self->{match_highlighting}) ) ? '' :
                        ( ( exists $passed_ref->{secondary_ref} ) ?
                            "#<--matches secondary_ref" : "#<--no match" );
    ### <where> - match_string: $match_string
    if( $branch_ref and @{$branch_ref} == 2 ){
        print$tab_string;
        print(
            ( $branch_ref->[0] eq 'hash_key' ) ?
                "$branch_ref->[1] =>" :
            ( $branch_ref->[0] eq 'array_position' ) ?
                '' : '???????' );
        print(
            ( is_HashRef( $passed_ref->{primary_ref} ) ) ?
                " {$match_string\n" :
            ( is_ArrayRef( $passed_ref->{primary_ref} ) ) ?
                " [$match_string\n" : '' );
        ### <where> - act method $self: $self
        push @{$passed_ref->{branchref}->[-1]}, ($passed_ref->{level} - 1);
    }
    ### <where> - leaving before_method
    return $passed_ref;
}

sub after_method{
    my ( $self, $passedref ) = @_;
    ### <where> - reached after_method
    ### <where> - received input: $passedref
    my  $branchref = $passedref->{branchref}->[-1];
    ### <where> - branchvalues: $branchref
    my $tabstring = ( $branchref->[2] ) ?
        ("\t" x ($branchref->[2])) : '';
    my $matchstring = ( !$passedref->{_has_secondary} or !$self->{match_highlighting} ) ? '' :
                        ( ( exists $passedref->{secondary_ref} and
                            is_Str( $passedref->{secondary_ref} ) and
                            is_Str( $passedref->{primary_ref} ) and
                            $passedref->{primary_ref} eq $passedref->{secondary_ref} ) ?
                            "#<--matches secondary_ref" : "#<--no match" );
    my $terminator =
        ( is_Str( $passedref->{primary_ref} ) ) ?
            " '$passedref->{primary_ref}',$matchstring\n" :
        ( $branchref and @{$branchref} == 3 ) ?
            ( 
                ( is_HashRef( $passedref->{primary_ref} ) ) ?
                    $tabstring . "},\n" :
                ( is_ArrayRef( $passedref->{primary_ref} ) ) ?
                    $tabstring . "],\n" : '???????'
            ) :  '' ;
    print $terminator;
    ### <where> - after_method complete
    return $passedref->{object};
}

###############  Private Methods / Modifiers  ##########################


# Added to allow for a YAML based configfile to be passed
around BUILDARGS => sub{
    my $callback    = shift;#Callback method to send attribute values to the attribute
    my $class       = shift;#currently active blessed module name
    ###  <where> - Reached BUILDARGS
    ###  <where> - handle various input types-> YAML config file, hash ref, or standard callout
    my $returnref   =
        ( @_ == 1 && is_yamlfile( $_[0] ) ) ?
            to_yamlhashref( $_[0] ) :#YAML::Any::LoadFile( $_[0] ) :#TODO add Try::Tiny to handle YAML::LoadFile exceptions?
        ( @_ == 1 && is_HashRef( $_[0] ) ) ?
            $_[0] :#Not sure if this is a useful distinction but it should keep any passed hashrefs intact
            { @_ } ;#build a hashref so the return call can be standardized;
    ####  <where> - the final ref is: $returnref
    #####  <where> - ---------------------------------------------------------
    #####  <where> - $class
    #####  <where> - ---------------------------------------------------------
    #####  <where> - Callback is: $class->dump( $callback )
    #####  <where> - ---------------------------------------------------------
    #####  <where> - $returnref
    #####  <where> - ---------------------------------------------------------
    ##################  TODO add YAML string parsing, mixed config file and passed parameters, possibly JSON formats?
    return $class->$callback( $returnref );
};

#################### Phinish with a Phlourish #######################

no Moose;
__PACKAGE__->meta->make_immutable;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin ###################

__END__

=head1 NAME

Data::Walk::Extracted::Print - The default for Data::Walk::Extracted

=head1 SYNOPSIS
    
    #! C:/Perl/bin/perl
    use Modern::Perl;
    use YAML::Any;
    use Data::Walk::Extracted v0.03;
    use Data::Walk::Extracted::Print v0.03;#Only required if explicitly called
    
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
    Data::Walk::Extracted->walk_the_data(
        primary_ref     =>  $firstref,
        secondary_ref   =>  $secondref,
        #\/This is the default and does not need to be called(but will warn that the default is being used)
        object          =>  Data::Walk::Extracted::Default::Print->new(
                                #\/This is the default and can be turned off(#<-- messages)
                                match_highlighting => 1,
                            ),
    );
    
    #######################################
    #     Output of SYNOPSIS
    # 01:   Parsing => {#<--no match
    # 02: 	    HashRef => {#<--no match
    # 03: 		    LOGGER => {#<--no match
    # 04: 			    run => 'INFO',#<--no match
    # 05: 		    },
    # 06:       },
    # 07:   },
    # 08:   Someotherkey => 'value',#<--matches secondary_ref
    # 09:   Helping => [<--matches secondary_ref
    # 10: 	    'Somelevel',<--matches secondary_ref
    # 11:	    {<--matches secondary_ref
    # 12:		    MyKey => {<--matches secondary_ref
    # 13:			    MiddleKey => {<--matches secondary_ref
    # 14:				    LowerKey2 => {<--matches secondary_ref
    # 15:   					BottomKey1 => '12345',<--no match
    # 16:   					BottomKey2 => [<--matches secondary_ref
    # 17:   						 'bavalue1',<--matches secondary_ref
    # 18:   						 'bavalue2',<--no match
    # 19:   						 'bavalue3',<--no match
    # 20:   					],
    # 21:   				},
    # 22:   				LowerKey1 => 'lvalue1',<--matches secondary_ref
    # 23:   			},
    # 24:		},
    # 25:	},
    # 26:],
    #######################################

    
=head1 DESCRIPTION

This module is the default behaviour for L<Data::Walk::Extracted>.  It provides the 
methods L</before_method> and L</after_method> used by Data::Walk::Extracted.  Both 
L<Data::Dumper> Dump and L<YAML> Dump functions are more mature than the default 
Data::Walk Printing function included here.  This is largely a demonstation module.

=head2 v0.03

=over

=item B<State> This code is still in Beta state and therefore is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.

=item B<Included> ArrayRefs and HashRefs are supported nodes for printing.  Strings and Numbers 
are all currently treated as base states and printed as strings.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to croak.

=back

=head1 Use

This is an object oriented L<Moose> module and generally behaves that way.  
It uses the built-in Moose constructor (new).

=head1 Attributes

Data passed to ->new when creating an instance.  For modification of these attributes 
see L</Methods>.  The ->new function will either accept fat comma lists, a complete 
hash ref that has the possible appenders as the top keys, or a YAML based config file 
that passes a hash ref with appenders as top keys.  Possible Combinations of these are 
on the TODO list.

=head3 match_highlighting

=over

=item B<Definition:> this determines if a comments string is added after each row that 
indicates i the printed row matches the secondary_ref or not.

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

=item L<github|https://github.com/jandrewlund>

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

=item L<Modern::Perl>

=item L<version>

=item L<Moose>

=item L<MooseX::Types::Moose>

=back

=head1 SEE ALSO

=over

=item L<Smart::Comments> - Commented out but built in to the module

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dump

=item L<YAML> - Dump

=back

=cut

#################### main pod documentation end #####################
