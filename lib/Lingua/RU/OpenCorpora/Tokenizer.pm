package Lingua::RU::OpenCorpora::Tokenizer;

use utf8;
use strict;
use warnings;

use Unicode::Normalize ();

use Lingua::RU::OpenCorpora::Tokenizer::List;
use Lingua::RU::OpenCorpora::Tokenizer::Vectors;
use Lingua::RU::OpenCorpora::Tokenizer::Context;

our $VERSION = 0.06;

sub new {
    my($class, $args) = @_;

    $args ||= {};
    my $self = bless {%$args}, $class;
    $self->_init;

    $self;
}

sub _init {
    my $self = shift;

    for(qw(exceptions prefixes hyphens)) {
        unless(defined $self->{$_}) {
            my $list = Lingua::RU::OpenCorpora::Tokenizer::List->new({
                list     => $_,
                data_dir => $self->{data_dir},
            });
            $self->{$_} = $list;
        }
    }

    unless(defined $self->{vectors}) {
        my $vectors = Lingua::RU::OpenCorpora::Tokenizer::Vectors->new({
            data_dir => $self->{data_dir},
        });
        $self->{vectors} = $vectors;
    }

    return;
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

*bounds = \&tokens_bounds;

sub _do_tokenize {
    my($self, $text, $options) = @_;

    my $token;
    $self->{tokens} = [];
    $self->{bounds} = [];

    my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
        text       => $text,
        exceptions => $self->{exceptions},
        prefixes   => $self->{prefixes},
        hyphens    => $self->{hyphens},
        vectors    => $self->{vectors},
    });
    my $last_pos = $#{ $ctx->{chars} };
    while(my $current = $ctx->next) {
        my $likelihood = $current->{likelihood};
        $likelihood    = 0.5 unless defined $likelihood;

        if($options->{want_tokens}) {
            $token .= $current->{char};

            if(
                $likelihood >= $options->{threshold}
                or $current->{pos} == $last_pos
            )
            {
                $token =~ s{^\s+|\s+$}{}g;
                push @{ $self->{tokens} }, $token if $token;
                $token = '';
            }
        }
        elsif($likelihood > 0) {
            push @{ $self->{bounds} }, [$current->{pos}, $likelihood];
        }
    }
}

1;

__END__

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer - tokenizer for OpenCorpora project

=head1 SYNOPSIS

    my $tokens = $tokenizer->tokens($text);

    my $bounds = $tokenizer->bounds($text);

=head1 DESCRIPTION

This module tokenizes input texts in Russian language.

Note that it uses probabilistic algorithm rather than trying to parse the language. It also uses some pre-calculated data freely provided by OpenCorpora project.

NOTE: OpenCorpora periodically provides updates for this data. Checkout C<opencorpora-update-tokenizer> script that comes with this distribution.

The algorithm is this:

=over 4

=item 1. Split text into chars.

=item 2. Iterate over the chars from left to right.

=item 3. For every char get its context (see L<CONTEXT>).

=item 4. Find likelihood for the context in vectors file (see L<VECTORS FILE>) or use the default value - 0.5.

=back

=head2 CONTEXT

See L<Lingua::RU::OpenCorpora::Tokenizer::Context>.

=head2 VECTORS FILE

Contains a list of vectors with likelihood values showing the chance that given vector is a token boundary.

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

=head2 new($args)

Constructs and initializes new tokenizer object.

Takes a hashref as an argument with the folowwing keys:

=over 4

=item data_dir

Path to a directory with OpenCorpora data. Optional. Defaults to distribution directory (see L<File::ShareDir>).

=item prefixes, hyphens, exceptions, vectors

Data objects. Optional. You can provide any of those (or none of them). Default is to create an object from the data that comes with the distribution.

=back

=head2 tokens($text [, $options])

Takes text as input and splits it into tokens. Returns a reference to an array of tokens.

You can also pass a hashref with options as a second argument. Current options:

=over 4

=item threshold

Minimal likelihood value for tokens boundary. Boundaries with lower likelihood are excluded from consideration.

Default value is 1, which makes tokenizer do splitting only when it's confident.

=back

=head2 tokens_bounds($text)

Takes text as input and finds bounds of tokens in the text. It doesn't split the text into tokens, it just marks where tokens could be.

Returns an arrayref of arrayrefs. Inner arrayref consists of two elements: boundary position in text and likelihood.

=head2 bounds($text)

Convenience alias for C<tokens_bounds()>.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer::Updater>

L<http://mathlingvo.ru/nlpseminar/archive/s_49>

=head1 AUTHOR

OpenCorpora.org team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
