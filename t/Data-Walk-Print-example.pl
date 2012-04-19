#! C:/Perl/bin/perl
use Modern::Perl;
use YAML::Any;
use Moose::Util qw( with_traits );
use lib '../lib';
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