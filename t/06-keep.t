#!perl -T

use strict;
use warnings;
use Test::More tests => 3;

use lib './t';
require 'testlib.pm';

use_ok('Data::PrefixMerge');

merge_is({'*a'=>1, '*b'=>2,     '*c'=>3, '*c2'=>3, '*d'=>4, '*e'=>5, f=>6},
         {  a =>9, '!b'=>undef, '+c'=>9, '.c2'=>9, '-d'=>9, '*e'=>9, f=>9},
         {  a =>1,   b =>2,       c =>3,   c2 =>3,   d =>4,   e =>5, f=>9}, 'hash 1');

merge_is({"*a"=>1}, {a=>2, "+a"=>3, ".a"=>4, "-a"=>5, "!a"=>6}, {a=>1}, 'protect multiple');
