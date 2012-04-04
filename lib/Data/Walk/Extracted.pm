package Data::Walk::Extracted;

use Modern::Perl;
use Moose;
use version; our $VERSION = qv('0.05_07');
use Carp;
use Smart::Comments -ENV;
$| = 1;
### Smart-Comments turned on for Data-Walk-Extracted
use MooseX::Types::Moose qw(
        ArrayRef
        HashRef
        Object
        CodeRef
        RegexpRef
        ClassName
        RoleName
        Ref
        Str
        Int
        Bool
    );
use Moose::Util qw( apply_all_roles with_traits );# 

my $walk_the_data_keys = {
    primary_ref     => 1,#Required
    secondary_ref   => 0,#Optional
    branch_ref      => 0,#Don't generally use
};

#Add type here and then Search on ARRAY or HASH and is_ArrayRef 
# or is_HashRef to find locations to update
my $supported_types = {######<------------------------------------------------------  ADD New types here
    'HASH'          => 'is_HashRef',
    'ARRAY'         => 'is_ArrayRef',
    'TERMINATOR'    => 'is_Str',
    'END'           => undef,
};

###############  Public Attributes  ####################################

for my $type ( keys %$supported_types ){
    my $sort_attribute = 'sort_' . $type;
    has $sort_attribute =>(
        is      => 'ro',
        isa     => Bool,#TODO Add other sort type support
        default => 0,
    );
    my $skip_attribute = 'skip_' . $type . '_ref';
    has $skip_attribute =>(
        is      => 'rw',
        isa     => Bool,
        default => 0,
    );
}

###############  Public Methods  #######################################

sub walk_the_data{#Used to scrub high level input
    ### <where> - Made it to walk_the_data
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = ( @_ == 2 and is_HashRef( $_[1] ) ) ? $_[1] : { @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    $self->_has_required_inputs( $passed_ref );
    $self->_test_inputs( $passed_ref );
    $self->_has_secondary( exists $passed_ref->{secondary_ref} );
    ##### <where> - Start recursive passing with  : $passed_ref
    $passed_ref = $self->_walk_the_data( $passed_ref );
    delete $passed_ref->{branch_ref};
    ### <where> - End recursive passing with    : $passed_ref
    return $passed_ref;
}

###############  Private Attributes  ###################################

has '_had_secondary' =>(
    is      => 'ro',
    isa     => Bool,
    writer  => '_has_secondary',
    default => 0,
);

###############  Private Methods / Modifiers  ##########################

sub _walk_the_data{
    my( $self, $passed_ref ) = @_;
    ### <where> - Made it to _walk_the_data
    ##### <where> - Passed input  : $passed_ref
    
    if( $self->can( 'before_method' ) ){
        ### <where> - role has a before_method
        $passed_ref = $self->before_method( $passed_ref );
        ### <where> - completed before_method
        #### <where> - the current passed ref is: $passed_ref
        if( !$passed_ref or exists $passed_ref->{bounce} ){
            ### <where> - returning to the previous level without parsing this node!
            delete $passed_ref->{bounce};
            return $passed_ref;
        }
    }else{
        ### <where> - No before_method found
    }
    
    ### <where> - determine what is next
    my  $ref_type   = $self->_will_parse_next_ref( $passed_ref );
    my  $list_ref;
    if( $ref_type ){
        @$list_ref =######<------------------------------------------------------  ADD New types here
            ( $ref_type eq 'ARRAY' ) ?
                @{$passed_ref->{primary_ref}} :
            ( $ref_type eq 'HASH' ) ?
                ( keys %{$passed_ref->{primary_ref}} ) :
            ( $ref_type eq 'TERMINATOR' ) ?
                ( $passed_ref->{primary_ref} ) :
                () ;
        my  $sort_attribute = 'sort_' . $ref_type;
        ### <where> - Sort attribute: $sort_attribute
        ### <where> - Sort setting  : $self->$sort_attribute
        if( $ref_type and $self->$sort_attribute eq 1 ){
            @$list_ref = sort @$list_ref;
            if( $ref_type eq 'ARRAY' ){
                $passed_ref->{primary_ref} = [ sort @{$passed_ref->{primary_ref}} ];
                if( exists $passed_ref->{secondary_ref} ){
                    $passed_ref->{secondary_ref} = 
                        [ sort @{$passed_ref->{secondary_ref}} ];
                }
            }
        }elsif( $ref_type and $self->$sort_attribute ){###################   UNTESTED !!!! ######
            @$list_ref = sort { $self->$sort_attribute } @$list_ref;
            if( $ref_type eq 'ARRAY' ){
                $passed_ref->{primary_ref} =
                    [ sort { $self->$sort_attribute } @{$passed_ref->{primary_ref}} ];
                if( exists $passed_ref->{secondary_ref} ){
                    $passed_ref->{secondary_ref} = 
                        [ sort { $self->$sort_attribute } @{$passed_ref->{secondary_ref}} ];
                }
            }
        }
        my  $new_passed_ref = {
            branch_ref  => $passed_ref->{branch_ref},
        };
        $passed_ref = $self->_cycle_the_list( $ref_type, $list_ref, $passed_ref, $new_passed_ref );
    }
    
    if( $self->can( 'after_method' ) ){
        ### <where> - role has an after_method
        $passed_ref = $self->after_method( $passed_ref );
        #### <where> - returned from after_method: $passed_ref
    }else{
        ### <where> - No after_method found
    }
    #### <where> - returning passedref: $passed_ref
    return $passed_ref;
}

sub _will_parse_next_ref{
    my ( $self, $passed_ref ) = @_;
    ### <where> - Made it to _will_parse_next_ref
    ##### <where> - Passed ref              : $passed_ref
    my  $ref_type = $self->_extracted_ref_type( $passed_ref->{primary_ref} );
    my  $skip_attribute = 'skip_' . $ref_type . '_ref';
    my  $skip_ref       = $self->$skip_attribute;
    ### <where> - The current ref type is   : $ref_type
    ### <where> - Skip attribute is         : $skip_attribute
    ### <where> - Skip attribute method call: $self->$skip_attribute
    ### <where> - Skip ref status is        : $skip_ref
    if( $skip_ref ){# or $ref_type eq 'TERMINATOR'
        ### <where> - returning skip -0-
        return 0;
    }elsif( exists $supported_types->{$ref_type} and
            $supported_types->{$ref_type}           ){
        ### <where> - returning: $ref_type
        return $ref_type;
    }else{
        croak "The passed reference type -$ref_type- cannot (yet) be processed by " . __PACKAGE__;
    }
}

sub _cycle_the_list{
    my ( $self, $ref_type, $list_ref, $passed_ref, $new_passed_ref ) = @_;#
    ### <where> - Made it to _cycle_the_list
    ##### <where> - ref type    : $ref_type
    ##### <where> - ref list    : $list_ref
    ##### <where> - Passed ref  : $passed_ref
    ##### <where> - New ref     : $new_passed_ref
    for my $x ( 0..$#$list_ref ){
        my  $item = (   $ref_type eq 'HASH' or
                        $ref_type eq 'TERMINATOR' ) ?######<------------------------------------------------------  ADD New types here
            $list_ref->[$x] : '' ;
        ### <where> - Processing position   : $x
        ### <where> - Processing item       : $item
        $new_passed_ref->{primary_ref} =######<------------------------------------------------------  ADD New types here
            ( $ref_type eq 'ARRAY' ) ?
                $list_ref->[$x] :
            ( $ref_type eq 'HASH' ) ?
                $passed_ref->{primary_ref}->{$item} : undef ;
        push @{$new_passed_ref->{branch_ref}}, [ 
            $ref_type, 
            $item, 
            $x,
            ((exists $passed_ref->{branch_ref} and @{$passed_ref->{branch_ref}}) ?
                ($passed_ref->{branch_ref}->[-1]->[3] + 1) : 1),
        ];
        ### <where> - Checking for secondary ref match
        if( $self->_had_secondary and $self->_secondary_ref_match( $passed_ref, $new_passed_ref ) ){
            $new_passed_ref->{secondary_ref} =######<------------------------------------------------------  ADD New types here
            ( $ref_type eq 'ARRAY' ) ?
                $passed_ref->{secondary_ref}->[$x] :
            ( $ref_type eq 'HASH' ) ?
                $passed_ref->{secondary_ref}->{$item} :
                undef ;
        }else{
            delete $new_passed_ref->{secondary_ref};
        }
        ##### <where> - Passing the data: $new_passed_ref
        my $alternative_passed_ref = $self->_walk_the_data( $new_passed_ref );
        pop @{$new_passed_ref->{branch_ref}};
        ### <where> - pass any data reference adjustments upward
        #### <where> - current position is: $x
        #### <where> - the returned ref is: $alternative_passed_ref
        if( $ref_type eq 'ARRAY' ){######<------------------------------------------------------  ADD New types here
            $passed_ref->{primary_ref}->[$x] = $alternative_passed_ref->{primary_ref};
            if( exists $alternative_passed_ref->{secondary_ref} ){
                $passed_ref->{secondary_ref}->[$x] = $alternative_passed_ref->{secondary_ref};
            }
        }elsif( $ref_type eq 'HASH' ){
            $passed_ref->{primary_ref}->{$item} = $alternative_passed_ref->{primary_ref};
            if( exists $alternative_passed_ref->{secondary_ref} ){
                $passed_ref->{secondary_ref}->{$item} = $alternative_passed_ref->{secondary_ref};
            }
        }
        #### <where> - current passed_ref: $passed_ref
        $x++;
    }
    return $passed_ref;
}

sub _has_required_inputs{
    my ( $self, $passed_ref ) = @_;
    ### <where> - Made it to _has_required_inputs
    ##### <where> - Passed ref    : $passed_ref
    for my $key ( keys %$walk_the_data_keys ){
        if( $walk_the_data_keys->{$key} ){
            ### <where> - A value is required for: $key
            if( $passed_ref->{$key} ){
                ### <where> - Required value exists for: $key
            }else{
                croak "The key -$key- is a required value and cannot be undefined";
            }
        }
    }
    return 1;
}

sub _test_inputs{
    my ( $self, $passed_ref ) = @_;
    ### <where> - Made it to _test_inputs
    ##### <where> - Passed ref    : $passed_ref
    for my $key ( keys %$passed_ref ){
        ### <where> - Testing key: $key
        if( exists $walk_the_data_keys->{$key} ){
            ### <where> - Acceptable passed key: $key
        }else{
            croak "The passed key -$key- is not supported by " . __PACKAGE__;
        }
    }
}

sub _extracted_ref_type{
    my ( $self, $passed_ref ) = @_;
    ### <where> - made it to _extracted_ref_type
    ##### <where> - the passed ref is: $passed_ref
    my  $response =
            ( !( defined $passed_ref ) ) ?
                'END' :
            is_Ref( $passed_ref ) ?
                ref $passed_ref : 
                'TERMINATOR' ;
    ### <where> - returning: $response
    return $response;
}
    

sub _secondary_ref_match{
    my ( $self, $main_ref, $new_ref ) = @_;
    ### <where> - made it to _secondary_ref_match
    ##### <where> - the main ref is    : $main_ref
    ### <where> - the current test is: $new_ref->{branch_ref}->[-1]
    my $result = 0;
    if( exists $main_ref->{secondary_ref} ){######<------------------------------------------------------  ADD New types here
        if( $new_ref->{branch_ref}->[-1]->[0] eq 'ARRAY' and
            is_ArrayRef( $main_ref->{secondary_ref} ) and
            $#{$main_ref->{secondary_ref}} >= $new_ref->{branch_ref}->[-1]->[2] ){
            ### <where> - found an equivalent position in the secondary_ref at: $new_ref->{branch_ref}->[-1]->[2]
            $result = 1;
        }elsif( $new_ref->{branch_ref}->[-1]->[0] eq 'HASH' and
                is_HashRef( $main_ref->{secondary_ref} ) and
                exists $main_ref->{secondary_ref}->{$new_ref->{branch_ref}->[-1]->[1]} ){
            ### <where> - found an equivalent position in the secondary_ref at: $new_ref->{branch_ref}->[-1]->[2]
            $result = 1;
        }elsif( $new_ref->{branch_ref}->[-1]->[0] eq 'TERMINATOR' and
                $main_ref->{primary_ref} eq $main_ref->{secondary_ref} ){
            ### <where> - found an equivalent position in the secondary_ref at: $new_ref->{branch_ref}->[-1]->[2]
            $result = 1;
        }else{
            ### <where> - No match found in the secondary_ref
        }
    }else{
        ### <where> - No secondary_ref exists
    }
    return $result;
}

sub BUILD{
    my ( $self, $args ) = @_;
    ###  <where> - Reached BUILD - (to check for 'before_method' or 'after_method')
    ###  <where> - passed: $args
    my  $meta = $self->meta;
    my  $new_object;
    ##### <where> - Old meta object   : $meta
    if( !$meta->has_method( 'before_method' ) and !$meta->has_method( 'after_method' ) ){
        carp "The composed class passed to 'new' does not have either a 'before_method' or an 'after_method' the Role 'Data::Walk::Print' will be added";
        $new_object = apply_all_roles( $self, ( 'Data::Walk::Print' ) );
    }
    ### <where> - New object        : $new_object
    ##### <where> - New meta object   : $meta
    $self->skip_END_ref( 1 );
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

This module takes a data reference (or two) and recursivly travels through it(them).  
Where the two references diverge the walker follows the primary data reference.
At the beginning and end of each node the code will attempt to call a 
L<method|/Extending Data::Walk::Extracted> using data from the current location of 
the node.

B<Beware> Recursive parsing is not a good fit for all data since very deep data 
structures will burn a fair amount of perl memory!  Meaning that as the module 
recursively parses through the levels perl leaves behind snapshots of the previous 
level that allow perl to keep track of it's location.

This is an implementation of the concept of extracted data walking from 
L<Higher-Order-Perl|http://hop.perl.plover.com/book/> Chapter 1 by 
L<Mark Jason Dominus|https://metacpan.org/author/MJD>.  I<The book is well worth the 
money!>  With that said I diverged from MJD purity in two ways. This is object oriented 
code not functional code and moreover it is written in L<Moose>. :) Second, the code uses 
methods L<that are not included|/Extending Data::Walk::Extracted> in the class, to provide 
add-on functionality at the appropriate places for action.  The MJD equivalent expects to 
use a passed CodeRef at the action points.  There is clearly some overhead associated with 
both of these differences.  I made those choices consciously and if that upsets you 
L<do not hassle MJD|/AUTHOR>!

=head2 Default Functionality

This module is does not do anything by itself but walk the data structure.
Because I want the code to do something every time I call it a new instance will 
append a default set of functionality L<Data::Walk::Print> during BUILD using 
'apply_all_roles' from L<Moose::Util>.  See L</Extending Data::Walk::Extracted> for 
more details of extending this data walker.

L<Data::Walk::Print> will print a perlish version of the primary data stucture as 
it walks through.  If a second data set is provided and the correct flag is set it 
will add a comment string with matching information.  Both L<Data::Dumper> Dump and 
L<YAML> Dump functions are more mature than the default Data::Walk::Print function 
included here.

=head2 v0.05

=over

=item B<State> This code is still in Beta state and therefore the API is subject to change.  
I like the basics and will try to add rather than modify whenever possible in the future.  
The goal of future development will be focused on supporting additional branch types.  API 
changes will only occur if the current functionality proves excessivly flawed in some fasion.  
All fixed functionality will be defined by the test suit.

=item B<Included> ArrayRefs and HashRefs are supported data walker nodes.  Strings and Numbers 
are all currently treated as base states.

=item B<Excluded> Objects and CodeRefs are not currently handled.  The should cause the code 
to croak if the module encounters them (not tested).  See L</TODO>

=back

=head1 Extending Data::Walk::Extracted

All action taken during the data walking must be initiated by implementation of two possible 
methods. The B<before_method> and the B<after_method>.  The methods are not provided by the 
base L<Data::Walk::Extracted> class.  They can be added with a 
L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> or by L<extending the 
class|https://metacpan.org/module/Moose::Manual::Classes>.  

=over

=item B<How to add methods using a Role?>

One way to incorporate a role into this class and then use it is the method 'with_traits' 
from L<Moose::Util>. B<Warning> When the Data::Walk::Extracted class is used to create a new 
instance it will check (using L<Moose|https://metacpan.org/module/Moose::Manual::Construction> 
BUILD) if the instance can( 'before_method' ) or can( 'after_method' ).  If neither method is 
available the  L<Default Role|Data::Walk::Print> will be added to the instance using L<Moose::Util> 
'apply_all_roles' and then 'carp' a warning.

=item B<what are the minimum requriements for use?>

The role must provide one of either a B<before_method> or an B<after_method>.

=item B<How does the class interact with these methods?>

At each node the  class calls $passed_ref = $self->before_method( $passed_ref ) before 
parsing the node and $passed_ref = $self->after_method( $passed_ref ) after parsing the 
node when available.  Both methods can either return a (possibly modified) $passed_ref 
or undef.  If either method returns undef, then undef is immediatly passed back up to 
the previous layer.  I<So if the before_method returns undef the data walker also skips 
parsing the node or attempting the 'after_method'.>

=item B<what does the $passed_ref contain?>

Every time the extracted walker calls a method it will pass a master data ref specific 
to that layer.  L<See below|/Third> for more details.

=back

=head1 Attributes

Data passed to ->new when creating an instance.  For modification of these attributes 
see L</Methods>.  The ->new function will either accept fat comma lists or a complete 
hash ref that has the possible appenders as the top keys.

=head3 sort_HASH 

=over

=item B<Definition:> This attribute is set to L<sort|http://perldoc.perl.org/functions/sort.html> 
(or not) Hash Ref keys prior to walking the Hash Ref node.

=item B<Default> 0 (No sort)

=item B<Range> Boolean values. See L</TODO> for future direction.
    
=back

=head3 sort_ARRAY

=over

=item B<Definition:> This attribute is set to L<sort|http://perldoc.perl.org/functions/sort.html> 
(or not) Array values prior to walking the Array Ref node.  B<Warning> this will permanantly sort 
the actual data in the passed ref permanently.  If a secondary ref also exists it will be sorted 
as well!

=item B<Default> 0 (No sort)

=item B<Range> Boolean values. See L</TODO> for future direction.

=back

=head3 skip_HASH_ref

=over

=item B<Definition:> This attribute is set to skip (or not) the processing of HASH Ref nodes.

=item B<Default> 0 (Don't skip)

=item B<Range> Boolean values.

=back

=head3 skip_ARRAY_ref

=over

=item B<Definition:> This attribute is set to skip (or not) the processing of ARRAY Ref nodes.

=item B<Default> 0 (Don't skip)

=item B<Range> Boolean values.

=back

=head3 skip_TERMINATOR_ref

=over

=item B<Definition:> This attribute is set to skip (or not) the processing of TERMINATOR's 
of ref branches.

=item B<Default> 0 (Don't skip)

=item B<Range> Boolean values.

=back

=head1 Methods

=head2 walk_the_data( %args )

This method is used to build a data reference that will recursivly parse the target 
data reference.  Effectivly it takes the passed reference(s) and walks vertically down 
each data branch.  At each node it calls a 'before_method' and an 'after_method' if 
available.  The detailed sequence is listed below.

=over

=item B<First> The class checks for an available 'before_method'.  If available 
$passed_ref = $self->before_method( $passed_ref ) is called.  If the new $passed_ref 
contains the key $passed_ref->{bounce} or is undef the program deletes the key 'bounce' 
from the $passed_ref (as needed) and then returns $passed_ref back up the tree.  I<Do 
not pass 'Go' do not collect $200.>  Otherwise $passed_ref is sent on to the node parser.  
If the $passed_ref is modified by the 'before_method' then the node parser will parse 
the new ref and not the old one. 

=item B<Second> It determines what reference type the node is at the current level.  
Strings and Numbers are considered 'TERMINATOR' types and are handled as single element 
nodes.  Then, any listing available for elements of that node is created and if the list 
L<should be sorted|/sort_HASH> then the list is sorted. If the current node is 
'undef' this is considered a 'base state' and the code skips to the L</Fifth> step.

=item B<Third - building the $passed_ref> For each element of the node a new dataset is built.  
The dataset consists of a L</primary_ref>, a L</secondary_ref> and a L</branch_ref>.  The primary_ref 
contains only the portion of the dataset that exists below the selected element of that node.  
The secondary_ref is only constructed if it has a matching element at that node with the 
primary_ref.  Node matching for hashrefs is done by string compares of the key only.  Node 
matching for arrayrefs is done by testing if the secondary_ref has the same array position 
available as the primary_ref.  I<No position content compare is done!>   The secondary_ref 
would then be built like the primary_ref.  The branch_ref will contain an array ref of array 
refs.  Each of the top array positions represents a previously traveled node on the current 
branch.  The lower array ref will have four positions which describe the the element taken 
for that branch.  The values in each position are; 0-ref type, 1-hash key name or '', 
2-element sequence position (from 0), and 3-level of the node (from 1).  The branch_ref 
arrays are effectivly the linear (vertical) breadcrumbs that show how the parser got to that 
point.  Past completed branches and future pending branches are not shown.  The new dataset 
is then passed to the recursive (private) subroutine to be parsed in the same manner 
(I<L</First>>).

=item B<Fourth> When the values are returned from the recursion call the returned value(s) 
is(are) used to replace the pased primary_ref and secondary_ref values in the current 
$passed_ref.

=item B<Fifth> - $passed_ref = $self->after_method( $passed_ref ) is called on the instance
if available.  

=item B<Seventh> the $passed_ref is passed back up to the next level.  (with changes)

=back

=head3 %args

arguments are accepted in either a hash or hashref style.

=head4 primary_ref

=over

=item B<accepts> a multilevel dataref - B<Mandatory>

=item B<range> HashRefs or ArrayRefs with string or number terminators

=back

=head4 secondary_ref

=over

=item B<accepts> a multilevel dataref - B<Optional>

=item B<range> HashRefs or ArrayRefs with string or number terminators

=back

=head4 branch_ref

=over

=item B<default> []

=item B<accepts> an Array of Arrays, - B<Optional - discouraged>

I<beware of messing with this since the module uses this for traceability>

=back

=head1 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> with the '-ENV' option so setting the variable 
$ENV{Smart_Comments} will turn on smart comment reporting.  There are three levels 
of 'Smartness' called in this module '### #### #####'.  See the L<Smart::Comments> 
documentation for more information.

=item B<$Carp::Verbose>

The module uses L<Carp> to warn(carp) and die(croak) so the variable $Carp::Verbose 
can be set for more detailed debugging.  

=back

=head1 BUGS

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item Support recursion through CodeRefs

=item Support recursion through Objects

=item Allow the sort_XXX attributes to recieve a 
L<sort|http://perldoc.perl.org/functions/sort.html> subroutine

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

=item L<Smart::Comments> -ENV option set

=item L<Data::Walk::Print> - or other action object

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