#!perl
use Modern::Perl;
use Moose::Util qw( with_traits );
use lib '../lib';
use	Data::Walk::Extracted v0.015;
use Data::Walk::Clone v0.005;

my  $dr_nisar_ahmad_wani = with_traits( 
		'Data::Walk::Extracted', 
		( 'Data::Walk::Clone',  ) 
	)->new( 
		skip_clone_tests =>[  [ 'HASH', 'LowerKey2', 'ALL',   'ALL' ] ],
	);
my  $donor_ref = {
	Someotherkey    => 'value',
	Parsing         =>{
		HashRef =>{
			LOGGER =>{
				run => 'INFO',
			},
		},
	},
	Helping =>[
		'Somelevel',
		{
			MyKey =>{
				MiddleKey =>{
					LowerKey1 => 'lvalue1',
					LowerKey2 => {
						BottomKey1 => 'bvalue1',
						BottomKey2 => 'bvalue2',
					},
				},
			},
		},
	],
};
my	$injaz_ref = $dr_nisar_ahmad_wani->deep_clone(
		donor_ref => $donor_ref,
	);
if(
	$injaz_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2} eq
	$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey}->{LowerKey2}		){
	print "The data is not cloned at the skip point\n";
}
	
if( 
	$injaz_ref->{Helping}->[1]->{MyKey}->{MiddleKey} ne
	$donor_ref->{Helping}->[1]->{MyKey}->{MiddleKey}		){
	print "The data is cloned above the skip point\n";
}