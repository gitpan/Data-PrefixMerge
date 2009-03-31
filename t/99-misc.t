#!perl -T

use strict;
use warnings;
use Test::More tests => 15;

use lib './t';
require 'testlib.pm';

use_ok('Data::PrefixMerge');

my $dm = Data::PrefixMerge->new;
$dm->config->{default_merge_mode} = 'ADD';
merge_is({a=>1, b=>[1],   c=>{a=>1}},
         {a=>2, b=>[1],   c=>{a=>2}},
         {a=>3, b=>[1,1], c=>{a=>3}}, 'default_merge_mode add', $dm);

$dm = Data::PrefixMerge->new;
$dm->config->{parse_hash_key_prefix} = 0;
merge_is({a=>1}, {'*a'=>3}, {a=>1, '*a'=>3}, 'parse_hash_key_prefix off', $dm);

merge_fail({'+a'=>1}, {a=>1}, 'left-side allows only prefix "*" 1');
merge_fail({'!a'=>1}, {a=>1}, 'left-side allows only prefix "*" 2');
merge_fail({'.a'=>1}, {a=>1}, 'left-side allows only prefix "*" 3');
merge_fail({'-a'=>1}, {a=>1}, 'left-side allows only prefix "*" 4');
merge_ok({'*a'=>1}, {a=>1}, 'left-side allows only prefix "*" 5');
$dm = Data::PrefixMerge->new;
$dm->config->{parse_hash_key_prefix} = 0;
merge_ok({'-a'=>1}, {a=>1}, 'left-side allows only prefix "*" 6', $dm);

my $h1 = {i=>1, h=>{i=>1, h=>{i=>1, j=>1}, h2=>{i=>1, j=>1}}, h2=>{i=>1}};
my $h2 = {i=>2, h=>{i=>2, h=>{i=>2}, h2=>{i=>2}}, h2=>{i=>2}};
merge_is($h1, $h2,
         {i=>2, h=>{i=>2, h=>{i=>2, j=>1}, h2=>{i=>2, j=>1}}, h2=>{i=>2}}, "wanted_path 1");
$dm = Data::PrefixMerge->new;
$dm->config->{wanted_path} = ["h", "h2"];
merge_is($h1, $h2,
         {i=>2, h=>{i=>2, h=>undef, h2=>{i=>2, j=>1}}, h2=>undef}, "wanted_path 2", $dm);

is_deeply(prefix_merge({a=>1, b=>1}, {b=>2})->{backup}, {b=>1}, 'backup 1a');
is_deeply(prefix_merge({a=>1, b=>1}, {b=>2}, {recurse_hash=>0})->{backup}, undef, 'backup 1b');
is_deeply(prefix_merge([5, 6, 7], [8, 9])->{backup}, undef, 'backup 2a');
is_deeply(prefix_merge([5, 6, 7], [8, 9], {recurse_array=>1})->{backup}, [5, 6], 'backup 2b');
