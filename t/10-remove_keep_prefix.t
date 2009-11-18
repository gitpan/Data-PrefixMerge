#!perl -T

use strict;
use warnings;
use Test::More tests => 2;

use lib './t';
require 'testlib.pm';

use Data::PrefixMerge;

my $dm = Data::PrefixMerge->new;
for (qw(remove_keep_prefixes remove_keep_prefix)) {
    is_deeply($dm->$_({a=>1, "^a2"=>5, "^c"=>[4, "^2", {"^^c"=>2}], d=>{"^e^"=>3}}), 
                      {a=>1,   a2 =>5,   c =>[4, "^2", { "^c"=>2}], d=>{ "e^"=>3}},
	      "$_ 1");
}
