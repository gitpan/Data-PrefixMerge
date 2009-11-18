#!perl -T

use strict;
use warnings;
use Test::More tests => 6;

use lib './t';
require 'testlib.pm';

use Data::PrefixMerge;

merge_is({h=>{a=>1}}, {"h"=>{"!a"=>undef}}, {h=>{}}, 'hash 1a');
merge_is({h=>{a=>1}}, {"!h"=>{!a=>undef}}, {}, 'hash 1b');
merge_fail({h=>{}}, {"-h"=>1}, 'hash 2');
merge_fail({h=>1}, {"-h"=>{}}, 'hash 3');
merge_fail({h=>{}}, {"-h"=>[]}, 'hash 4');
merge_fail({h=>[]}, {"-h"=>{}}, 'hash 5');
