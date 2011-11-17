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
            [9,  1],
            [21, 1],
            [22, 1],
        ],
    ],
    [
        'Это предложение чуть сложнее, но все ещё простое.',
        [
            [2,  1],
            [14, 1],
            [19, 1],
            [27, 1],
            [28, 1],
            [31, 1],
            [35, 1],
            [39, 1],
            [47, 1],
            [48, 1],
        ],
    ],
    [
        'Текст с двоеточием на конце:',
        [
            [4,  1],
            [6,  1],
            [17, 1],
            [20, 1],
            [26, 1],
        ],
    ],
    [
        '«Школа злословия» учит прикусить язык',
        [
            [0,  1],
            [5,  1],
            [15, 1],
            [16, 1],
            [21, 1],
            [31, 1],
            [36, 1],
        ],
    ],
);

my $tokenizer = Lingua::RU::OpenCorpora::Tokenizer->new;

for my $t (@tests) {
    my $bounds = $tokenizer->tokens_bounds($t->[0]);
    for(my $i = 0; my $tt = $t->[1][$i]; $i++) {
        is $bounds->[$i][0], $tt->[0], "boundary: $t->[0]";
        delta_within $bounds->[$i][1], $tt->[1], 0.15, "probability: $t->[0]";
    }
}
