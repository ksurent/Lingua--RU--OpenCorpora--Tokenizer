use utf8;
no warnings qw(qw);
use open qw(:std :utf8);

use Test::More;
use Test::Deep;
use Test::Exception;

use FindBin    ();
use File::Spec ();
use Lingua::RU::OpenCorpora::Tokenizer::List;
use Lingua::RU::OpenCorpora::Tokenizer::Model;

my $data_dir = File::Spec->catdir($FindBin::Bin, 'data');

my $hyphens = Lingua::RU::OpenCorpora::Tokenizer::List->new({
    list     => 'hyphens',
    data_dir => $data_dir,
});
my $prefixes = Lingua::RU::OpenCorpora::Tokenizer::List->new({
    list     => 'prefixes',
    data_dir => $data_dir,
});
my $exceptions = Lingua::RU::OpenCorpora::Tokenizer::List->new({
    list     => 'exceptions',
    data_dir => $data_dir,
});

my $model = Lingua::RU::OpenCorpora::Tokenizer::Model->new({
    corpus     => [],
    hyphens    => $hyphens,
    prefixes   => $prefixes,
    exceptions => $exceptions,
});

my @tests = (
    [
        {
            text   => 'Здравствуйте, я ваша тётя!',
            tokens => [qw(Здравствуйте , я ваша тётя !)],
        },
        #{11,undef, 12,undef, 14,undef, 19,undef, 24,undef, 25,undef},
        [11, 12, 14, 19, 24, 25],
    ],
    [
        {
            text   => 'Просто набор слов без пунктуации',
            tokens => [qw(Просто набор слов без пунктуации)],
        },
        #{5,undef, 11,undef, 16,undef, 20,undef, 31,undef},
        [5, 11, 16, 20, 31],
    ],
    [
        {
            text   => 'Хо-хо-хо',
            tokens => [qw(Хо-хо-хо)],
        },
        #{7,undef},
        [7],
    ],
    [
        {
            text   => 'Хо-хо-хо',
            tokens => [qw(Хо-хо-хо хо)],
            dies   => 1,
        },
        #{},
        [],
    ],
);

plan tests => scalar @tests;

for my $t (@tests) {
    if($t->[0]{dies}) {
        dies_ok { $model->_get_bounds_from_tokens($t->[0]) } "bounds exception: [$t->[0]{text}]";
    }
    else {
        my @bounds = $model->_get_bounds_from_tokens($t->[0]);
        cmp_deeply \@bounds, $t->[1], "bounds: [$t->[0]{text}]";
    }
}
