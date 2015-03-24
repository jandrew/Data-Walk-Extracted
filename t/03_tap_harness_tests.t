#!perl
#~ use Smart::Comments '###';
my	$dir 	= './';
my	$up		= '../';
for my $next ( <*> ){
	if( ($next eq 't') and -d $next ){
		### <where> - found the t directory - must be using prove ...
		$dir	= './t/';
		$up		= '';
		last;
	}
}
### <where> - dir is: $dir
### <where> - up is: $up
		
my	$args ={
		#~ verbosity => 1,
		lib =>[
			$up . 'lib',
		],
	};
### <where> - args: $args
my	@tests =(
		[  $dir . 'Data/walk/print.t', 	'print_test' ],
		[  $dir . 'Data/walk/prune.t', 	'prune_test' ],
		[  $dir . 'Data/walk/clone.t', 	'clone_test' ],
		[  $dir . 'Data/walk/graft.t', 	'graft_test' ],
	);
use	TAP::Harness;
my	$harness = TAP::Harness->new( $args );
	$harness->runtests(@tests);
use Test::More;
pass( "Finished the TAP Harness tests" );
done_testing();