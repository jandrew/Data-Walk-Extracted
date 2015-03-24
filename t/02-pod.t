#! C:/Perl/bin/perl
use Test::More;
eval "use Test::Pod 1.48";
if( $@ ){
	plan skip_all => "Test::Pod 1.48 required for testing POD";
}else{
	plan tests => 7;
}
my	$up		= '../';
for my $next ( <*> ){
	if( ($next eq 't') and -d $next ){
		### <where> - found the t directory - must be using prove ...
		$up	= '';
		last;
	}
}
pod_file_ok( $up . 'README.pod', "The README file has good POD" );
pod_file_ok( $up . 'lib/Data/Walk/Extracted/Types.pm', "Data::Walk::Extracted::Types file has good POD" );
pod_file_ok( $up . 'lib/Data/Walk/Extracted/Dispatch.pm', "Data::Walk::Extracted::Dispatch file has good POD" );
pod_file_ok( $up . 'lib/Data/Walk/Print.pm', "Data::Walk::Print file has good POD" );
pod_file_ok( $up . 'lib/Data/Walk/Prune.pm', "Data::Walk::Prune file has good POD" );
pod_file_ok( $up . 'lib/Data/Walk/Clone.pm', "Data::Walk::Clone file has good POD" );
pod_file_ok( $up . 'lib/Data/Walk/Graft.pm', "Data::Walk::Graft file has good POD" );
done_testing();