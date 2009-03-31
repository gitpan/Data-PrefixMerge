use inc::Module::Install;

name     'Data-PrefixMerge';
all_from 'lib/Data/PrefixMerge.pm';
author   'Steven Haryanto <steven@masterweb.net>';
license  'perl';

build_requires 'Test::More';

requires 'Moose';
requires 'Data::Compare';

auto_install;

WriteAll;
