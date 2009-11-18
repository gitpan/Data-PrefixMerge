#!perl -T

use strict;
use warnings;
use Test::More tests => 2;

use lib './t';
require 'testlib.pm';

use Data::PrefixMerge;

my $dm = Data::PrefixMerge->new;
for (qw(remove_keep_prefixes remove_keep_prefix)) {
    is_deeply($dm->$_({a=>1, "^a2"=>1, "^c"=>[1, "^2", {"^^c"=>1}]}), 
                      {a=>1,   a2 =>1,   c =>[1, "^2", { "^c"=>1}]},
	      "$_ 1");
}
