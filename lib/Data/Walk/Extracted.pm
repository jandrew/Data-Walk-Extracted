package Data::Walk::Extracted;

use Modern::Perl;
use Moose;
use version; our $VERSION = qv('0.03_01');
use Carp;
#~ use Smart::Comments '###';#, '####'
### Smart-Comments turned on for Data-Walk-Extracted

use MooseX::Types::Moose qw(
        ArrayRef
        HashRef
        Object
        CodeRef
        RegexpRef
        ClassName
        RoleName
        Str
        Int
    );

###############  Public Attributes  ####################################

###############  Public Methods  #######################################

sub walk_the_data{#Used to scrub high level input
    ### <where> - Made it to walk_the_data
    #### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passedref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ### <where> - Passed hashref: $passedref
    my ( $level, $branchref ) = ();
    if( is_HashRef( $passedref->{primary_ref} ) or
        is_ArrayRef( $passedref->{primary_ref} ) ){
        #### <where> - primary_ref passed from user
    }else{
        croak "No primary hash or array reference passed to evaluate";
    }
    if( exists $passedref->{secondary_ref} ){
        #### <where> - secondary_ref passed from user
        if( is_HashRef( $passedref->{secondary_ref} ) or
            is_ArrayRef( $passedref->{secondary_ref} ) ){
            #### <where> - secondary_ref can be processed
            $passedref->{_has_secondary} = 1;
        }else{
            croak "The passed secondary_ref cannot be processesed - " . __PACKAGE__ .
            " does not handle " . (ref  $passedref->{secondary_ref}) . " refs";
        }
    }else{
        $passedref->{_has_secondary} = 0;
    }
    if( is_Object( $passedref->{object} ) ){
        #### <where> - object passed from user
    }else{
        require Data::Walk::Extracted::Print;
        $passedref->{object} = Data::Walk::Extracted::Print->new();
        carp "No action object passed to -" . __PACKAGE__ . 
            "- so -" . (ref $passedref->{object}) . "- will be used";
    }
    $passedref->{level} = ( is_Int( $passedref->{level} ) ) ? 
        is_Int( $passedref->{level} ) : 0 ;
    $passedref->{branchref} = [];
    ### <where> - Current dataref   : $passedref->{dataref}
    ### <where> - Current object    : $passedref->{object}
    ### <where> - Current level     : $passedref->{level}
    ### <where> - Initial branch    : $passedref->{branchref}
    $passedref->{object} = $self->_walk_the_data( $passedref );
    
    return $passedref->{object};
}

###############  Private Attributes  ###################################

###############  Private Methods / Modifiers  ##########################

sub _walk_the_data{
    my( $self, $passedref ) = @_;
    ### <where> - Made it to _walk_the_data
    ### <where> - Passed input  : $passedref
    if( $passedref->{object}->can( 'before_method' ) ){
        #### <where> - object has before_method
        my  $newref = $passedref->{object}->before_method( $passedref );
        if( $newref ){
            ### <where> - successfully passed before_method
            $passedref = $newref;
        }else{
            return $passedref->{object};
        }
    }
    ### <where> - determine what is next
    my  $nextlevel = $passedref->{level} + 1;
    my  $newpassedref = {
            level   => $nextlevel,
            object  => $passedref->{object},
        };
    #~ my  $secondary_match = 1;#Innocent until proven guilty
    if( is_ArrayRef( $passedref->{primary_ref} ) ){
        ### <where> - found ArrayRef at level : $nextlevel
        my $x = 0;
        #~ $secondary_match = ( 
            #~ exists $passedref->{secondary_ref} and
            #~ is_ArrayRef( $passedref->{secondary_ref} ) 
        #~ ) ? 1 : 0 ;
        for my $item ( @{$passedref->{primary_ref}} ){
            ### <where> - Proceccing array position : $x
            #### <where> - Processing array item     : $item
            ### <where> - Checking for secondary ref match
            if( exists $passedref->{secondary_ref} and
                is_ArrayRef( $passedref->{secondary_ref} ) and
                $#{$passedref->{secondary_ref}} >= $x           ){
                ### <where> - found an equivalent position in the secondary_ref at: $x
                $newpassedref->{secondary_ref} = $passedref->{secondary_ref}->[$x];
            }else{
                ### <where> - the currently researched array position doesn't exist in the secondary_ref
                #~ $secondary_match = 0;
            }
            push @{$newpassedref->{branchref}}, [ 'array_position', $x];
            $newpassedref->{primary_ref} = $passedref->{primary_ref}->[$x++];
            $newpassedref->{_has_secondary} = $passedref->{_has_secondary};
            #### <where> - Passing the data: $newpassedref
            $passedref->{object} = $self->_walk_the_data( $newpassedref );
        }
        ### <where> - returned from array_position parsing
    }elsif( is_HashRef( $passedref->{primary_ref} ) ){
        ### <where> - found HashRef at level : $nextlevel
        #~ $newpassedref->{type} = 'HashRef';
        #~ $secondary_match = ( 
            #~ exists $passedref->{secondary_ref} and
            #~ is_HashRef( $passedref->{secondary_ref} ) 
        #~ ) ? 1 : 0 ;
        for my $key ( keys %{$passedref->{primary_ref}} ){
            ### <where> - Processing hashref key: $key
            ### <where> - Checking for secondary ref match
            if( exists $passedref->{secondary_ref} and
                is_HashRef( $passedref->{secondary_ref} ) and
                exists $passedref->{secondary_ref}->{$key} ){
                ### <where> - found match in the secondary_ref for: $key
                $newpassedref->{secondary_ref} = $passedref->{secondary_ref}->{$key};
            }else{
                ### <where> - the currently researched hash key doesn't exist in the secondary_ref
                #~ $secondary_match = 0;
            }
            push @{$newpassedref->{branchref}}, [ 'hash_key', $key ];
            $newpassedref->{primary_ref} = $passedref->{primary_ref}->{$key};
            $newpassedref->{_has_secondary} = $passedref->{_has_secondary};
            #### <where> - Passing the data: $newpassedref
            $passedref->{object} = $self->_walk_the_data( $newpassedref );
        }
        ### <where> - returned from hashkey parsing
    }elsif( is_CodeRef( $passedref->{primary_ref} ) ){
        croak "Unmanaged datatype -CodeRef- found at level -$nextlevel-";
    }elsif( is_Object( $passedref->{primary_ref} ) ){
        croak "Unmanaged datatype -Object- found at level -$nextlevel-";
    }elsif( is_RegexpRef( $passedref->{primary_ref} ) ){
        croak "Unmanaged datatype -Regexpref- found at level -$nextlevel-";
    }elsif( is_ClassName( $passedref->{primary_ref} ) ){
        croak "Unmanaged value type -ClassName- found at level -$nextlevel-";
    }elsif( is_RoleName( $passedref->{primary_ref} ) ){
        croak "Unmanaged value type -RoleName- found at level -$nextlevel-";
    }elsif( is_Str( $passedref->{primary_ref} ) ){
        ### <where> - found Str at level : $nextlevel
        ### <where> - this is a base state and any value handling should be in the after_method!
        if( exists $passedref->{secondary_ref} ){
            if( $passedref->{primary_ref} eq $passedref->{secondary_ref} ){
                ### <where> - match found as string level for: $passedref->{primary_ref}
            }else{
                ### <where> - NO match found as string level for: $passedref->{primary_ref}
                delete $passedref->{secondary_ref};
            }
        }
    }else{
        croak "Unmanaged datatype -" . (ref $passedref->{primary_ref}) . 
                "- found at level -$nextlevel-";
    }
    ### <where> - testing possible action of after_method
    ### <where> - using passedref: $passedref
    if( $passedref->{object}->can( 'after_method' ) ){
        ### <where> - object has an after_method
        $passedref->{object} = $passedref->{object}->after_method( $passedref );
        ### <where> - returned from after_method
    }else{
        ### <where> - no action for next level  : $nextlevel
        ### <where> - and Type                  : $newpassedref->{type}
    }
    return $passedref->{object};
}

#################### Phinish with a Phlourish ##########################

no Moose;
__PACKAGE__->meta->make_immutable;

1;
# The preceding line will help the module return a true value

#################### main pod documentation begin ###################

__END__

=head1 NAME

Data::Walk::Extracted - An extracted dataref walker

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

This module takes a data reference (or two) and recursivly travels through it(them).  
Where the two references diverge the walker follows the primary data reference.
At the beginning and end of each branching node the code will attempt to call a method 
on a passed object instance with data from the current location of the node.  
This module is largely useless without that additional functionality provided by the 
object instance.  If no instance is provided the module has a default that will 
print the perlish version of the data stucture as it goes through.  Both 
L<Data::Dumper> Dump and L<YAML> Dump functions are more mature than the default 
Data::Walk Printing function included here.

The module uses L<Carp> to carp and croak so the variable $Carp::Verbose can be set 
for debugging.  There are no attributes used to maintain data in this module so each
recursive level creates its own view of itself.  B<Beware> Recursive parsing is not a 
good fit for all data since very deep data structures will burn a fair amount of perl 
memory!  Meaning that as the module recursively parses through the levels perl leaves
behind snapshots of the previous level that allow perl to keep track of it's location.

This is an implementation of the concept of extracted data walking from 
L<Higher-Order-Perl|http://hop.perl.plover.com/book/> Chapter 1 by Mark Jason Dominus.  
I<The book is well worth the money!>  With that said this is object oriented 
code not functional code and is both written in L<Moose> and the code expects an 
object instance (does not have to be a Moose class) to be available at the appropriate 
places for action.  The MJD equivalent is written in the functional style and expects 
a passed CodeRef at the action points.  There is clearly some overhead associated with 
both L<Moose> and the object oriented style choices.  Those choices are intentional on 
my side and should not be attributed to MJD.  

=head2 v0.03

=over

=item B<State> This code is still in Beta state and therefore the API is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.  API 
changes will only occur if the current functionality proves excessivly flawed in some fasion.  
All fixed functionality will be defined by the test suit.

=item B<Included> ArrayRefs and HashRefs are supported data walker nodes.  Strings and Numbers 
are all currently treated as base states.

=item B<Excluded> Objects and CodeRefs are not currently handled and may cause the code to croak.

=back

=head1 Use

This is an object oriented L<Moose> module and generally behaves that way.  
It uses the built-in Moose constructor (new).

=head1 Attributes

There are no attributes. L<currently|/TODO>

=head1 Methods

=head2 walk_the_data( %args )

This method is used to build a data reference that will recursivly parse the target 
data reference.  Effectivly it takes the passed reference(s) and an object instance used 
for node actions and bundles them with some Hansel and Gretel type programming crumbs.
This includes an attribute that remembers if a secondary_ref was initially passed to the
data walker.  The data walker then walks the data structure vertically using the following steps;

=over

=item B<First> L</before_method> is called on the passed action object instance if available.  
If the object method returns nothing the program returns back up the tree.  Otherwise the result
of the before_method is used to replace the passed ref recieved at this level of the recursion.

=item B<Second> It determines what type of node is next.

=item B<Third> - B<If> a branching node is found then the branches are identified, I<go to 
L</Fourth>> B<else> I<goto L</Sixth>>

=item B<Fourth> the next branch is chosen, the Hansel and Gretel breadcrumbs are 
built for the node choice and a new set of %args are built with a pared down dataref of data 
only found below that node choice.  If the secondary_ref has the same node then a pared down 
secondary_ref is also prepared.  Node matching for hashrefs is done by string compares of the
key only.  Node matching for arrayrefs is done by testing if the secondary_ref has the same array 
position as the primary_ref.  I<No position content compare is done!> The %newargs are 
then passed to the recursive (private) subroutine to be parsed in the same manner.  

=item B<Fifth> When the values are returned from the recursion call the node is checked 
for more branches. B<If> more branches are available I<go to L</Fourth>> B<else> I<go to L</Sixth>>

=item B<Sixth> - L</after_method>  is called on the passed action object instance if available.  If 
the next level is a string or number it must be handled here.  The after_method is expected to 
always return the action object instance.

=item B<Seventh> the action object instance is passed back up to the next level.

=back

=head3 %args

arguments are accepted in either a hash or hashref style.

=over

=item B<key> 'primary_ref'

=item B<value> - mandatory

=over

=item B<accepts> a multilevel dataref

=item B<range> HashRefs or ArrayRefs with string or number terminators

=back

=back

=over

=item B<key> 'secondary_ref'

=item B<value> - optional

=over

=item B<accepts> a multilevel dataref

=item B<range> HashRefs or ArrayRefs with string or number terminators

=back

=back

=over

=item B<key> 'object'

=item B<value> - optional - highly suggested

=over

=item B<default> If no object is sent the module will "require" 
L<Data::Walk::Extracted::Print> and then pass it to the walker with the data ref.  In 
general this shouldn't be a problem since it ships in the same package as this module.  
See the module for specific behaviour.

=item B<accepts> an object instance.  This object instance will be used to do the 
real work of the module.  This module will attempt to use two object methods from that 
instance, L</before_method> and L</after_method>.  In general the before_method and after_method 
are expected to receive and return a data reference from this module that includes 
everything listed above.

=item B<range> the object instance is only useful if it has at least one of two methods 
L</before_method> or L</after_method>.  The object instance can be a Moose class but it is not required.

=back

=back

=over

=item B<key> 'level'

=item B<value> - optional - discouraged

=over

=item B<default> 0 (the inital passed dataref is said to be at level 0)

=item B<accepts> an integer, I<beware of messing with this default>

=back

=back

=over

=item B<key> 'branchref'

=item B<value> - optional - discouraged

=over

=item B<default> []

=item B<accepts> an Array of Arrays, I<beware of messing with this default>

=back

=back

=head1 BUGS

=over

=item L<github|https://github.com/jandrewlund>

=back

=head1 TODO

=over

=item Use attributes as traffic flags with the current behavior preserved as default

=item Support recursion through CodeRefs

=item Support recursion through Objects

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

=item L<Modern::Perl>

=item L<version>

=item L<Carp>

=item L<Moose>

=item L<MooseX::Types::Moose>

=item L<Data::Walk::Extracted::Print> - or other action object

=back

=head1 SEE ALSO

=over

=item L<Smart::Comments> - Commented out but built into the module

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dump

=item L<YAML> - Dump

=back

=cut

#################### main pod documentation end #####################