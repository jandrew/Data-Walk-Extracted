package Data::Walk::Extracted;

use Moose;
use MooseX::StrictConstructor;
use version; our $VERSION = qv('0.007_005');
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

my $walk_the_data_keys = {
    primary_ref     => 1,#Required
    secondary_ref   => 0,#Optional
    before_method   => 2,#One or the other of two required
    after_method    => 2,#One or the other of two required
    branch_ref      => 0,#Don't generally use
};

#Add type here and then Search on ARRAY or HASH and is_ArrayRef 
# or is_HashRef to find locations to update
my $supported_types = {######<------------------------------------------------------  ADD New types here
    'HASH'			=> 'is_HashRef',
    'ARRAY'         => 'is_ArrayRef',
    'TERMINATOR'	=> 'is_Str',
    'END'           	=> 1,
};

###############  Public Attributes  ####################################

for my $type ( keys %$supported_types ){
    my $sort_attribute = 'sort_' . $type;
    has $sort_attribute =>(
        is			=> 'ro',
        isa    	=> Bool,#TODO Add other sort type support
        default 	=> 0,
    );
    my $skip_attribute = 'skip_' . $type . '_ref';
    has $skip_attribute =>(
        is      	=> 'rw',
        isa     	=> Bool,
        default 	=> 0,
    );
}

has 'change_array_size' =>(
    is      	=> 'ro',
    isa     	=> Bool,
    writer  	=> 'change_array_size_behavior',
    default 	=> 1,
);

###############  Public Methods  #######################################

###############  Private Attributes  ###################################

has '_had_secondary' =>(
    is      => 'ro',
    isa     => Bool,
    writer  => '_has_secondary',
    default => 0,
);

###############  Private Methods / Modifiers  ##########################

sub _process_the_data{#Used to scrub high level input
    ### <where> - Made it to walk_the_data
    ##### <where> - Passed input  : @_
    my ( $self, $passed_ref, $conversion_ref ) =@_;
    ##### <where> - Passed hashref: $passed_ref
    ##### <where> - Passed hashref: $passed_ref
    ### <where> - review the ref keys for requirements and conversion
    $passed_ref = $self->_has_required_inputs( $passed_ref, $conversion_ref );
    $self->_has_secondary( exists $passed_ref->{secondary_ref} );
    ##### <where> - Start recursive passing with  : $passed_ref
    $passed_ref = $self->_walk_the_data( $passed_ref );
    delete $passed_ref->{branch_ref};
    ### <where> - convert the data keys back to the Role names
    for my $old_key ( keys %$conversion_ref ){
        if( exists $passed_ref->{$old_key} ){
            $passed_ref->{$conversion_ref->{$old_key}} = $passed_ref->{$old_key};
            delete $passed_ref->{$old_key};
        }
    }
    ### <where> - End recursive passing with    : $passed_ref
    return $passed_ref;
}

sub _walk_the_data{
    my( $self, $passed_ref ) = @_;
    ### <where> - Made it to _walk_the_data
    ##### <where> - Passed input  : $passed_ref
    
    if( exists $passed_ref->{before_method} ){
        my  $before_method = $passed_ref->{before_method};
        ### <where> - role has a before_method: $before_method
        $passed_ref = $self->$before_method( $passed_ref );
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
    
    if( exists $passed_ref->{after_method} ){
        my $after_method = $passed_ref->{after_method};
        ### <where> - role has an after_method: $after_method
        $passed_ref = $self->$after_method( $passed_ref );
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
        my  $branch_item = ( $item eq '' ) ? undef : $item;
        ### <where> - Processing position   : $x
        ### <where> - Processing item       : $item
        $new_passed_ref->{primary_ref} =######<------------------------------------------------------  ADD New types here
            ( $ref_type eq 'ARRAY' ) ?
                $list_ref->[$x] :
            ( $ref_type eq 'HASH' ) ?
                $passed_ref->{primary_ref}->{$item} : undef ;
        push @{$new_passed_ref->{branch_ref}}, [ 
            $ref_type, 
            $branch_item, 
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
        if( exists $passed_ref->{before_method} ){
            $new_passed_ref->{before_method} = $passed_ref->{before_method};
        }
        if( exists $passed_ref->{after_method} ){
            $new_passed_ref->{after_method} = $passed_ref->{after_method};
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
    my ( $self, $passed_ref, $lookup_ref ) = @_;
    ### <where> - Made it to _has_required_inputs
    ##### <where> - Passed ref    : $passed_ref
    my $fail_ref;
    my $pass_ref;
    for my $key ( keys %$walk_the_data_keys ){
        if( $walk_the_data_keys->{$key} ){
            ### <where> - Found a possibly required value for: $key
            if( (   exists $lookup_ref->{$key} and 
                    exists $passed_ref->{$lookup_ref->{$key}} ) or
                ( !( exists $lookup_ref->{$key} ) and 
                    exists $passed_ref->{$key}          )           ){
                $pass_ref->{$walk_the_data_keys->{$key}} = 1;
                delete $fail_ref->{$walk_the_data_keys->{$key}};
            }elsif( !( exists $pass_ref->{$walk_the_data_keys->{$key}} ) ){
                push @{$fail_ref->{$walk_the_data_keys->{$key}}}, 
                    ( (exists $lookup_ref->{$key}) ?
                        $lookup_ref->{$key} : $key );
            }
        }
    }
    my @message;
	#### $fail_ref
	### $lookup_ref
	### $passed_ref
    for my $item ( keys %$fail_ref ){
		### $item
        my $list = join '- or -', @{$fail_ref->{$item}};
		### $list
        if( @{$fail_ref->{$item}} == 1 ){
            push @message, "The key -$list- is required and must have a value";
        }else{
            push @message, "One or more of the keys -$list- must be passed with a value";
        }
    }
	### @message
    croak (join "\n", @message) if @message;
    ### <where> - Made it to _test_inputs
    my %ref_lookup = reverse %$lookup_ref;
    for my $key ( keys %$passed_ref ){
        ### <where> - Testing key: $key
        if( exists $walk_the_data_keys->{$key} ){
            ### <where> - Acceptable passed key: $key
        }elsif( $ref_lookup{$key} and
                exists $walk_the_data_keys->{$ref_lookup{$key}} ){
            ### <where> - Need to modify the key to: $ref_lookup{$key}
            $passed_ref->{$ref_lookup{$key}} = $passed_ref->{$key};
            delete $passed_ref->{$key};
        }else{
            croak "The passed key -$key- is not supported by " . __PACKAGE__;
        }
    }
    return $passed_ref;
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
        print_ref     =>  $firstref,
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
code not functional code and moreover it is written in L<Moose>. :) Second, like the MJD 
equivalent, the code does L<nothing on its own|/Extending Data::Walk::Extracted>.   
Unlike the MJD equivalent it looks for methods provided in a role or class extention at the 
appropriate places for action.  The MJD equivalent expects to use a passed CodeRef at 
the action points.  There is clearly some overhead associated with both of these differences.  
I made those choices consciously and if that upsets you L<do not hassle MJD|/AUTHOR>!

=head2 Default Functionality

This module does not do anything by itself but walk the data structure.  I<It takes no 
action on its own during the walk.>  All the output L<above|/SYNOPSIS> is from 
L<Data::Walk::Print>

=head2 Basic interface

The module uses five basic pieces of data to work;

=over

=item B<primary_ref> - a dataref that the walker will walk

=item B<secondary_ref> - a dataref that is used for comparision while walking

=item B<before_method> - some action performed at the beginning of each node

=item B<after_method> - some action performed at the beginning of each node

=item B<conversion_ref> - a way to change the data ref naming used in the role to the name used 
in the base class.  This allows the data to be named in a way unique to the role 
so that any bad callout can be caught but still be used generically by the 
base class.

=back

=head3 An example

    $passed_ref ={
        print_ref =>{ 
            First_key => 'first_value',
        },
        match_ref =>{
            First_key => 'second_value',
        },
        before_method => '_print_before_method',
        after_method  => '_print_after_method',
    }

    $conversion_ref =>{
        primary_ref   => 'print_ref',# generic_name => role_name,
        secondary_ref => 'match_ref',
    }

The minimum acceptable list of passed arguments are: 'primary_ref' and either of 
'before_method' or 'after_method'.  The list can also contain 'secondary_ref' and 
'branch_ref' but they are not required.  When nameing the before_method and after_method for 
the role keep in mind possible namespace collisions with other role methods.  The input 
scrubber will use the $conversion_ref to test the $passed_ref for the correct $key names.  
If the key names are passed differently from the role then the scrubber will change the keys 
prior to sending the $passed_ref to the data walker.  Any errors will be 'croak'ed using the 
passed names not the data walker names. 

After the data scrubbing the $passed_ref is sent to the data walker.

=head2 v0.007

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

=item B<How to add Roles to the Class?>

One way to incorporate a role into this class and then use it is the method 'with_traits' 
from L<Moose::Util>.

=item B<What is the reccomended way to build a role that uses this class?>

First start by creating the 'action' method for the role.  This would preferably be named 
something descriptive like 'mangle_data'.  This method should build a $passed_ref and 
possibly a $conversion_ref.  The L<$passed_ref|/An Example> can include up to two data 
references, a call to either a 'before_method' or an 'after_method' or both, and possibly 
a 'branch_ref'.  The L</$conversion_ref> should contain key / value pairs that repsesent the 
translation of the $passed_ref keys used in the Role to the names used by this class.  This 
allows for generic handling of walking but still allowing multiple roles to coexist in the 
class when built.  These two values are used as follows

	$result = $self->_process_the_data( $passed_ref, $conversion_ref );

Then build one or both of B<before_method> and B<after_method> for use when walking the 
data.  For examples review the code in L<Data::Walk::Print>

L<Write some tests for your role!|http://www.perlmonks.org/?node_id=918837>

=item B<what is the recursive data walking sequence?>

=over

=item B<First> The class checks for an available 'before_method'.  Using the test 
exists $passed_ref->{before_method}.  If the test passes then the sequence  
$method = $passed_ref->{before_method}; $passed_ref = $self->$method( $passed_ref ); is 
run.  If the new $passed_ref contains the key $passed_ref->{bounce} or is undef the 
program deletes the key 'bounce' from the $passed_ref (as needed) and then returns 
$passed_ref directly back up the data tree.  I<Do not pass 'Go' do not collect $200.>  
Otherwise $passed_ref is sent on to the node parser.  If the $passed_ref is modified 
by the 'before_method' then the node parser will parse the new ref and not the old one. 

=item B<Second> It determines what reference type the node is at the current level.  
Strings and Numbers are considered 'TERMINATOR' types and are handled as single element 
nodes.  Then, any listing available for elements of that node is created and if the list 
L<should be sorted|/sort_HASH> then the list is sorted. If the current node is 
'undef' this is considered a 'base state' and the code skips to the L</Fifth> step.

=item B<Third> - building the $passed_ref For each element of the node a new dataset is built.  
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

=item B<Fifth> - The class checks for an available 'after_method'.  Using the test 
exists $passed_ref->{after_method}.  If the test passes then the sequence  
$method = $passed_ref->{after_method}; $passed_ref = $self->$method( $passed_ref ); is 
run.

=item B<Sixth> the $passed_ref is passed back up to the next level.  (with changes)

=back

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

=head3 change_array_size

=over

=item B<Definition:> This attribute will not be used by this class directly.  However 
the L<Data::Walk::Prune> Role and the L<Data::Walk::Graft> Role both use it so it is 
placed here so there will be no conflicts.

=item B<Default> 1 (This usually means that the array position will be added or removed)

=item B<Range> Boolean values.

=back

=head1 Methods

=head2 change_array_size_behavior( $bool )

=over

=item B<Definition:> This method is used to change the L</change_array_size> attribute 
after the instance is created.  This attribute is not used by this class!  
However, it is provided so multiple Roles can share behavior rather each handling this 
attribute differently.  See L<Data::Walk::Prune> and L<Data::Walk::Graft> for 
specific effects of this attribute.

=item B<Accepts:> a Boolean value

=item B<Returns:> ''

=back

=head1 GLOBAL VARIABLES

=over

=item B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments> with the '-ENV' option so setting the variable 
$ENV{Smart_Comments} will turn on smart comment reporting.  There are three levels 
of 'Smartness' called in this module '### #### #####'.  See the L<Smart::Comments> 
documentation for more information.

=item B<$Carp::Verbose>

The module uses L<Carp> to die(croak) so the variable $Carp::Verbose 
can be set for more detailed debugging.  

=back

=head1 SUPPORT

=over

=item L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

=item Support recursion through CodeRefs

=item Support recursion through Objects

=item Allow the sort_XXX attributes to recieve a 
L<sort|http://perldoc.perl.org/functions/sort.html> subroutine

=item Add a Data::Walk::Top Role to the package

=item Add a Data::Walk::Thin Role to the package

=back

=head1 AUTHOR

=over

=item Jed

=item jandrew@cpan.org

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 Dependancies

=over

=item L<version>

=item L<Carp>

=item L<Moose>

=item L<MooseX::StrictConstructor>

=item L<MooseX::Types::Moose>

=item L<Smart::Comments> -ENV option set

=back

=head1 SEE ALSO

=over

=item L<Data::Walk>

=item L<Data::Walker>

=item L<Data::Dumper> - Dump

=item L<YAML> - Dump

=item L<Data::Walk::Print> - or other action object

=back

=cut

#################### main pod documentation end #####################