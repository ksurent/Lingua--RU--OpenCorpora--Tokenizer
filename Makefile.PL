use inc::Module::Install;

all_from 'lib/Lingua/RU/OpenCorpora/Tokenizer.pm';
readme_from 'lib/Lingua/RU/OpenCorpora/Tokenizer.pm';

requires 'parent';
requires 'Text::Table';
requires 'LWP::UserAgent';
requires 'File::ShareDir';
requires 'IO::Compress::Gzip';
requires 'IO::Uncompress::Gunzip';
requires 'Array::Iterator' => 0.08;

test_requires 'Test::Deep';
test_requires 'Test::Exception';

install_script 'opencorpora-update-tokenizer';
install_share  'share';

homepage   'http://opencorpora.org/';
repository 'https://github.com/ksurent/Lingua--RU--OpenCorpora--Tokenizer';
bugtracker 'https://github.com/ksurent/Lingua--RU--OpenCorpora--Tokenizer/issues';

WriteAll;
