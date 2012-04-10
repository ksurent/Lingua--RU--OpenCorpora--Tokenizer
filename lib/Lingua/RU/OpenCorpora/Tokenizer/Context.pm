package Lingua::RU::OpenCorpora::Tokenizer::Context;

use utf8;
use strict;
use warnings;
use parent 'Array::Iterator';

sub new {
    my($class, $text, $args) = @_;

    my $self = $class->SUPER::new([split //, $text]);
    $self->{exceptions} = delete $args->{exceptions};
    $self->{prefixes}   = delete $args->{prefixes};
    $self->{hyphens}    = delete $args->{hyphens};
    $self->{vectors}    = delete $args->{vectors};

    $self;
}

sub _getItem {
    my($self, $chars, $idx) = @_;

    my $ctx = {
        char      => $chars->[$idx],
        prevchar  => $idx                     ? $chars->[$idx-1] : '',
        nextchar  => defined $chars->[$idx+1] ? $chars->[$idx+1] : '',
        nnextchar => defined $chars->[$idx+2] ? $chars->[$idx+2] : '',
        pos       => $idx,
        is_space  => _is_space($chars->[$idx]),
    };
    $self->_get_char_sequences($ctx, $chars);
    $self->_vectorize($ctx, $chars);

    $ctx;
}

sub _get_char_sequences {
    my($self, $ctx, $chars) = @_;

    my $seq = my $seq_left = my $seq_right = '';
    my $spacer = '';

    if(
        $ctx->{nextchar} =~ m|([-./?=:&"!+()])|
        or $ctx->{char} =~ m|([-./?=:&"!+()])|
    )
    {
        $spacer = $1;
    }

    if(length $spacer) {
        # go left
        for(my $i = $ctx->{pos}; $i >= 0; $i--) {
            my $ch = $chars->[$i];

            my $case1 = !!(
                _is_hyphen($spacer)
                and (
                    _is_cyr($ch)
                    or _is_hyphen($ch)
                    or _is_single_quote($ch)
                )
            );
            my $case2 = !!(
                not _is_hyphen($spacer)
                and not _is_space($ch)
            );

            if($case1 or $case2) {
                $seq_left = $ch . $seq_left;
            }
            else {
                last;
            }

            $seq_left = substr $seq_left, 0, -1
                if substr($seq_left, -1) eq $spacer;
        }

        # go right
        my $last_pos = $self->get_length - 1;
        for(my $i = $ctx->{pos} + 1; $i <= $last_pos; $i++) {
            my $ch = $chars->[$i];

            my $case1 = !!(
                _is_hyphen($spacer)
                and (
                    _is_cyr($ch)
                    or _is_hyphen($ch)
                    or _is_single_quote($ch)
                )
            );
            my $case2 = !!(
                not _is_hyphen($spacer)
                and not _is_space($ch)
            );

            if($case1 or $case2) {
                $seq_right .= $ch;
            }
            else {
                last;
            }

            $seq_right = substr $seq_right, 0, 1
                if substr($seq_right, -1) eq $spacer;
         }

        $seq = join '', $seq_left, $spacer, $seq_right;
    }

    $ctx->{spacer}    = $spacer;
    $ctx->{seq}       = $seq;
    $ctx->{seq_left}  = $seq_left;
    $ctx->{seq_right} = $seq_right;

    return;
}

# hot stuff below

my $_vectors_cache;
sub _vectorize {
    my $ckey = join ',', _is_hyphen($_[1]->{spacer}),
                         @{$_[1]}{qw(spacer prevchar char nextchar nnextchar seq_left seq_right)};

    $_vectors_cache->{$ckey} = $_[0]->_do_vectorize($_[1]) unless exists $_vectors_cache->{$ckey};
    $_[1]->{vector} = $_vectors_cache->{$ckey};

    $_[1]->{probability} = $_[0]->{vectors}->in_list($_[1]->{vector})
        if defined $_[0]->{vectors};

    return;
}

sub _do_vectorize {
    my $spacer           = !!length $_[1]->{spacer};
    my $spacer_is_hyphen = $spacer && _is_hyphen($_[1]->{spacer});

    my @bits = (
        _char_class($_[1]->{char}),
        _char_class($_[1]->{nextchar}),
        _is_digit($_[1]->{prevchar}),
        _is_digit($_[1]->{nnextchar}),
        $spacer_is_hyphen
            ? _is_dict_seq($_[0]->{hyphens}, $_[1]->{seq})
            : 0,
        $spacer_is_hyphen
            ? _is_suffix($_[1]->{seq_right})
            : 0,
        _is_same_pm($_[1]->{char}, $_[1]->{nextchar}),
        ($spacer and not $spacer_is_hyphen)
            ? _looks_like_url($_[1]->{seq}, $_[1]->{seq_right})
            : 0,
        ($spacer and not $spacer_is_hyphen)
            ? _is_exception_seq($_[0]->{exceptions}, $_[1]->{seq})
            : 0,
        $spacer_is_hyphen
            ? _is_prefix($_[0]->{prefixes}, $_[1]->{seq_left})
            : 0,
        (_is_colon($_[1]->{spacer}) and !!length $_[1]->{seq_right})
            ? _looks_like_time($_[1]->{seq_left}, $_[1]->{seq_right})
            : 0,
    );

    oct join '', '0b', @bits;
}

sub _is_pmark        { $_[0] =~ /^[,?!";«»]$/ ? 1 : 0 }

sub _is_latin        { $_[0] =~ /^\p{Latin}$/ ? 1 : 0 }

sub _is_cyr          { $_[0] =~ /^\p{Cyrillic}$/ ? 1 : 0 }

sub _is_digit        { $_[0] =~ /^[0-9]$/ ? 1 : 0 }

sub _is_bracket1     { $_[0] =~ /^[\[({<]$/ ? 1 : 0 }

sub _is_bracket2     { $_[0] =~ /^[\])}>]$/ ? 1 : 0 }

sub _is_suffix       { $_[0] =~ /^(?:то|таки|с|ка|де)$/ ? 1 : 0 }

sub _is_space        { $_[0] =~ /^\s$/ ? 1 : 0 }

sub _is_hyphen       { $_[0] eq '-' ? 1 : 0 }

sub _is_dot          { $_[0] eq '.' ? 1 : 0 }

sub _is_single_quote { $_[0] eq "'" ? 1 : 0 }

sub _is_slash        { $_[0] eq '/' ? 1 : 0 }

sub _is_colon        { $_[0] eq ':' ? 1 : 0 }

sub _is_same_pm      { $_[0] eq $_[1] ? 1 : 0 }

sub _is_prefix       { $_[0]->in_list($_[1]) ? 1 : 0 }

sub _is_dict_seq {
    return 0 if not $_[1] or substr $_[1], 0, 1 eq '-';

    $_[0]->in_list($_[1]) ? 1 : 0;
}

sub _is_exception_seq {
    my $seq = $_[1]; # need a copy

    return 1 if $_[0]->in_list($seq);

    return 0 unless $seq =~ /^\W|\W$/;

    $seq =~ s/^\W+//;
    return 1 if $_[0]->in_list($seq);

    while($seq =~ s/\W$//) {
        return 1 if $_[0]->in_list($seq);
     }

    0;
}

sub _looks_like_url {
    return 0 unless !!length $_[1];
    return 0 if length $_[0] < 5;
    return 0 if substr $_[0], 0, 1 eq '.';

    $_[0] =~ m{^\W*https?://?}
    or $_[0] =~ m{^\W*www\.}
    or $_[0] =~ m<.\.(?:[a-z]{2,3}|ру|рф)\W*$>i
    or return 0;

    1;
}

sub _looks_like_time {
    my($seq_left, $seq_right) = @_; # need copies

    $seq_left  =~ s/^[^0-9]{1,2}//;
    $seq_right =~ s/[^0-9]+$//;

    return 0 if $seq_left !~ /^[0-9]{1,2}$/
             or $seq_right !~ /^[0-9]{2}$/;

    ($seq_left < 24 and $seq_right < 60)
        ? 1
        : 0;
}

sub _char_class {
    _is_cyr($_[0])          ? '0001' :
    _is_space($_[0])        ? '0010' :
    _is_dot($_[0])          ? '0011' :
    _is_pmark($_[0])        ? '0100' :
    _is_hyphen($_[0])       ? '0101' :
    _is_digit($_[0])        ? '0110' :
    _is_latin($_[0])        ? '0111' :
    _is_bracket1($_[0])     ? '1000' :
    _is_bracket2($_[0])     ? '1001' :
    _is_single_quote($_[0]) ? '1010' :
    _is_slash($_[0])        ? '1011' :
    _is_colon($_[0])        ? '1100' : '0000';
}

1;

__END__
