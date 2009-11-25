package Data::PrefixMerge;
our $VERSION = '0.12';


# ABSTRACT: Merge two nested data structures, with merging mode prefix on hash keys


use Moose;
use Data::PrefixMerge::Config;
use Data::Compare;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(prefix_merge);

use Data::Dumper;
#sub _debug_dump { my $var = shift; print "DEBUG: ", Data::Dumper->new([$var])->Indent(0)->Terse(1)->Sortkeys(1)->Purity(0)->Dump, "\n"; }


sub prefix_merge {
    my ($a, $b, $config_vars) = @_;
    my $merger = __PACKAGE__->new(config => $config_vars);
    $merger->merge($a, $b);
}



has config => (is => "rw");
#has plugins => (is => "rw");

# merging process state
has path => (is => "rw");
has error => (is => "rw");
has result => (is => "rw");


sub BUILD {
    my ($self, $args) = @_;

    if ($self->config) {
        # some sanity checks
        my $is_hashref = ref($self->config) eq 'HASH';
        die "config must be a hashref or a Data::PrefixMerge::Config" unless
            $is_hashref || UNIVERSAL::isa($self->config, "Data::PrefixMerge::Config");
        $self->config(Data::PrefixMerge::Config->new(%{ $self->config })) if $is_hashref;
    } else {
        $self->config(Data::PrefixMerge::Config->new);
    }

    # XXX load default plugins
}


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

sub _process_options_key {
    my ($self, $h) = @_;
    my $k0 = $self->config->hash_options_key;
    return unless defined($k0);
    for my $k ("^$k0", $k0) {
        if (exists $h->{$k}) {
            my $opts = $h->{$k};
            unless (defined($opts) && ref($opts) eq 'HASH') {
                $self->error("Options key `$k` is not a hash");
                return;
            }
            my $remove_keep_maxdepth;
            my $do_remove_keep;
            for my $o (keys %$opts) {
                my $ov = $opts->{$o};
                if ($o =~ /^\^?(remove_keep_prefix(?:es)?)?$/) {
                    $do_remove_keep = $ov;
                } elsif ($o =~ /^\^?(remove_keep_max_depth)?$/) {
                    $remove_keep_maxdepth = $ov;
                } else {
                    $self->error("Invalid option `$o` in options key `$k`, ignored");
                }
            }
            if ($do_remove_keep) {
                $self->remove_keep_prefixes($h, $remove_keep_maxdepth);
            }
            delete $h->{$k};
            return;
        }
    }
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
            my ($a, $b) = @_;
            (($b =~ /^\^/) <=> ($a =~ /^\^/)) ||
            (($b =~ /^\*/) <=> ($a =~ /^\*/)) ||
            (($b =~ /^-/) <=> ($a =~ /^-/)) ||
            (($b =~ /^\+/) <=> ($a =~ /^\+/)) ||
            (($b =~ /^\./) <=> ($a =~ /^\./)) ||
            (($b =~ /^!/) <=> ($a =~ /^!/)) ||
            $a cmp $b
        };
        #_debug_dump([sort $sortsub keys %$a]);
        for (sort $sortsub keys %$a) {
            if (/^\^(.+)/) {
                if (exists($a->{$1}) || exists($a->{"*$1"})) {
                    $self->error("Key conflict on left side: $_ and $1/*$1");
                    return;
                }
                push @ka, [$_, ($config->{preserve_keep_prefix} ? $_ : $1)];
            } elsif (/^\*(.+)/) {
                if (exists($a->{$1}) || exists($a->{"^$1"})) {
                    $self->error("Key conflict on left side: $_ and $1/^$1");
                    return;
                }
                push @ka, [$_, $1];
            } elsif (/^([+.!-])(.+)/) {
                $self->error("Left side must not have prefix $1: $2");
                return;
            } elsif ($assume_left_keep && $config->{preserve_keep_prefix}) {
                $a->{"^$_"} = $a->{$_};
                delete $a->{$_};
                push @ka, ["^$_", $_];
            } else {
                push @ka, [$_, $_];
            }
        }
        #_debug_dump([sort $sortsub keys %$b]);
        for (sort $sortsub keys %$b) {
            if (/^([*+!.^-])(.+)/) {
                next if exists($a->{"^$2"}) or ($assume_left_keep && exists($a->{$2}));
                my $m = ($1 eq '*' ? 'NORMAL' :
                         $1 eq '+' ? 'ADD' :
                         $1 eq '.' ? 'CONCAT' :
                         $1 eq '-' ? 'SUBTRACT' :
                         $1 eq '^' ? 'KEEPRIGHT' :
                         'DELETE');
                push @kb, [$_, $2, $m];
            } else {
                next if exists($a->{"^$_"}) or ($assume_left_keep && exists($a->{$_}));
                push @kb, [$_, $_, $config->{default_merge_mode}];
            }
        }

    } else {

        @ka = map {[$_, $_]} keys %$a;
        @kb = map {[$_, $_, $config->{default_merge_mode}]} keys %$b;

    }

    my $res = {};
    my $backup = {};
    for (@ka) {
        my $nk = $assume_left_keep && $config->{preserve_keep_prefix}? "^$_->[1]" : $_->[1];
        $res->{$nk} = $a->{$_->[0]};
    }
    for (@kb) {
        my $nk = $_->[2] eq 'KEEPRIGHT' && $config->{preserve_keep_prefix}? "^$_->[1]" : $_->[1];
        if (exists $res->{$_->[1]}) {
            $backup->{$_->[1]} = $res->{$_->[1]};
            push @{ $self->path }, $_->[1];
            if ($_->[2] eq 'DELETE') {
                delete $res->{$_->[1]};
            } else {
                my $backup2;
                ($res->{$nk}, $backup2) = $self->_merge($res->{$_->[1]}, $b->{$_->[0]}, $_->[2]);
                delete $res->{$_->[1]} if $_->[1] ne $nk;
            }
            pop @{ $self->path };
            return $res if $self->error;
        } else {
            $res->{$nk} = $b->{$_->[0]} unless $_->[2] eq 'DELETE';
        }
    }
    $self->_process_options_key($res);
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
    $self->_process_options_key(\%res);
    \%res;
}

#sub merge_ANY_ANY_DELETE {
#    undef;
#}

sub merge_ANY_ANY_KEEP {
    my ($self, $a, $b) = @_;
    #print "merge_ANY_ANY_KEEP($a, $b)\n";
    $a;
}

sub merge_ANY_ANY_KEEPRIGHT {
    my ($self, $a, $b) = @_;
    #print "merge_ANY_ANY_KEEPRIGHT($a, $b)\n";
    $b;
}

sub merge_HASH_HASH_KEEP { merge_HASH_HASH_NORMAL(@_, 1) }


sub remove_keep_prefixes {
    my ($self, $data, $maxdepth, $_mem, $_curlevel) = @_;
    # $_mem is to handle circular reference
    $maxdepth //= -1;
    $_curlevel //= 1;

    #print "DEBUG: remove_keep_prefixes($data = ".Dumper($data).")\n";

    return $data if $maxdepth > 0 && $_curlevel > $maxdepth;

    if (!defined($_mem)) { $_mem = {} }
    my $ref = ref($data);
    $_mem->{$data}++ if $ref;
    #print "DEBUG: _mem = ".Dumper($_mem)."\n";
    goto L1 if $ref && $_mem->{$data} > 1;

    if ($ref eq 'HASH') {
        for (keys %$data) {
	    my $ref2 = ref($data->{$_});

            if (/^\^/) {
		my $new = $_; $new =~ s/^\^//;
                $data->{$new} = ($ref2 && $_mem->{$data->{$_}}) ?
		    $data->{$_} :
		    $self->remove_keep_prefixes($data->{$_}, $maxdepth, $_mem, $_curlevel+1);
                delete $data->{$_};
            } else {
                $data->{$_} = $self->remove_keep_prefixes($data->{$_}, $maxdepth, $_mem, $_curlevel+1)
		    unless ($ref2 && $_mem->{$data->{$_}});
            }
        }
    } elsif (ref($data) eq 'ARRAY') {
        for (@$data) {
	    my $ref2 = ref($_);
            next unless $ref2;
            $_ = $self->remove_keep_prefixes($_, $maxdepth, $_mem, $_curlevel+1)
		unless ($_mem->{$_});
        }
    }
  L1:
    #print "DEBUG: result: $data = ".Dumper($data)."\n";
    $data;
}


sub remove_keep_prefix { remove_keep_prefixes(@_) }


__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

Data::PrefixMerge - Merge two nested data structures, with merging mode prefix on hash keys

=head1 VERSION

version 0.12

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
L<Data::PrefixMerge::Config>), in which Data::PrefixMerge will behave like most
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

=head2 KEEP ('^' prefix on the left/right side)

If you add '^' prefix on the left side, it will be protected from
being replaced/deleted/etc.

 prefix_merge({'^x'=>WHATEVER1}, {"x"=>WHATEVER2}); # {x=>WHATEVER1}

For hashes, KEEP mode means that all keys on the left side will not be
replaced/modified/deleted, *but* you can still add more keys from the
right side hash.

 prefix_merge({a=>1, b=>2, c=>3},
              {a=>4, '^c'=>1, d=>5},
              'KEEP');
            # {a=>1, b=>2, c=>3, d=>5}

=head2

=head1 FUNCTIONS

=head2 prefix_merge($a, $b[, $config_vars])

A non-OO wrapper for merge() method. Exported by default. See C<merge>
method for more details.

=head1 ATTRIBUTES

=head2 config

A hashref for config. See L<Data::PrefixMerge::Config>.

=head1 METHODS

=head2 merge($a, $b)

Merge two nested data structures. Returns the result hash: {
success=>0|1, error=>'...', result=>..., backup=>... }. The 'error'
key is set to contain an error message if there is an error. The merge
result is in the 'result' key. The 'backup' key contains replaced
elements from the original hash/array.

=head2 remove_keep_prefixes($data, $maxdepth)

Recurse $data and remove keep prefix ("^") in hash keys. $maxdepth is
maximum depth, default is -1 (unlimited).

Example: $merger->remove_keep_prefixes([1, "^a", {"^b"=>1}]); # [1, "^a", {b=>1}]

=head2 remove_keep_prefix

Alias for remove_keep_prefixes.

=head1 SEE ALSO

L<Data::Merger> (from Data-Utilities)

L<Hash::Merge>

L<Hash::Merge::Simple>

L<Data::Schema> (a module that uses this module)

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

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

