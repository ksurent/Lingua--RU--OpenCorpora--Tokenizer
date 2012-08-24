use utf8;
no warnings qw(qw);
use open qw(:std :utf8);

use Test::More;
use Test::Deep;

use Lingua::RU::OpenCorpora::Tokenizer;

my @tests = (
    # exceptions
    [
        'Вася завел себе Яндекс.Кошелек',
        [qw(Вася завел себе Яндекс.Кошелек)],
    ],
    [
        'Петя сходил на концерт AC/DC',
        [qw(Петя сходил на концерт AC/DC)],
    ],
    [
        'Серёжа использует Yahoo! для поиска',
        [qw(Серёжа использует Yahoo! для поиска)],
    ],
    [
        q{Денис хочет поехать в Кот-д'Ивуар в отпуск},
        [qw(Денис хочет поехать в Кот-д'Ивуар в отпуск)],
    ],
    # tabs
    [
        "Привет,\tМир!",
        [qw(Привет , Мир !)],
    ],
    [
        "\tТаб",
        [qw(Таб)],
    ],
    [
        "Таб\t",
        [qw(Таб)],
    ],
    [
        "\tТаб\t",
        [qw(Таб)],
    ],
    # spaces
    [
        '    Пробелы',
        [qw(Пробелы)],
    ],
    [
        'Пробелы    ',
        [qw(Пробелы)],
    ],
    [
        '    Пробелы    ',
        [qw(Пробелы)],
    ],
);

plan tests => scalar @tests;

my $tokenizer = Lingua::RU::OpenCorpora::Tokenizer->new;

for my $t (@tests) {
    my $tokens = $tokenizer->tokens($t->[0]);
    cmp_deeply $tokens, $t->[1], "tokens: [$t->[0]]";
}
