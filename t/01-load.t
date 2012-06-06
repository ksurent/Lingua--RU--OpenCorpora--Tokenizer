use Test::More tests => 6;

BEGIN {
    use_ok 'Lingua::RU::OpenCorpora::Tokenizer';
    use_ok 'Lingua::RU::OpenCorpora::Tokenizer::List';
    use_ok 'Lingua::RU::OpenCorpora::Tokenizer::Model';
    use_ok 'Lingua::RU::OpenCorpora::Tokenizer::Updater';
    use_ok 'Lingua::RU::OpenCorpora::Tokenizer::Context';
    use_ok 'Lingua::RU::OpenCorpora::Tokenizer::Vectors';
}
