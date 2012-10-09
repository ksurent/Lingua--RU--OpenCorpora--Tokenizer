use utf8;
no warnings qw(qw);
use open qw(:std :utf8);

use Test::More qw(no_plan);
use Test::Exception;
use Test::Deep;

use FindBin    ();
use File::Spec ();
use Lingua::RU::OpenCorpora::Tokenizer::List;
use Lingua::RU::OpenCorpora::Tokenizer::Context;

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

my @tests = (
    ['Привет', 6],
    ['', 0],
);

for my $t (@tests) {
    my $ctx = Lingua::RU::OpenCorpora::Tokenizer::Context->new({
        text       => $t->[0],
        hyphens    => $hyphens,
        prefixes   => $prefixes,
        exceptions => $exceptions,
    });

    my $iterations = 0;
    while(my $current = $ctx->next) {
        ok defined $current, "context: [$t->[0]]";
        $iterations++;
    }

    is $iterations, $t->[1], "iterations: [$t->[0]]";
}
