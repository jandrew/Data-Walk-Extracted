#! C:/Perl/bin/perl
use Modern::Perl;
use YAML::Any;
use Moose::Util qw( with_traits );
use lib '../lib';

$| = 1;

use Data::Walk::Extracted v0.05;
use Data::Walk::Prune v0.01;

my  $newclass = with_traits( 'Data::Walk::Extracted', ( 'Data::Walk::Prune' ) );
my  $edward_scissorhands = $newclass->new( splice_arrays => 1, );#Default
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