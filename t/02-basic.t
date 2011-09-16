use utf8;
no warnings qw(qw);
use open qw(:std :utf8);

use Test::More qw(no_plan);
use Test::Number::Delta;
use Test::Deep;

use Lingua::RU::OpenCorpora::Tokenizer;

my @tests = (
    [
        'Простейшее предложение.',
        [
            [11, 1],
            [23, 1],
            [24, 0.5],
        ],
        [qw(
            Простейшее
            предложение
            .
        )],
    ],
    [
        'Это предложение чуть сложнее, но все ещё простое.',
        [
            [4,  1],
            [16, 1],
            [21, 1],
            [29, 1],
            [30, 1],
            [33, 1],
            [37, 1],
            [41, 1],
            [49, 1],
            [50, 0.5],
        ],
        [qw(
            Это
            предложение
            чуть
            сложнее
            ,
            но
            все
            ещё
            простое
            .
        )],
    ],
);

my $tokenizer = Lingua::RU::OpenCorpora::Tokenizer->new;

for my $t (@tests) {
    my $bounds = $tokenizer->tokens_bounds($t->[0]);
    for(my $i = 0; my $tt = $t->[1][$i]; $i++) {
        is $bounds->[$i][0], $tt->[0], "boundary: $t->[0]";
        delta_within $bounds->[$i][1], $tt->[1], 0.01, "probability: $t->[0]";
    }

    my $tokens = $tokenizer->tokens($t->[0]);
    cmp_deeply $tokens, $t->[2], "tokens: $t->[0]";
}
