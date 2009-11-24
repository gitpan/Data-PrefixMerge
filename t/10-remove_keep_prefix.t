#!perl -T

use strict;
use warnings;
use Test::More tests => 20;
use Storable qw/dclone/;
use YAML;

use lib './t';
require 'testlib.pm';

use Data::PrefixMerge;

my $dm = Data::PrefixMerge->new;
for (qw(remove_keep_prefixes remove_keep_prefix)) {
    my ($inp, $out, $exp, $exp1, $exp2, $exp3);

    $inp = {a=>1, "^a2"=>5, "^c"=>[4, "^2", {"^^c"=>2}], d=>{"^e^"=>3}};
    $exp = {a=>1,   a2 =>5,   c =>[4, "^2", { "^c"=>2}], d=>{ "e^"=>3}};
    $out = dclone($inp); $dm->$_($out);
    #print "INPUT: ", Dump($inp), "\nOUTPUT: ", Dump($out), "\nEXPECTED: ", Dump($exp);
    is_deeply($out, $exp, "$_ 1");

    $inp = { "a" => 1, "^b"=>2, "^^b2"=>20 }; $inp->{"^c"} = $inp; $inp->{"^^c2"} = $inp; $inp->{"d"} = $inp;
    $exp = { "a" => 1,  "b"=>2,  "^b2"=>20 }; $exp->{ "c"} = $exp; $exp->{ "^c2"} = $exp; $exp->{"d"} = $exp;
    $out = dclone($inp); $dm->$_($out);
    #print "INPUT: ", Dump($inp), "\nOUTPUT: ", Dump($out), "\nEXPECTED: ", Dump($exp);
    is_deeply($out, $exp, "$_ recursion 1");

    $inp = [ 1, 2, { "a"=>1, "^b"=>2, "^^b2"=>20 } ]; $inp->[3] = $inp; $inp->[4] = $inp->[2];
    $exp = [ 1, 2, { "a"=>1,  "b"=>2,  "^b2"=>20 } ]; $exp->[3] = $exp; $exp->[4] = $exp->[2];
    $out = dclone($inp); $dm->$_($out);
    #print "INPUT: ", Dump($inp), "\nOUTPUT: ", Dump($out), "\nEXPECTED: ", Dump($exp);
    is_deeply($out, $exp, "$_ recursion 2");

    $inp  = { "^h"=>{"^h2"=>{"^h3"=>{}}, "hb2"=>{"^h3"=>{}}},
	      "hb"=>{"^h2"=>{"^h3"=>{}}, "hb2"=>{"^h3"=>{}}} };
    $exp  = {  "h"=>{ "h2"=>{ "h3"=>{}}, "hb2"=>{ "h3"=>{}}},
	      "hb"=>{ "h2"=>{ "h3"=>{}}, "hb2"=>{ "h3"=>{}}} };
    $exp1 = {  "h"=>{"^h2"=>{"^h3"=>{}}, "hb2"=>{"^h3"=>{}}},
	      "hb"=>{"^h2"=>{"^h3"=>{}}, "hb2"=>{"^h3"=>{}}} };
    $exp2 = {  "h"=>{ "h2"=>{"^h3"=>{}}, "hb2"=>{"^h3"=>{}}},
	      "hb"=>{ "h2"=>{"^h3"=>{}}, "hb2"=>{"^h3"=>{}}} };
    $out = dclone($inp); $dm->$_($out);
    is_deeply($out, $exp, "$_ maxlevel -1 hash");
    $out = dclone($inp); $dm->$_($out, 1);
    is_deeply($out, $exp1, "$_ maxlevel 1 hash");
    $out = dclone($inp); $dm->$_($out, 2);
    is_deeply($out, $exp2, "$_ maxlevel 2 hash");

    $inp  = [ {"^h2"=>{"^h3"=>{}}}, [ {"^h3"=>{"^h4"=>{}}} ] ];
    $exp  = [ { "h2"=>{ "h3"=>{}}}, [ { "h3"=>{ "h4"=>{}}} ] ];
    $exp1 = [ {"^h2"=>{"^h3"=>{}}}, [ {"^h3"=>{"^h4"=>{}}} ] ];
    $exp2 = [ { "h2"=>{"^h3"=>{}}}, [ {"^h3"=>{"^h4"=>{}}} ] ];
    $exp3 = [ { "h2"=>{ "h3"=>{}}}, [ { "h3"=>{"^h4"=>{}}} ] ];
    $out = dclone($inp); $dm->$_($out);
    is_deeply($out, $exp, "$_ maxlevel -1 array");
    $out = dclone($inp); $dm->$_($out, 1);
    is_deeply($out, $exp1, "$_ maxlevel 1 array");
    $out = dclone($inp); $dm->$_($out, 2);
    is_deeply($out, $exp2, "$_ maxlevel 2 array");
    $out = dclone($inp); $dm->$_($out, 3);
    is_deeply($out, $exp3, "$_ maxlevel 3 array");

}
