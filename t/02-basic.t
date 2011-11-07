use utf8;
no warnings qw(qw);
use open qw(:std :utf8);

use Test::More;
use Test::Number::Delta;
use Test::Deep;

use Lingua::RU::OpenCorpora::Tokenizer;

plan skip_all => 'Tests disabled for now';

my @tests = (
    [
        'Простейшее предложение.',
        [
            [11, 1],
            [23, 1],
            [24, 1],
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
            [50, 1],
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
    [
        'Текст с двоеточием на конце:',
        [
            [6,  1],
            [8,  1],
            [19, 1],
            [22, 1],
            [28, 1],
        ],
        [qw(
            Текст
            с
            двоеточием
            на
            конце
            :
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
