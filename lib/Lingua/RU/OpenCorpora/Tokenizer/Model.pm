package Lingua::RU::OpenCorpora::Tokenizer::Model;

use utf8;
use strict;
use warnings;

use Carp ();
use Text::Table;
use Lingua::RU::OpenCorpora::Tokenizer::Vectors;
use Lingua::RU::OpenCorpora::Tokenizer::Context;

our $VERSION = 0.06;

sub new {
    my($class, $args) = @_;

    bless {%$args}, $class;
}

sub train {
    my $self = shift;

    my $i = 0;
    for my $item (@{ $self->{corpus} }) {
        my $bound = $self->_get_bounds_from_tokens($item);

        my $fold_id = $i++ % $self->{nfolds};
        my $fold    = $self->{cross}[$fold_id] ||= {};

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
            $fold->{vector}{$vec}++;
            if(exists $bound->{$current->{pos}}) {
                $self->{bound}{$vec}++;
                $fold->{bound}{$vec}++;
            }
        }
    }

    for my $vec (keys %{ $self->{vector} }) {
        $self->{data}{$vec} = ($self->{bound}{$vec} || 0) / $self->{vector}{$vec};

        for my $fold_id (0 .. $self->{nfolds}-1) {
            my $fold = $self->{cross}[$fold_id];

            $fold->{data}{$vec} = ($fold->{bound}{$vec} || 0) / $fold->{vector}{$vec}
                if $fold->{vector}{$vec};
        }
    }

    return;
}

sub evaluate {
    my $self = shift;

    my $i = 0;
    for my $item (@{ $self->{corpus} }) {
        my $bound = $self->_get_bounds_from_tokens($item);

        my $fold_id = $i++ % $self->{nfolds};
        my $fold    = $self->{cross}[$fold_id];

        my $vectors = Lingua::RU::OpenCorpora::Tokenizer::Vectors->new({
            data => $self->{cross}[$fold_id]{data},
        });
        my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
            text       => $item->{text},
            hyphens    => $self->{hyphens},
            prefixes   => $self->{prefixes},
            exceptions => $self->{exceptions},
            vectors    => $vectors,
        });
        while($ctx->has_next) {
            my $current = $ctx->next;
            next if $current->{is_space};

            $fold->{total}++ if exists $bound->{$current->{pos}};

            for my $threshold (@{ $self->{thresholds} }) {
                if(exists $bound->{$current->{pos}}) {
                    $fold->{truepos}{$threshold}++ if $current->{probability} >= $threshold;
                }
                elsif($current->{probability} >= $threshold) {
                    $fold->{falsepos}{$threshold}++;
                }
            }
        }
    }

    for my $threshold (@{ $self->{thresholds} }) {
        my $stats = $self->{stats}{$threshold} ||= {};

        for my $fold_id (0 .. $self->{nfolds}-1) {
            my $fold     = $self->{cross}[$fold_id];

            my $total    = $fold->{total}                || 0;
            my $truepos  = $fold->{truepos}{$threshold}  || 0;
            my $falsepos = $fold->{falsepos}{$threshold} || 0;

            $stats->{total}     += $total;
            $stats->{truepos}   += $truepos;
            $stats->{falsepos}  += $falsepos;

            $stats->{recall}    += $truepos / $total;
            $stats->{precision} += $truepos / ($truepos + $falsepos);
        }

        $stats->{$_} /= $self->{nfolds}
            for qw(total truepos falsepos precision recall);

        $stats->{F1} = 2 * $stats->{precision} * $stats->{recall} / ($stats->{precision} + $stats->{recall});
    }

    return;
}

sub print_stats {
    my $self = shift;

    my $best;

    my $tt = Text::Table->new(
        'Threshold',
        'Precision',
        'Recall',
        'F1-score',
        'Bounds',
        'True positive',
        'False positive',
    );
    for my $threshold (@{ $self->{thresholds} }) {
        my $stats = $self->{stats}{$threshold};
        $tt->load([
            $threshold,
            $stats->{precision},
            $stats->{recall},
            $stats->{F1},
            $stats->{total},
            $stats->{truepos},
            $stats->{falsepos},
        ]);

        $best = $threshold if not defined $best or $stats->{F1} > $best;
    }

    print "$tt\n";
    print "Total vectors: ", scalar keys %{ $self->{data} }, "\n";
    print "Best threshold: $best\n";

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
