#! C:/Perl/bin/perl
### Test that the pod files run
use Test::More;
use lib '../lib', 'lib';
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();