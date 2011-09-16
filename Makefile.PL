use inc::Module::Install;

all_from 'lib/Lingua/RU/OpenCorpora/Tokenizer.pm';
readme_from 'lib/Lingua/RU/OpenCorpora/Tokenizer.pm';

requires 'LWP::UserAgent';
requires 'File::ShareDir';
requires 'IO::Uncompress::Gunzip';

test_requires 'Test::Deep';
test_requires 'Test::Number::Delta';

install_script 'opencorpora-update-tokenizer';
install_share  'share';

WriteAll;
