
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "An extracted dataref walker\r",
  "AUTHOR" => "Jed Lund <jandrew\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Capture::Tiny" => "0.12",
    "Modern::Perl" => 0,
    "Moose::Util" => 0,
    "MooseX::ShortCut::BuildInstance" => "0.005",
    "Test::Moose" => 0,
    "Test::Most" => 0,
    "YAML::Any" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Data-Walk-Extracted",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Data::Walk::Extracted",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Inspector" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "MooseX::StrictConstructor" => 0,
    "MooseX::Types" => 0,
    "MooseX::Types::Moose" => 0,
    "Scalar::Util" => 0,
    "Smart::Comments" => 0,
    "version" => 0
  },
  "VERSION" => "v0.019_005",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



