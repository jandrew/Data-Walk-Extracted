
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "An extracted dataref walker\r",
  "AUTHOR" => "Jed Lund <jandrew\@cpan.org>",
  "BUILD_REQUIRES" => {},
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
    "lib" => 0,
    "version" => 0
  },
  "TEST_REQUIRES" => {
    "Capture::Tiny" => "0.12",
    "Moose::Util" => 0,
    "MooseX::ShortCut::BuildInstance" => "0.008",
    "Test::Moose" => 0,
    "Test::More" => 0,
    "Test::Most" => 0,
    "YAML::Any" => 0
  },
  "VERSION" => "0.024.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

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



