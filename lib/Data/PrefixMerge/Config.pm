package Data::PrefixMerge::Config;
our $VERSION = '0.10';


# ABSTRACT: Data::PrefixMerge configuration


use Moose;


has recurse_hash => (is => 'rw', default => 1);


has recurse_array => (is => 'rw', default => 0);


has parse_hash_key_prefix => (is => 'rw', default => 1);


has wanted_path => (is => 'rw');


has default_merge_mode => (is => 'rw', default => 'NORMAL');


has preserve_keep_prefix => (is => 'rw', default => 0);

# unimplemented
#parse_hash_option_key => 1, # XXX or event
#clone => 0,

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::PrefixMerge::Config - Data::PrefixMerge configuration

=head1 VERSION

version 0.10

=head1 SYNOPSIS

    # getting configuration
    if ($merger->config->allow_extra_hash_keys) { ... }

    # setting configuration
    $merger->config->max_warnings(100);

=head1 DESCRIPTION

Configuration variables for Data::PrefixMerge.

=head1 ATTRIBUTES

=head2 recurse_hash => BOOL

Whether to recursively merge hash. Default is 1.

With recurse_hash set to 1, hashes will be recursively merged:

 prefix_merge({h=>{a=>1}}, {h=>{b=>1}}); # {h=>{a=>1, b=>1}}

With recurse_hash set to 0, hashes on the left side will just be
replaced with hashes on the right side:

 prefix_merge({h=>{a=>1}}, {h=>{b=>1}}); # {h=>{b=>1}}

=head2 recurse_array => BOOL

Whether to recursively merge hash. Default is 0.

With recurse_array set to 1, arrays will be recursively merged:

 prefix_merge([1, 1], [2]); # [2, 1]

With recurse_array set to 0, array on the left side will just be
replaced with array on the right side:

 prefix_merge([1, 1], [2]); # [2]

=head2 parse_hash_key_prefix => BOOL

Whether to parse merge prefix for in hash keys. Default is 1. If you
set this to 0, merging behaviour is similar to most other nested merge
modules.

With parse_hash_key_prefix set to 1:

 prefix_merge({a=>1}, {"+a"=>2}); # {a=>3}

With parse_hash_key_prefix set to 0:

 prefix_merge({a=>1}, {"+a"=>2}); # {a=>1, "+a"=>2}

=head2 wanted_path => ARRAYREF

Default is undef. If you set this, merging is only done to the
specified "branch". Useful to save time/storage when merging large
hash "trees" while you only want a certain branch of the trees
(e.g. resolving just a config variable from several config hashes).

Example:

 prefix_merge(
   {
    user => {
      steven => { quota => 100, admin => 1 },
      tommie => { quota =>  50, admin => 0 },
      jimmy  => { quota => 150, admin => 0 },
    },
    groups => [qw/admin staff/],
   },
   {
    user => {
      steven => { quota => 1000 },
    }
   }
 );

With wanted_path unset, the result would be:

   {
    user => {
      steven => { quota => 1000, admin => 1 },
      tommie => { quota =>   50, admin => 0 },
      jimmy  => { quota =>  150, admin => 0 },
    }
    groups => [qw/admin staff/],
   }

With wanted_path set to ["user", "steven", "quota"] (in other words,
you're saying that you'll be disregarding other branches), the result
would be:

   {
    user => {
      steven => { quota => 1000, admin => undef },
      tommie => undef,
      jimmy  => undef,
    }
    groups => undef,
   }

=head2 default_merge_mode => 'NORMAL' | 'ADD' | 'CONCAT' | 'SUBTRACT' | 'DELETE' | 'KEEP'

Default is 'NORMAL'.

Example:

When setting default_merge_mode to NORMAL (DEFAULT):

 prefix_merge(3, 4); # 4

When setting default_merge_mode to ADD:

 prefix_merge(3, 4); # 7

=head2 preserve_keep_prefix => 0|1

Default it 0.

If set to 1, then key KEEP merge prefixes on hash keys (^) will be
preserved. This is useful if we want to do another merge on the
result.

Example:

 prefix_merge({'^a'=>1}, {a=>2}); # {a=>1}
 prefix_merge({'a'=>1}, {a=>2}, {preserve_keep_prefix=>1}); # {'^a'=>1}
 prefix_merge({'a'=>1}, {'^a'=>2}, {preserve_keep_prefix=>1}); # {'^a'=>1}

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

