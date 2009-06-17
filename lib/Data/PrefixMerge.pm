package Data::PrefixMerge;

use Moose;
use vars qw(@ISA @EXPORT);
use Data::Compare;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(prefix_merge);

=head1 NAME

Data::PrefixMerge - Merge two nested data structures, with merging mode prefix on hash keys

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';


=head1 SYNOPSIS

    # OO interface

    use Data::PrefixMerge;
    my $merger = Data::PrefixMerge->new();

    my $hash1 = { a=>1,    c=>1, d=>{  da =>[1]} };
    my $hash2 = { a=>2, "-c"=>2, d=>{"+da"=>[2]} };

    my $res = $merger->merge($hash1, $hash2);
    die $res->{error} if $res->{error};
    print $res->{result}; # { a=>2, c=>-1, d => { da=>[1,2] } }


    # procedural interface

    use Data::PrefixMerge;
    my $res = prefix_merge($hash1, $hash2);
    my $hash1 = { a=>1,    c=>1, d=>{  da =>[1]} };
    my $hash2 = { a=>2, "+c"=>2, d=>{"+da"=>[2]} };
    die $res->{error} if $res->{error};
    print $res->{result}; # { a=>2, c=>-1, d => { da=>[1,2] } }

=head1 DESCRIPTION

There are already several modules on CPAN to do recursive data
structure merging. The main difference between those modules and
Data::PrefixMerge is that Data::PrefixMerge supports "merge prefixes"
in hash keys. Merge prefixes instruct how the merge should be done
(merging mode).

Merging prefixes can also be turned off via configuration (see
B<CONFIG> section), in which Data::PrefixMerge will behave like most
other merge modules.

=head1 MERGING MODES

=head2 NORMAL (optional '*' prefix on left/right side)

 prefix_merge({ a=>11, b=>12},  {b=>22, c=>23}); # {a=>11, b=>22, c=>23}
 prefix_merge({*a=>11, b=>12}, {*b=>22, c=>23}); # {a=>11, b=>22, c=>23}

=head2 ADD ('+' prefix on the right side)

 prefix_merge({i=>3}, {"+i"=>4, "+j"=>1}); # {i=>7, j=>1}
 prefix_merge({a=>[1]}, {"+a"=>[2, 3]}); # {a=>[1, 2, 3]}

Additive merge on hashes will be treated like a normal merge.

=head2 CONCAT ('.' prefix on the right side)

 prefix_merge({i=>3}, {".i"=>4, ".j"=>1}); # {i=>34, j=>1}

Concative merge on arrays will be treated like additive merge.

=head2 SUBTRACT ('-' prefix on the right side)

 prefix_merge({i=>3}, {"-i"=>4}); # {i=>-1}
 prefix_merge({a=>["a","b","c"]}, {"-a"=>["b"]}); # {a=>["a","c"]}

Subtractive merge on hashes is not defined.

=head2 DELETE ('!' prefix on the right side)

 prefix_merge({x=>WHATEVER}, {"!x"=>WHATEVER}); # {}

=head2 KEEP ('!' prefix on the left side)

If you add '!' prefix on the left side, it will be protected from
being replaced/deleted/etc.

 prefix_merge({'!x'=>WHATEVER1}, {"x"=>WHATEVER2}); # {x=>WHATEVER1}

=head2

=head1 FUNCTIONS

=head2 prefix_merge($a, $b[, $config_vars])

A non-OO wrapper for merge() method. Exported by default. See C<merge>
method for default.

=cut

sub prefix_merge {
    my ($a, $b, $config_vars) = @_;
    my $merger = __PACKAGE__->new();
    if ($config_vars) {
        for (keys %$config_vars) {
            $merger->config->{$_} = $config_vars->{$_};
        }
    }
    $merger->merge($a, $b);
}

=head1 ATTRIBUTES

=cut

=head2 config

A hashref for config. See B<CONFIG> section below.

=cut

has config => (is => "rw");
#has plugins => (is => "rw");

# merging process state
has path => (is => "rw");
has error => (is => "rw");
has result => (is => "rw");

=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    unless ($self->config) {
        $self->config({
            recurse_hash => 1,
            recurse_array => 0,
            parse_hash_key_prefix => 1,
            wanted_path => undef,
            default_merge_mode => 'NORMAL',
            preserve_prefix => 0,

            # unimplemented
            #parse_hash_option_key => 1, # XXX or event
            #clone => 0,
        });
    }
    # XXX load default plugins
}

=head2 merge($a, $b)

Merge two nested data structures. Returns the result hash: {
success=>0|1, error=>'...', result=>..., backup=>... }. The 'error'
key is set to contain an error message if there is an error. The merge
result is in the 'result' key. The 'backup' key contains replaced
elements from the original hash/array.

=cut

sub merge {
    my ($self, $a, $b) = @_;

    #print "merge()\n";

    $self->path([]);
    $self->error('');
    my ($res, $backup) = $self->_merge($a, $b, $self->config->{default_merge_mode});
    {
        success => !$self->error,
        error   => ($self->error ?
                    sprintf("/%s: %s", join("/", @{ $self->path }), $self->error) : ''),
        result  => $res,
        backup  => $backup,
    };
}

sub _merge {
    my ($self, $a, $b, $mode) = @_;
    my $config = $self->config;

    #use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Terse=1; print "_merge(".Dumper($a).", ".Dumper($b).", $mode)\n";

    # determine which merge methods we will call
    my (@meth, @ta, @tb);
    for ([$a, \@ta], [$b, \@tb]) {
        my $r = ref($_->[0]);
        my $t = $_->[1];
        if ($r eq 'HASH') {
            push @$t, 'HASH';
        } elsif ($r eq 'ARRAY') {
            push @$t, 'ARRAY';
        } elsif (!$r) {
            push @$t, "SCALAR";
        }
        # XXX support objects like DBI etc
        push @$t, "ANY";
    }
    for my $m ($mode) {
        for my $t1 (@ta) {
            for my $t2 (@tb) {
                push @meth, "merge_${t1}_${t2}" . ($m ? "_$m" : "");
            }
        }
    }

    for my $m (@meth) {
        if ($self->can($m)) {
            #print "$m\n";
            return $self->$m($a, $b);
        }
    }
    $self->error("Don't know how to $mode merge ".(ref($a)||"SCALAR")." and ".(ref($b)||"SCALAR"));
    return;
}

# returns 1 if a is included in b (e.g. [user => "steven"] in included in [user
# => steven => "quota"], but [user => "rudi"] is not)
sub _path_is_included {
    my ($p1, $p2) = @_;
    my $res = 1;
    for my $i (0..@$p1-1) {
        do { $res = 0; last } if !defined($p2->[$i]) || $p1->[$i] ne $p2->[$i];
    }
    #print "_path_is_included([".join(", ", @$p1)."], [".join(", ", @$p2)."])? $res\n";
    $res;
}

# normal mode

sub merge_ANY_ANY_NORMAL {
    my ($self, $a, $b) = @_;
    $b;
}

sub merge_HASH_HASH_NORMAL {
    my ($self, $a, $b, $assume_left_keep) = @_;
    my $config = $self->config;
    return merge_ANY_ANY_NORMAL(@_) unless $config->{recurse_hash};
    return if $config->{wanted_path} && !_path_is_included($self->path, $config->{wanted_path});

    my (@ka, @kb); # ([key in data, unprefixed key, mode], ...)
    if ($config->{parse_hash_key_prefix}) {
        my $sortsub = sub {
            (($b =~ /^\*/) <=> ($a =~ /^\*/)) ||
            (($b =~ /^-/) <=> ($a =~ /^-/)) ||
            (($b =~ /^\+/) <=> ($a =~ /^\+/)) ||
            (($b =~ /^\./) <=> ($a =~ /^\./)) ||
            (($b =~ /^!/) <=> ($a =~ /^!/)) ||
            $a cmp $b
        };
        for (sort $sortsub keys %$a) {
            if (/^\!(.+)/) {
                if (exists($a->{$1}) || exists($a->{"*$1"})) {
                    $self->error("Key conflict in left side: $_ and $1/*$1");
                    return;
                }
                push @ka, [$_, ($config->{preserve_prefix} ? $_ : $1)];
            } elsif (/^\*(.+)/) {
                if (exists($a->{$1}) || exists($a->{"!$1"})) {
                    $self->error("Key conflict in left side: $_ and $1/!$1");
                    return;
                }
                push @ka, [$_, $1];
            } elsif (/^([+.-])(.+)/) {
                $self->error("Left side must not have prefix $1: $2");
                return;
            } else {
                push @ka, [$_, $_];
            }
        }
        for (sort $sortsub keys %$b) {
            if (/^([*+!.-])(.+)/) {
                next if exists($a->{"!$2"}) or ($assume_left_keep && exists($a->{$2}));
                my $m = ($1 eq '*' ? 'NORMAL' :
                         $1 eq '+' ? 'ADD' :
                         $1 eq '.' ? 'CONCAT' :
                         $1 eq '-' ? 'SUBTRACT' :
                         'DELETE');
                push @kb, [$_, $2, $m];
            } else {
                next if exists($a->{"!$_"}) or ($assume_left_keep && exists($a->{$_}));
                push @kb, [$_, $_, $config->{default_merge_mode}];
            }
        }

    } else {

        @ka = map {[$_, $_]} keys %$a;
        @kb = map {[$_, $_, $config->{default_merge_mode}]} keys %$b;

    }

    #use Data::Dumper; $Data::Dumper::Indent=0; print "\@ka => ", Dumper(\@ka), " \@kb => ", Dumper(\@kb), "\n";

    my $res = {};
    my $backup = {};
    for (@ka) {
        $res->{$_->[1]} = $a->{$_->[0]};
    }
    for (@kb) {
        if (exists $res->{$_->[1]}) {
            $backup->{$_->[1]} = $res->{$_->[1]};
            push @{ $self->path }, $_->[1];
            if ($_->[2] eq 'DELETE') {
                delete $res->{$_->[1]};
            } else {
                my $backup2;
                ($res->{$_->[1]}, $backup2) = $self->_merge($res->{$_->[1]}, $b->{$_->[0]}, $_->[2]);
            }
            pop @{ $self->path };
            return $res if $self->error;
        } else {
            $res->{$_->[1]} = $b->{$_->[0]} unless $_->[2] eq 'DELETE';
        }
    }
    ($res, $backup);
}

sub merge_ARRAY_ARRAY_NORMAL {
    my ($self, $a, $b) = @_;
    my $config = $self->config;
    return merge_ANY_ANY_NORMAL(@_) unless $config->{recurse_array};
    return if $config->{wanted_path} && !_path_is_included($self->path, $config->{wanted_path});

    my @res;
    my @backup;
    my $la = @$a;
    my $lb = @$b;
    for my $i (0..($la > $lb ? $la : $lb)-1) {
        push @{ $self->path }, $i;
        if ($i < $la && $i < $lb) {
            push @backup, $a->[$i];
            my ($res2, $backup2) = $self->_merge($a->[$i], $b->[$i], $config->{default_merge_mode});
            push @res, $res2;
        } elsif ($i < $la) {
            push @res, $a->[$i];
        } else {
            push @res, $b->[$i];
        }
        pop @{ $self->path };
    }
    (\@res, \@backup);
}

sub merge_ARRAY_ARRAY_ADD {
    my ($self, $a, $b) = @_;
    [ @$a, @$b ];
}

sub merge_HASH_HASH_ADD { merge_HASH_HASH_NORMAL(@_) }

sub merge_ARRAY_ARRAY_CONCAT {
    my ($self, $a, $b) = @_;
    [ @$a, @$b ];
}

sub merge_SCALAR_SCALAR_CONCAT {
    my ($self, $a, $b) = @_;
    $a . $b;
}

sub merge_HASH_HASH_CONCAT { merge_HASH_HASH_NORMAL(@_) }

sub merge_SCALAR_SCALAR_ADD {
    my ($self, $a, $b) = @_;
    $a + $b;
}

sub merge_SCALAR_SCALAR_SUBTRACT {
    my ($self, $a, $b) = @_;
    $a - $b;
}

sub _in($$) {
    my ($needle, $haystack) = @_;
    for (@$haystack) {
        return 1 if Compare($needle, $_);
    }
    0;
}

sub merge_ARRAY_ARRAY_SUBTRACT {
    my ($self, $a, $b) = @_;
    my @res;
    for (@$a) {
        push @res, $_ unless _in($_, $b);
    }
    \@res;
}

sub merge_HASH_HASH_SUBTRACT {
    my ($self, $a, $b) = @_;
    my %res;
    for (keys %$a) {
        $res{$_} = $a->{$_} unless exists($b->{$_});
    }
    \%res;
}

#sub merge_ANY_ANY_DELETE {
#    undef;
#}

sub merge_ANY_ANY_KEEP {
    my ($self, $a, $b) = @_;
    $a;
}

sub merge_HASH_HASH_KEEP { merge_HASH_HASH_NORMAL(@_, 1) }

=head1 CONFIG

You can set config like this:

 $merger->config->{CONFIGVAR} = 'VALUE';

Available config variables:

=head2 recurse_hash => 0 or 1

Whether to recursively merge hash. Default is 1.

With recurse_hash set to 1, hashes will be recursively merged:

 prefix_merge({h=>{a=>1}}, {h=>{b=>1}}); # {h=>{a=>1, b=>1}}

With recurse_hash set to 0, hashes on the left side will just be
replaced with hashes on the right side:

 prefix_merge({h=>{a=>1}}, {h=>{b=>1}}); # {h=>{b=>1}}

=head2 recurse_array => 0 or 1

Whether to recursively merge hash. Default is 0.

With recurse_array set to 1, arrays will be recursively merged:

 prefix_merge([1, 1], [2]); # [2, 1]

With recurse_array set to 0, array on the left side will just be
replaced with array on the right side:

 prefix_merge([1, 1], [2]); # [2]

=head2 parse_hash_key_prefix => 0 or 1

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

=head2 preserve_prefix => 0|1

Default it 0.

If set to 1, then merge prefixes on hash keys on the left is kept (not
stripped). Currently only '!' prefix on the left side is preserved. This is
useful if the merge result is to be merged again and we still want to preserve
the left side.

Example:

 prefix_merge({'!a'=>1}, {a=>2}); # {a=>1}
 prefix_merge({'!a'=>1}, {a=>2}, {preserve_prefix=>1}); # {'!a'=>1}

=head1 SEE ALSO

L<Data::Merger> (from Data-Utilities)
L<Hash::Merge>
L<Hash::Merge::Simple>
L<Data::Schema> (a module that uses this module)

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-prefixmerge
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-PrefixMerge>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::PrefixMerge

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-PrefixMerge>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-PrefixMerge>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-PrefixMerge>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-PrefixMerge/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
