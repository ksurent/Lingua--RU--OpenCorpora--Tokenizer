package Lingua::RU::OpenCorpora::Tokenizer;

use utf8;
use v5.10;
use strict;
use warnings;

use Carp qw(croak);
use Lingua::RU::OpenCorpora::Tokenizer::Updater;

our $VERSION = 0.02;

sub new {
    my $class = shift;

    my $self = bless {}, $class;
    $self->_init;

    $self;
}

sub tokens {
    my($self, $text) = @_;

    $self->_do_tokenize($text);

    $self->{tokens};
}

sub tokens_bounds {
    my($self, $text) = @_;

    $self->_do_tokenize($text);

    $self->{bounds};
}

sub _do_tokenize {
    my($self, $text) = @_;

    my $chars = $self->{chars} = [split //, $text];
    $self->{bounds} = [];
    $self->{tokens} = [];

    my $token;
    for(my $i = 0; $i <= $#{ $chars }; $i++) {
        my $context = {
            char      => $chars->[$i],
            prevchar  => $i ? $chars->[$i - 1] : '',
            nextchar  => $chars->[$i + 1] // '',
            nnextchar => $chars->[$i + 2] // '',
            pos       => $i,
        };

        $self->_get_char_chains($context);
        $self->_vector($context);

        $token .= $chars->[$i];

        my $coeff = $self->{vectors}{$context->{vector}} // 0.5;
        if($coeff) {
            push @{ $self->{bounds} }, [$context->{pos} + 2, $coeff];

            $token =~ s{^\s+|\s+$}{};
            push @{ $self->{tokens} }, $token if $token;
            $token = '';
        }
    }
}

sub _get_char_chains {
    my($self, $context) = @_;

    my $chain = my $chain_left = my $chain_right = '';

    if($self->_is_hyphen($context->{nextchar}) or $self->_is_hyphen($context->{char})) {
        # go left
        for(my $i = $context->{pos}; $i >= 0; $i--) {
            my $ch = $self->{chars}[$i];
            if($self->_is_cyr($ch) or $self->_is_hyphen($ch) or $self->_is_single_quote($ch)) {
                $chain_left = $ch . $chain_left;
            }
            else {
                last;
            }

            $chain_left =~ s/-$//;
        }

        # go right
        for(my $i = $context->{pos} + 1; $i <= $#{ $self->{chars} }; $i++) {
            my $ch = $self->{chars}[$i];
            if($self->_is_cyr($ch) or $self->_is_hyphen($ch) or $self->_is_single_quote($ch)) {
                $chain_right .= $ch;
            }
            else {
                last;
            }

            $chain_right =~ s/^-//;
        }

        $chain = $chain_left . '-' . $chain_right;
    }

    $context->{chain}       = $chain;
    $context->{chain_left}  = $chain_left;
    $context->{chain_right} = $chain_right;

    return;
}

sub _vector {
    my($self, $context) = @_;

    my $vec = join '',
              map $_->[0]($self, @$context{@$_[1 .. $#$_]}),
              @{ $self->{vector_functions} };

    $context->{vector} = oct '0b' . $vec;

    return;
}

sub _init {
    my $self = shift;

    $self->{vector_functions} = [
        [\&_is_space,        'char',            ],
        [\&_is_space,        'nextchar',        ],
        [\&_is_pmark,        'char',            ],
        [\&_is_pmark,        'nextchar',        ],
        [\&_is_latin,        'char',            ],
        [\&_is_latin,        'nextchar',        ],
        [\&_is_cyr,          'char',            ],
        [\&_is_cyr,          'nextchar',        ],
        [\&_is_hyphen,       'char',            ],
        [\&_is_hyphen,       'nextchar',        ],
        [\&_is_digit,        'prevchar',        ],
        [\&_is_digit,        'char',            ],
        [\&_is_digit,        'nextchar',        ],
        [\&_is_digit,        'nnextchar',       ],
        [\&_is_dict_chain,   'chain',           ],
        [\&_is_dot,          'char',            ],
        [\&_is_dot,          'nextchar',        ],
        [\&_is_bracket1,     'char',            ],
        [\&_is_bracket1,     'nextchar',        ],
        [\&_is_bracket2,     'char',            ],
        [\&_is_bracket2,     'nextchar',        ],
        [\&_is_single_quote, 'char',            ],
        [\&_is_single_quote, 'nextchar',        ],
        [\&_is_suffix,       'chain_right',     ],
        [\&_is_same_pm,      'char', 'nextchar',],
        [\&_is_slash,        'char',            ],
        [\&_is_slash,        'nextchar',        ],
    ];

    $self->_load_vectors;
    $self->_load_hyphens;

    return;
}

sub _load_vectors {
    my $self = shift;

    my $file = Lingua::RU::OpenCorpora::Tokenizer::Updater->_path('vectors');
    open my $fh, '<', $file or croak "$file: $!";
    <$fh>; # skip version
    my %vectors = map { chomp; split } <$fh>;
    close $fh;

    $self->{vectors} = \%vectors;

    return;
}

sub _load_hyphens {
    my $self = shift;

    my $file = Lingua::RU::OpenCorpora::Tokenizer::Updater->_path('hyphens');
    open my $fh, '<:utf8', $file or croak "$file: $!";
    <$fh>; # skip version
    my %hyphens = map { chomp; $_, undef } <$fh>;
    close $fh;

    $self->{hyphens} = \%hyphens;

    return;
}

sub _is_pmark        { $_[1] =~ /^[,?!":;\xAB\xBB]$/ ? 1 : 0 }

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

sub _is_same_pm      { $_[1] eq $_[2] ? 1 : 0 }

sub _is_dict_chain {
    my($self, $chain) = @_;

    return 0 if not $chain or $chain =~ /^-/;

    exists $self->{hyphens}{$chain} ? 1 : 0;
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

In terms of this module context is just a binary vector, currently consisting of 27 elements. It's calculated for every character of the text, then it gets converted to decimal representation and then it's checked against L<VECTORS FILE>. Every element is a result of a simple function like C<_is_latin>, C<_is_digit>, C<_is_bracket> and etc. applied to the input character and few characters around it.

=head2 VECTORS FILE

Contains a list of vectors with probability values showing the chance that given vector is a token boundary.

Built by OpenCorpora project from semi-automatically annotated corpus.

=head2 HYPHENS FILE

Contains a list of hyphenated Russian words. Used in vectors calculations.

Built by OpenCorpora project from semi-automatically annotated corpus.

=head1 METHODS

=head2 new

Constructs and initializes new tokenizer object.

=head2 tokens($text)

Takes text as input and splits it into tokens. Returns a reference to an array of tokens.

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
