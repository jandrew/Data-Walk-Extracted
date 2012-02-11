#! C:/Perl/bin/perl
use Modern::Perl;
use YAML::Any;
use lib '../lib';
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