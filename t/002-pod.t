#! C:/Perl/bin/perl
### Test that the pod files run
use Test::Most;
use lib '../lib', 'lib';
eval "use Test::Pod 1.48";
plan skip_all => "Test::Pod 1.48 required for testing POD" if $@;
all_pod_files_ok();
explain "...Test Done";
done_testing();