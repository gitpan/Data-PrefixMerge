
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Data-PrefixMerge',
  NAME      => 'Data::PrefixMerge',
  AUTHOR    => "Steven\ Haryanto\ \<stevenharyanto\@gmail\.com\>",
  ABSTRACT  => "Merge\ two\ nested\ data\ structures\,\ with\ merging\ mode\ prefix\ on\ hash\ keys",
  VERSION   => '0.10',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Test::More" => '0',
    "Data::Compare" => '0',
    "Moose" => '0',
  },
  test => {TESTS => 't/*.t'}
);

