sub _merge($$;$) {
    my ($a, $b, $dm) = @_;
    $dm ||= Data::PrefixMerge->new;
    $dm->merge($a, $b);
}

sub merge_is($$$$;$) {
    my ($a, $b, $expected, $test_name, $dm) = @_;
    my $res = _merge($a, $b, $dm);
    is_deeply($res->{result}, $expected, $test_name);
}

sub merge_ok($$$;$) {
    my ($a, $b, $test_name, $dm) = @_;
    my $res = _merge($a, $b, $dm);
    ok($res && $res->{success}, $test_name);
}

sub merge_fail($$$;$) {
    my ($a, $b, $test_name, $sn) = @_;
    my $res = _merge($a, $b, $sn);
    ok($res && !$res->{success}, $test_name);
}

1;
