#!perl -T

use strict;
use warnings;
use Test::More tests => 25;

use lib './t';
require 'testlib.pm';

use_ok('Data::PrefixMerge');

# procedural interface
my $res = prefix_merge(1, 2);
ok($res && $res->{success} && $res->{result} == 2, 'procedural');

merge_is(1, 2, 2, 'scalar 1');
merge_is(1, undef, undef, 'scalar 2');
merge_is(undef, 2, 2, 'scalar 3');

merge_is([1], [2,3], [2,3], 'array 1');
merge_is([1], undef, undef, 'array 2');
merge_is([1], 2, 2, 'array 3');
merge_is(1, [2,3], [2,3], 'array 4');
merge_is(undef, [2], [2], 'array 5');
merge_is([{a=>1}], [{b=>2}], [{b=>2}], 'array 6');

my $dm = Data::PrefixMerge->new;
$dm->config->{recurse_array} = 1;
merge_is([{a=>1}], [{b=>2}], [{a=>1, b=>2}], 'recursive array 1', $dm);

merge_is({a=>11, b=>12}, {b=>22, c=>23}, {a=>11, b=>22, c=>23}, 'hash 1a');
merge_is({a=>11, b=>12}, {'*b'=>22, '*c'=>23}, {a=>11, b=>22, c=>23}, 'hash 1b');
merge_is({a=>1}, undef, undef, 'hash 2');
merge_is(undef, {a=>1}, {a=>1}, 'hash 3');
merge_is({a=>1}, [], [], 'hash 4');
merge_is([], {a=>1}, {a=>1}, 'hash 5');
merge_is({a=>1}, 1, 1, 'hash 6');
merge_is(1, {a=>1}, {a=>1}, 'hash 7');

$dm = Data::PrefixMerge->new;
$dm->config->{recurse_hash} = 0;
merge_is({a=>11, b=>12}, {b=>22, c=>23}, {b=>22, c=>23}, 'recurse hash 1', $dm);

merge_is({i=>1, h=>{i=>1, j=>1}, j=>2},
         {i=>2, h=>{j=>2, k=>3}, k=>3},
         {i=>2, h=>{i=>1, j=>2, k=>3}, j=>2, k=>3}, 'recurse hash 2');
merge_is({h=>{h=>{i=>1, j=>1}}},
         {h=>{h=>{j=>2, k=>3}}},
         {h=>{h=>{i=>1, j=>2, k=>3}}}, 'recurse hash 3');

# order of merge if multiple oprations are specified
merge_is({a=>3}, {"-a"=>7, "+a"=>12}, {a=>8}, 'order: - before + 1');
merge_is({a=>[1,2,3]}, {"-a"=>[1], "+a"=>[1]}, {a=>[2,3,1]}, 'order: - before + 2');
