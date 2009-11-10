#!perl -T

use Test::More tests => 2;

BEGIN {
	use_ok( 'Data::PrefixMerge' );
	use_ok( 'Data::PrefixMerge::Config' );
}

diag( "Testing Data::PrefixMerge $Data::PrefixMerge::VERSION, Perl $], $^X" );
