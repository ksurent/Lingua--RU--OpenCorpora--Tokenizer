package Lingua::RU::OpenCorpora::Tokenizer::Model;

use utf8;
use strict;
use warnings;

use Carp ();
use Lingua::RU::OpenCorpora::Tokenizer::Vectors;
use Lingua::RU::OpenCorpora::Tokenizer::Context;

our $VERSION = 0.06;

sub new {
    my($class, $args) = @_;

    bless {%$args}, $class;
}

sub train {
    my($self, $corpus) = @_;

    for my $item (@$corpus) {
        my $bound = $self->_get_bounds_from_tokens($item);

        my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
            text       => $item->{text},
            hyphens    => $self->{hyphens},
            exceptions => $self->{exceptions},
            prefixes   => $self->{prefixes},
        });

        while($ctx->has_next) {
            my $current = $ctx->next;
            my $vec     = $current->{vector};

            $self->{vector}{$vec}++;
            $self->{bound}{$vec}++ if exists $bound->{$current->{pos}};
        }
    }

    for my $vec (keys %{ $self->{vector} }) {
        $self->{data}{$vec} = exists $self->{bound}{$vec}
            ? $self->{bound}{$vec} / $self->{vector}{$vec}
            : 0;
    }

    return;
}

# TODO i believe there's room for improvment here
sub _get_bounds_from_tokens {
    my($self, $item) = @_;

    my %bound;
    my $pos = 0;
    for my $token (@{ $item->{tokens} }) {
        while(substr($item->{text}, $pos, length $token) ne $token) {
            $pos++;

            # shouldn't happen...
            Carp::croak "Strange token: [$token] in sentence [$item->{text}]" if $pos > length $item->{text};
        }
        $bound{$pos + length($token) - 1} = undef;
        $pos += length $token;
    }

    \%bound;
}

sub save {
    my $self = shift;

    my $vectors = Lingua::RU::OpenCorpora::Tokenizer::Vectors->new({
        data_dir => $self->{data_dir},
        data     => $self->{data},
    });
    $vectors->_write_parsed_data;

    return;
}

1;

__END__

=encoding UTF-8

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer::Model - create vectors from corpus

=head1 DESCRIPTION

This module enables you to train tokenizer on your own data. Given a corpus it outputs a file with vectors and probabilities.

=head1 SYNOPSIS

    my $trainer = Lingua::RU::OpenCorpora::Tokenizer::Model->new({
        hyphens    => $hyphens,
        prefixes   => $prefixes,
        exceptions => $exceptions,
    });
    $trainer->train($corpus);
    $trainer->save_vectors;

=head1 METHODS

=head2 new($args)

Constructor.

Takes a hashref as an argument with the following keys:

=over 4

=item hyphens, prefixes, exceptions

Data objects. All required. See L<Lingua::RU::OpenCorpora::Tokenizer::List>.

=item data_dir

Path to a directory with OpenCorpora data. Optional. Defaults to distribution directory (see L<File::ShareDir>).

=back

=head2 train($corpus)

Computes vectors and probabilities for C<$corpus>.

C<$corpus> is an arrayref of hashrefs with the following keys:

=over 4

=item text

Raw input text.

=item tokens

Gold standard tokenization. An arrayref of tokens.

=back

Example:

    $corpus = [
        {
            text   => "Здравствуй, мир!",              # original text
            tokens => ["Здравствуй", ",", "мир", "!"], # gold standard tokenization
        },
        ...
    ];

=head2 save_vectors

Dump trained model to disk. Output file can be later picked up by L<Lingua::RU::OpenCorpora::Tokenizer::Vectors>.

Respects C<data_dir> option.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer::Vectors>

L<Lingua::RU::OpenCorpora::Tokenizer::Evaluate>

L<Lingua::RU::OpenCorpora::Tokenizer>

=head1 AUTHOR

OpenCorpora team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
