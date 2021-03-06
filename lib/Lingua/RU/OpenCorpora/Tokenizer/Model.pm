package Lingua::RU::OpenCorpora::Tokenizer::Model;

use utf8;
use strict;
use warnings;

use Carp ();
use Text::Table;
use Lingua::RU::OpenCorpora::Tokenizer::Vectors;
use Lingua::RU::OpenCorpora::Tokenizer::Context;

our $VERSION = 0.07;

# default likelihood thresholds for model evaluation
my @THRESHOLDS = (
    .00, .01, .05, .10,
    .15, .20, .25, .30,
    .35, .40, .45, .50,
    .55, .60, .65, .70,
    .75, .80, .85, .90,
    .95, .99, 1.0,
);

# default number of folds in cross-validation
my $NFOLDS = 10;

sub new {
    my($class, $args) = @_;

    bless {
        thresholds => \@THRESHOLDS,
        nfolds     => $NFOLDS,
        %$args,
    }, $class;
}

sub train {
    my $self = shift;

    my $i = 0;
    for my $item (@{ $self->{corpus} }) {
        # ethalon
        my $bound = {map +($_,undef), $self->_get_bounds_from_tokens($item)};

        # pre-calculate some data for cross-validation
        my $fold_id = $i++ % $self->{nfolds};
        my $fold    = $self->{cross}[$fold_id] ||= {};

        my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
            text       => $item->{text},
            hyphens    => $self->{hyphens},
            exceptions => $self->{exceptions},
            prefixes   => $self->{prefixes},
        });
        while(my $current = $ctx->next) {
            my $vec = $current->{vector};

            $self->{vector}{$vec}++; # total vector frequency
            $fold->{vector}{$vec}++; # frequency within cross-validation fold
            if(exists $bound->{$current->{pos}}) {
                $self->{bound}{$vec}++; # total bound frequency
                $fold->{bound}{$vec}++; # bound frequency within cross-validation fold
            }
        }
    }

    for my $vec (keys %{ $self->{vector} }) {
        # likelihood of given vector to be a token bound
        my $likelihood = ($self->{bound}{$vec} || 0) / $self->{vector}{$vec};
        $self->{data}{$vec} = $likelihood;
        $self->{confident}++ if $likelihood == 0 or $likelihood == 1;

        # likelihood of given vector to be a token bound within fold
        for my $fold_id (0 .. $self->{nfolds}-1) {
            my $fold = $self->{cross}[$fold_id];

            $fold->{data}{$vec} = ($fold->{bound}{$vec} || 0) / $fold->{vector}{$vec}
                if $fold->{vector}{$vec};
        }
    }

    return;
}

# evaluate model using K-fold cross-validation technique
sub evaluate {
    my $self = shift;

    my @vectors = map Lingua::RU::OpenCorpora::Tokenizer::Vectors->new({data => $self->{cross}[$_]{data}}),
                  0 .. $self->{nfolds} - 1;

    my $i = 0;
    for my $item (@{ $self->{corpus} }) {
        # ethalon
        my $bound = {map +($_,undef), $self->_get_bounds_from_tokens($item)};

        my $fold_id = $i++ % $self->{nfolds};
        my $fold    = $self->{cross}[$fold_id];

        my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
            text       => $item->{text},
            hyphens    => $self->{hyphens},
            prefixes   => $self->{prefixes},
            exceptions => $self->{exceptions},
            vectors    => $vectors[$fold_id],
        });
        while(my $current = $ctx->next) {
            # space is *always* a bound so it doesn't really make sense to count it
            next if $current->{is_space};

            $fold->{total}++ if exists $bound->{$current->{pos}};

            for my $threshold (@{ $self->{thresholds} }) {
                if(exists $bound->{$current->{pos}}) {
                    # increment true positives as this a correct bound and its likelihood is higher than the threshold
                    $fold->{truepos}{$threshold}++ if $current->{likelihood} >= $threshold;
                }
                elsif($current->{likelihood} >= $threshold) {
                    # increment false positives as this is not a bound but still has high likelihood
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

            # http://en.wikipedia.org/wiki/Precision_and_recall
            $stats->{recall}    += $truepos / $total;
            $stats->{precision} += $truepos / ($truepos + $falsepos);
        }

        # macro-average evaluation results
        $stats->{$_} /= $self->{nfolds}
            for qw(total truepos falsepos precision recall);

        # http://en.wikipedia.org/wiki/F1_Score
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
        $tt->add(
            $threshold,
            $stats->{precision},
            $stats->{recall},
            $stats->{F1},
            $stats->{total},
            $stats->{truepos},
            $stats->{falsepos},
        );

        $best = $threshold if not defined $best or $stats->{F1} > $best;
    }

    print $tt, "\n";
    print "Total vectors: ", scalar keys %{ $self->{data} }, "\n";
    # 'confidence' here is the percentage of vectors that have likelihood of strictly 0 or 1
    print "Model confidence: ", $self->{confident} / keys(%{ $self->{data} }) * 100, "%\n";
    print "Best threshold: $best\n";

    return;
}


# TODO i believe there's room for improvment here
sub _get_bounds_from_tokens {
    my($self, $item) = @_;

    my @bounds;
    my $offset = 0;
    for my $token (@{ $item->{tokens} }) {
        my $bound_pos = index $item->{text}, $token, $offset;

        # shouldn't happen...
        Carp::croak "Strange token: [$token] in sentence [$item->{text}]"
            if $bound_pos < 0;

        my $len  = length $token;
        $offset += $len;
        push @bounds, $bound_pos + $len - 1;
    }

    @bounds;
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

=head2 HOW IT WORKS

Training algorithm is the following:

=over 8

=item 1. compute L<context|Lingua::RU::OpenCorpora::Tokenizer::Context> for each character of each sentence in the training set

=item 2. count how many times each context occurs in the training set

=item 3. count how many times each context was marked as a token bound in the training set

=item 4. for each context compute likelihood of it being a token bound

=back

Basically, what you get after training is a model that is able to tell you in what circumstances given character should be considered a token bound. For instance, it answers questions like "What's the likelihood of a colon character surrounded by two digits and spaces being a token bound?". Or "What's the likelihood of a cyrillic letter preceded by a bunch of other cyrillic letters and a space, followed by dot, being a token bound?".

For a more formal explanation see L<this paper|http://opencorpora.org/doc/articles/2012_MIEM.pdf> (unfortunately, in Russian only).

=head1 SYNOPSIS

    my $model = Lingua::RU::OpenCorpora::Tokenizer::Model->new({
        corpus     => $corpus,
        hyphens    => $hyphens,
        prefixes   => $prefixes,
        exceptions => $exceptions,
    });
    $model->train;
    $model->save;

=head1 METHODS

=head2 new($args)

Constructor.

Takes a hashref as an argument with the following keys:

=over 4

=item corpus

Input data to train on. Required. An arrayref of hashrefs with the following keys:

=over 4

=item text

Raw input text.

=item tokens

Gold standard tokenization. An arrayref of ordered tokens.

=back

Example:

    $corpus = [
        {
            text   => "Здравствуй, мир!",              # original text
            tokens => ["Здравствуй", ",", "мир", "!"], # gold standard tokenization
        },
        ...
    ];

=item hyphens, prefixes, exceptions

Data objects. All required. See L<Lingua::RU::OpenCorpora::Tokenizer::List>.

=item thresholds

An arrayref of likelihood thresholds. Needed for model evaluation. Optional. Default is:

C<[qw/0.0 0.01 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 0.99 1.0/]>.

=item nfolds

Number of folds to perform in cross-validation. Optional. Default is 10.

=item data_dir

Path to a directory with OpenCorpora data. Optional. Defaults to distribution directory (see L<File::ShareDir>).

=back

=head2 train

Computes vectors and likelihoods.

=head2 save

Dump trained model to disk. Output file can be later picked up by L<Lingua::RU::OpenCorpora::Tokenizer::Vectors>.

Respects C<data_dir> option.

Must not be called before C<train>.

=head2 evaluate

Computes a bunch of metrics to evaluate current model using cross-validation technique (see L<http://en.wikipedia.org/wiki/Cross-validation_(statistics)>).

Respects C<thresholds> attribute.

These metrics include:

=over 4

=item precision

=item recall

See L<http://en.wikipedia.org/wiki/Precision_and_recall>.

=item F1-score

See L<en.wikipedia.org/wiki/F1_score>.

=item true positives

=item false positives

See L<http://en.wikipedia.org/wiki/Type_I_and_type_II_errors>.

=item bounds

Number of token bounds found.

=back

Above metrics will be calculated for every threshold that was specified via C<threshold> argument in constructor.

Must not be called before C<train>.

=head2 print_stats

Prints a table with results from C<evaluate> call.

Must not be called before C<evaluate>.

=head1 TODO

Add better, more verbose documentation.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer::Vectors>

L<Lingua::RU::OpenCorpora::Tokenizer>

=head1 AUTHOR

OpenCorpora team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
