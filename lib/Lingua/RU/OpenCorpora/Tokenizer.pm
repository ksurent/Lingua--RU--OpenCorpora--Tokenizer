package Lingua::RU::OpenCorpora::Tokenizer;

use utf8;
use strict;
use warnings;

use Lingua::RU::OpenCorpora::Tokenizer::List;
use Lingua::RU::OpenCorpora::Tokenizer::Vectors;

our $VERSION = 0.05;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;
    $self->_init;

    $self;
}

sub tokens {
    my($self, $text, $options) = @_;

    $options = {} unless defined $options;
    $options->{want_tokens} = 1;
    $options->{threshold}   = 1 unless defined $options->{threshold};

    $self->_do_tokenize($text, $options);

    $self->{tokens};
}

sub tokens_bounds {
    my($self, $text, $options) = @_;

    $options = {} unless defined $options;
    $options->{want_tokens} = 0;

    $self->_do_tokenize($text, $options);

    $self->{bounds};
}

sub _do_tokenize {
    my($self, $text, $options) = @_;

    my $chars = $self->{chars} = [split //, $text];
    $self->{bounds} = [];
    $self->{tokens} = [];

    my $token;
    for(my $i = 0; $i <= $#{ $chars }; $i++) {
        my $ctx = {
            char      => $chars->[$i],
            prevchar  => $i ? $chars->[$i - 1] : '',
            nextchar  => $chars->[$i + 1],
            nnextchar => $chars->[$i + 2],
            pos       => $i,
        };
        not defined $ctx->{$_} and $ctx->{$_} = ''
            for qw(nextchar nnextchar);

        $self->_get_char_sequences($ctx);
        $self->_vector($ctx);

        my $coeff = $self->{vectors}->in_list($ctx->{vector});
        $coeff    = 0.5 unless defined $coeff;

        if($options->{want_tokens}) {
            $token .= $chars->[$i];

            if(
                $coeff >= $options->{threshold}
                or $ctx->{pos} == $#{ $chars }
            )
            {
                $token =~ s{^\s+|\s+$}{};
                push @{ $self->{tokens} }, $token if $token;
                $token = '';
            }
        }
        else {
            if($coeff) {
                push @{ $self->{bounds} }, [$ctx->{pos}, $coeff];
            }
        }
    }
}

sub _get_char_sequences {
    my($self, $ctx) = @_;

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
            my $ch = $self->{chars}[$i];

            my $case1 = !!(
                $self->_is_hyphen($spacer)
                and (
                    $self->_is_cyr($ch)
                    or $self->_is_hyphen($ch)
                    or $self->_is_single_quote($ch)
                )
            );
            my $case2 = !!(
                not $self->_is_hyphen($spacer)
                and not $self->_is_space($ch)
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
        for(my $i = $ctx->{pos} + 1; $i <= $#{ $self->{chars} }; $i++) {
            my $ch = $self->{chars}[$i];

            my $case1 = !!(
                $self->_is_hyphen($spacer)
                and (
                    $self->_is_cyr($ch)
                    or $self->_is_hyphen($ch)
                    or $self->_is_single_quote($ch)
                )
            );
            my $case2 = !!(
                not $self->_is_hyphen($spacer)
                and not $self->_is_space($ch)
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

sub _vector {
    my($self, $ctx) = @_;

    my $spacer           = !!length $ctx->{spacer};
    my $spacer_is_hyphen = $spacer && $self->_is_hyphen($ctx->{spacer});

    my @bits = (
        $self->_char_class($ctx->{char}),
        $self->_char_class($ctx->{nextchar}),
        $self->_is_digit($ctx->{prevchar}),
        $self->_is_digit($ctx->{nnextchar}),
        $spacer_is_hyphen
            ? $self->_is_dict_seq($ctx->{seq})
            : 0,
        $spacer_is_hyphen
            ? $self->_is_suffix($ctx->{seq_right})
            : 0,
        $self->_is_same_pm($ctx->{char}, $ctx->{nextchar}),
        ($spacer and not $spacer_is_hyphen)
            ? $self->_looks_like_url($ctx->{seq}, $ctx->{seq_right})
            : 0,
        ($spacer and not $spacer_is_hyphen)
            ? $self->_is_exception_seq($ctx->{seq})
            : 0,
        $spacer_is_hyphen
            ? $self->_is_prefix($ctx->{seq_left})
            : 0,
        ($self->_is_colon($ctx->{spacer}) and !!length $ctx->{seq_right})
            ? $self->_looks_like_time($ctx->{seq_left}, $ctx->{seq_right})
            : 0,
    );

    $ctx->{vector} = oct join '', '0b', @bits;

    return;
}

sub _init {
    my $self = shift;

    for(qw(exceptions prefixes hyphens)) {
        my $list = Lingua::RU::OpenCorpora::Tokenizer::List->new(
            $_,
            {
                data_dir => $self->{data_dir},
            },
        );
        $self->{$_} = $list;
    }

    my $vectors = Lingua::RU::OpenCorpora::Tokenizer::Vectors->new({
        data_dir => $self->{data_dir},
    });
    $self->{vectors} = $vectors;

    return;
}

sub _is_pmark        { $_[1] =~ /^[,?!";«»]$/ ? 1 : 0 }

sub _is_latin        { $_[1] =~ /^[a-zA-Z]$/ ? 1 : 0 }

sub _is_cyr          { $_[1] =~ /^[а-яА-ЯЁё]$/ ? 1 : 0 }

sub _is_space        { $_[1] =~ /^\s$/ ? 1 : 0 }

sub _is_digit        { $_[1] =~ /^\d$/ ? 1 : 0 }

sub _is_bracket1     { $_[1] =~ /^[\[({<]$/ ? 1 : 0 }

sub _is_bracket2     { $_[1] =~ /^[\])}>]$/ ? 1 : 0 }

sub _is_suffix       { $_[1] =~ /^(?:то|таки|с|ка|де)$/ ? 1 : 0 }

sub _is_hyphen       { $_[1] eq '-' ? 1 : 0 }

sub _is_dot          { $_[1] eq '.' ? 1 : 0 }

sub _is_single_quote { $_[1] eq "'" ? 1 : 0 }

sub _is_slash        { $_[1] eq '/' ? 1 : 0 }

sub _is_colon        { $_[1] eq ':' ? 1 : 0 }

sub _is_same_pm      { $_[1] eq $_[2] ? 1 : 0 }

sub _is_prefix {
    my($self, $seq) = @_;

    $self->{prefixes}->in_list(lc $seq) ? 1 : 0;
}

sub _is_dict_seq {
    my($self, $seq) = @_;

    return 0 if not $seq or $seq =~ /^-/;

    $self->{hyphens}->in_list($seq) ? 1 : 0;
}

sub _is_exception_seq {
    my($self, $seq) = @_;

    return 1 if $self->{exceptions}->in_list($seq);

    return 0 unless $seq =~ /^\W|\W$/;

    $seq =~ s/^[^A-Za-zА-ЯЁа-яё0-9]+//;
    return 1 if $self->{exceptions}->in_list($seq);

    while($seq =~ s/^[^A-Za-zА-ЯЁа-яё0-9]+//) {
        return 1 if $self->{exceptions}->in_list($seq);
    }

    0;
}

sub _looks_like_url {
    my($self, $seq, $seq_right) = @_;

    return 0 unless $seq_right;
    return 0 if length $seq < 5;
    return 0 if $seq =~ /^\./;

    for($seq) {
        m{^\W*https?://}
        or m{^\W*www\.}
        or m<.\.(?:[a-z]{2,3}|ру|рф)\W*$>i
        or return 0;
    }

    1;
}

sub _looks_like_time {
    my($self, $seq_left, $seq_right) = @_;

    return 0 if $seq_left  !~ /^[0-9]{1,2}$/
             or $seq_right !~ /^[0-9]{2}$/;

    ($seq_left < 24 and $seq_right < 60)
        ? 1
        : 0;
}

sub _char_class {
    my($self, $char) = @_;

    my $bits = $self->_is_cyr($char)          ? '0001' :
               $self->_is_space($char)        ? '0010' :
               $self->_is_dot($char)          ? '0011' :
               $self->_is_pmark($char)        ? '0100' :
               $self->_is_hyphen($char)       ? '0101' :
               $self->_is_digit($char)        ? '0110' :
               $self->_is_latin($char)        ? '0111' :
               $self->_is_bracket1($char)     ? '1000' :
               $self->_is_bracket2($char)     ? '1001' :
               $self->_is_single_quote($char) ? '1010' :
               $self->_is_slash($char)        ? '1011' :
               $self->_is_colon($char)        ? '1100' : '0000';

    split //, $bits;
}

1;

__END__

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer - tokenizer for OpenCorpora project

=head1 SYNOPSIS

    my $tokens = $tokenizer->tokens($text);

    my $bounds = $tokenizer->tokens_bounds($text);

=head1 DESCRIPTION

This module tokenizes input texts in Russian language.

Note that it uses probabilistic algorithm rather than trying to parse the language. It also uses some pre-calculated data freely provided by OpenCorpora project.

NOTE: OpenCorpora periodically provides updates for this data. Checkout C<opencorpora-update-tokenizer> script that comes with this distribution.

The algorithm is this:

=over 4

=item 1. Split text into chars.

=item 2. Iterate over the chars from left to right.

=item 3. For every char get its context (see L<CONTEXT>).

=item 4. Find probability for the context in vectors file (see L<VECTORS FILE>) or use the default value - 0.5.

=back

=head2 CONTEXT

In terms of this module context is just a binary vector, currently consisting of 17 elements. It's calculated for every character of the text, then it gets converted to decimal representation and then it's checked against L<VECTORS FILE>. Every element is a result of a simple function like C<_is_latin>, C<_is_digit>, C<_is_bracket> and etc. applied to the input character and few characters around it.

=head2 VECTORS FILE

Contains a list of vectors with probability values showing the chance that given vector is a token boundary.

Built by OpenCorpora project from semi-automatically annotated corpus.

=head2 HYPHENS FILE

Contains a list of hyphenated Russian words. Used in vectors calculations.

Built by OpenCorpora project from semi-automatically annotated corpus.

=head2 EXCEPTIONS FILE

Contains a list of char sequences that are not subjects to tokenizing.

Built by OpenCorpora project from semi-automatically annotated corpus.

=head2 PREFIXES FILE

Contains a list of common prefixes for decompound words.

Built by OpenCorpora project from semi-automatically annotated corpus.

NOTE: all files are stored as GZip archives and are not supposed to be edited manually.

=head1 METHODS

=head2 new(%args)

Constructs and initializes new tokenizer object.

Arguments are:

=over 4

=item data_dir

Path to a directory with OpenCorpora data. Optional. Defaults to distribution directory (see L<File::ShareDir>).

=back

=head2 tokens($text [, $options])

Takes text as input and splits it into tokens. Returns a reference to an array of tokens.

You can also pass a hashref with options as a second argument. Current options:

=over 4

=item threshold

Minimal probability value for tokens boundary. Boundaries with lower probability are excluded from consideration.

Default value is 1, which makes tokenizer do splitting only when it's confident.

=back

=head2 tokens_bounds($text)

Takes text as input and finds bounds of tokens in the text. It doesn't split the text into tokens, it just marks where tokens could be.

Returns an arrayref of arrayrefs. Inner arrayref consists of two elements: boundary position in text and probability.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer::Updater>

L<http://mathlingvo.ru/nlpseminar/archive/s_49>

=head1 AUTHOR

OpenCorpora.org team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
