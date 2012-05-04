use utf8;
use open qw(:std :utf8);

use Test::More qw(no_plan);
use Test::Exception;

use FindBin    ();
use File::Spec ();
use Lingua::RU::OpenCorpora::Tokenizer::List;
use Lingua::RU::OpenCorpora::Tokenizer::Vectors;

my %tests = (
    ok => {
        exceptions => [qw(
            Yahoo!
            AC/DC
        )],
        prefixes => [qw(
            квази
            анти
        )],
        hyphens => [qw(
            а-ля
            акустико-электрическая
            аль-джазира
        )],
        vectors => [qw(
            0
            8
            16
        )],
    },
    nok => {
        exceptions => [qw(
            хитрое_слово_с_нижним_подчеркиванием
        )],
        prefixes => [qw(
            несуществующийпрефикс
        )],
        hyphens => [qw(
            по-умолчанию
        )],
        vectors => [qw(
            9999999999
            -1
        )],
    },
);

# test default location
for my $list (qw(exceptions prefixes hyphens)) {
    my $obj;
    lives_ok { $obj = Lingua::RU::OpenCorpora::Tokenizer::List->new({list => $list}) } "$list: constructor";

    ok defined $obj, "$list: defined";
    ok defined $obj->{version}, "$list: version";

    for my $t (@{ $tests{ok}->{$list} }) {
        ok $obj->in_list($t), "$list: [$t]";
    }

    for my $t (@{ $tests{nok}->{$list} }) {
        ok !$obj->in_list($t), "$list: [$t]";
    }
}

my $obj;
lives_ok { $obj = Lingua::RU::OpenCorpora::Tokenizer::Vectors->new } 'vectors: constructor';

ok defined $obj, 'vectors: defined';
ok defined $obj->{version}, 'vectors: version';

for my $t (@{ $tests{ok}->{vectors} }) {
    ok defined $obj->in_list($t), "vectors: [$t]";
}

for my $t (@{ $tests{nok}->{vectors} }) {
    ok !defined $obj->in_list($t), "vectors: [$t]";
}

# test custom location

my $data_dir = File::Spec->catdir($FindBin::Bin, 'data');

for my $list (qw(exceptions prefixes hyphens)) {
    my $obj;
    lives_ok {
        $obj = Lingua::RU::OpenCorpora::Tokenizer::List->new({
            list     => $list,
            data_dir => $data_dir,
        })
    } "$list: constructor with data_dir";

    ok defined $obj, "$list: defined with custom data_dir";
    ok defined $obj->{version}, "$list: version with custom data_dir";

    for my $t (@{ $tests{ok}->{$list} }) {
        ok $obj->in_list($t), "$list: [$t] with custom data_dir";
    }

    for my $t (@{ $tests{nok}->{$list} }) {
        ok !$obj->in_list($t), "$list: [$t] with custom data_dir";
    }
}

lives_ok {
    $obj = Lingua::RU::OpenCorpora::Tokenizer::Vectors->new({
        data_dir => $data_dir,
    })
} 'vectors: constructor with data_dir';

ok defined $obj, 'vectors: defined with custom data_dir';
ok defined $obj->{version}, 'vectors: version with custom data_dir';

for my $t (@{ $tests{ok}->{vectors} }) {
    ok defined $obj->in_list($t), "vectors: [$t] with custom data_dir";
}

for my $t (@{ $tests{nok}->{vectors} }) {
    ok !defined $obj->in_list($t), "vectors: [$t] with custom data_dir";
}
