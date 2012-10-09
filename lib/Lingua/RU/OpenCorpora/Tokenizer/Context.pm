package Lingua::RU::OpenCorpora::Tokenizer::Context;

use utf8;
use strict;
use warnings;

use Unicode::Normalize ();

our $VERSION = 0.07;

sub new {
    my($class, $args) = @_;

    # normalize Unicode to prevent decomposed characters to be processed separately
    my $text = Unicode::Normalize::NFC(delete $args->{text});

    bless {
        chars      => [split //, $text],
        exceptions => delete $args->{exceptions},
        prefixes   => delete $args->{prefixes},
        hyphens    => delete $args->{hyphens},
        vectors    => delete $args->{vectors},
        idx        => 0, # iterator index
    }, $class;
}

sub next {
    my $self = shift;

    my $idx   = $self->{idx};
    my $chars = $self->{chars};
    return undef if $idx > $#$chars;

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

    $self->{idx}++;

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
        my $last_pos = $#{ $self->{chars} };
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
                         @{$_[1]}{qw(spacer prevchar char nextchar nnextchar seq)};

    $_vectors_cache->{$ckey} = $_[0]->_do_vectorize($_[1]) unless exists $_vectors_cache->{$ckey};
    $_[1]->{vector} = $_vectors_cache->{$ckey};

    $_[1]->{likelihood} = $_[0]->{vectors}->in_list($_[1]->{vector})
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

=encoding UTF-8

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer::Context - represents context for text characters

=head1 SYNOPSIS

    my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
        text       => $input_text,
        hyphens    => $hyphens,
        prefixes   => $prefixes,
        exceptions => $exceptions,
    });
    while(my $current = $ctx->next) {
        # context for current character
        ...
    }

=head1 DESCRIPTION

In terms of this module context is just a binary vector (plus some meta information). It's calculated for every character in the text, then it gets converted to decimal representation and then it's checked against a list of vectors. Every element of the vector is the result of a simple function like C<_is_latin>, C<_is_digit>, C<_is_bracket> and etc. applied to the input character and few characters around it.

=head1 METHODS

This class provides iterable interface by inheriting L<Array::Iterator>.

=head2 new($args)

Constructor.

Takes a hashref as an argument with the following keys:

=over 4

=item text

Input text to tokenize. Required.

=item hyphens, prefixes, exceptions

Data objects. All required. See L<Lingua::RU::OpenCorpora::Tokenizer::List>.

=item vectors

Data object. Not needed in training mode, must be specified otherwise. See L<Lingua::RU::OpenCorpora::Tokenizer::Vectors>.

=back

=head2 next

Returns next character's context or undef when there are no characters left. Context is a hashref with the following keys:

=over 4

=item char

Current character.

=item nextchar

Next character.

=item prevchar

Previous character.

=item nnextchar

Character after next.

=item pos

Zero-based index of the current character.

=item is_space

Flag whether the current character is space.

=item seq_left

Sequence of contextually relevant (probably) characters to left of the current character.

For example: if you are processing an input string like "Город Санкт-Петербург" and your current character is "-", then C<seq_left> would be "Санкт".

=item seq_right

Sequence of contextually relevant (probably) characters to right of the current character.

For example: if you are processing an input string like "Город Санкт-Петербург" and your current character is "-", then C<seq_right> would be "Петербург".

=item seq

Concatenation of C<seq_left>, C<char> and C<seq_right>.

=item vector

Decimal representation of the binary context vector. Uniquely identifies the current character and its context.

=item likelihood

Likelihood of the current vector to be a token bound.

Note that this key will be missing if no vectors file was provided in constructor. This is the case when you are training your model.

=back

=head1 SEE ALSO

L<Array::Iterator>

L<Lingua::RU::OpenCorpora::Tokenizer>

=head1 AUTHOR

OpenCorpora team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
