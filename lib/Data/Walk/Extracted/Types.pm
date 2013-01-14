package Data::Walk::Extracted::Types;
use Moose::Role;
use MooseX::Types::Moose qw(
        Int
    );
use version; our $VERSION = qv('0.001_003');
BEGIN{
	if( $ENV{ Smart_Comments } ){
		use Smart::Comments -ENV;
		### Smart-Comments turned on for Data-Walk-Types ...
	}
}

use MooseX::Types -declare => [ qw(
        posInt
    ) ];

#########1 SubType Library    3#########4#########5#########6#########7#########8#########9

subtype posInt, as Int,
    where{ $_ >= 0 },
    message{ "$_ is not a positive integer" };

#########1 private methods    3#########4#########5#########6#########7#########8#########9



#########1 Phinish strong     3#########4#########5#########6#########7#########8#########9

no Moose::Role;

1;
# The preceding line will help the module return a true value

#########1 main pod docs      3#########4#########5#########6#########7#########8#########9

__END__

=head1 NAME

Data::Walk::Extracted::Types - A type library for Data::Walk::Extracted

=head1 SYNOPSIS
    
    package Data::Walk::Extracted::MyRole;
	use Moose::Role;
	use Data::Walk::Extracted::Types qw(
		posInt
	);
    use Log::Shiras::Types qw(
        posInt #See Code for other options
    );
    
    has 'someattribute' =>(
            isa     => posInt,#Note the lack of quotes
        );
    
    sub valuetestmethod{
        my ( $self, $value ) = @_;
        return is_posInt( $value );
    }

    no Moose::Role;

    1;

=head1 DESCRIPTION

This is the custom type class that ships with the L<Log::Shiras> package.  
Wherever possible errors to coersions are passed back to the type so coersion 
failure will be explained.

There are only subtypes in this package!  B<WARNING> These types should be 
considered in a beta state.  Future type fixing will be done with a set of tests in 
the test suit of this package.  (currently none are implemented)

See L<MooseX::Types> for general re-use of this module.

=head1 TODO

=over

=item write a test suit for the types to permanently define behavior!

=back

=head1 SUPPORT

L<Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=head1 AUTHOR

=over

=item Jed Lund 

=item jandrew@cpan.com

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 DEPENDENCIES

=over

=item L<Moose::Role>

=item L<MooseX::Types>

=item L<MooseX::Types::Moose>

=item L<version>

=back

=head1 SEE ALSO

=over

=item L<MooseX::Types::Perl>

=back

=cut

#################### main pod documentation end #####################