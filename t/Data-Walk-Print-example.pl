#!perl
use YAML::Any;
use Moose::Util qw( with_traits );
use lib '../lib';
use Data::Walk::Extracted 0.020;
use Data::Walk::Print 0.020;

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
                    BottomKey2:
                    - bavalue1
                    - bavalue3
                    BottomKey1: 12354'
);
my $AT_ST = with_traits( 
		'Data::Walk::Extracted', 
		( 'Data::Walk::Print' ),
	)->new(
		match_highlighting => 1,#This is the default
    );
$AT_ST->print_data(
    print_ref	=>  $firstref,
    match_ref	=>  $secondref, 
	sorted_nodes =>{
		HASH => 1, #To force order for demo purposes
	}
);