#!perl -T

use strict;
use warnings;
use Test::More tests => 6;
use Storable qw/dclone/;
use YAML;

use lib './t';
require 'testlib.pm';

use Data::PrefixMerge;

my $dm = Data::PrefixMerge->new;
for (qw(remove_keep_prefixes remove_keep_prefix)) {
    my ($inp, $out, $exp);

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
}
