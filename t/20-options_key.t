#!perl -T

use strict;
use warnings;
use Test::More tests => 14;

use lib './t';
require 'testlib.pm';

use Data::PrefixMerge;

my $dm;
$dm = Data::PrefixMerge->new();
$dm->config->preserve_keep_prefix(1);
$dm->config->hash_options_key('MERGE_OPTS');

merge_is({"^a"=>1, MERGE_OPTS=>{}},
         { "a"=>2},
         {"^a"=>1},
         'no option', $dm);

merge_fail({"^a"=>1, MERGE_OPTS=>undef},
           { "a"=>2},
           'options undef', $dm);

merge_fail({"^a"=>1, MERGE_OPTS=>[]},
           { "a"=>2},
           'options not hash', $dm);

merge_fail({"^a"=>1, MERGE_OPTS=>{foo=>1}},
           { "a"=>2},
           'unknown option', $dm);

for (qw(remove_keep_prefix remove_keep_prefixes)) {
    merge_is({"^a"=>1, MERGE_OPTS=>{$_=>0}},
             { "a"=>2},
             {"^a"=>1},
             "option $_=0", $dm);
    merge_is({"^a"=>1, MERGE_OPTS=>{$_=>1}},
             { "a"=>2},
             { "a"=>1},
             "option $_=1", $dm);
    merge_is({"^a"=>{"^a2"=>10}, MERGE_OPTS=>{$_=>1, remove_keep_max_depth=>1}},
             { "a"=>{ "a2"=>20}},
             { "a"=>{"^a2"=>10}},
             "option $_=1 maxdepth=1", $dm);
    merge_is({"^a"=>{ "a2"=>{"^a3"=>3}}, MERGE_OPTS=>{$_=>1, remove_keep_max_depth=>2}},
             { "a"=>{ "a2"=>{"^a3"=>4}}},
             { "a"=>{ "a2"=>{"^a3"=>3}}},
             "option $_=1 maxdepth=2", $dm);
    merge_is({"^a"=>{ "a2"=>{ "a3"=>3}}, MERGE_OPTS=>{$_=>1}},
             { "a"=>{ "a2"=>{ "a3"=>4}}},
             { "a"=>{ "a2"=>{ "a3"=>3}}},
             "option $_=1 maxdepth=-1", $dm);
}
