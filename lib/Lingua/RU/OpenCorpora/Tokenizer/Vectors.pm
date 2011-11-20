package Lingua::RU::OpenCorpora::Tokenizer::Vectors;

use strict;
use warnings;
use parent 'Lingua::RU::OpenCorpora::Tokenizer::List';

our $VERSION = 0.04;

use File::ShareDir qw(dist_dir);

sub new {
    my($class, $args) = @_;

    $args             ||= {};
    $args->{data_dir} ||= dist_dir('Lingua-RU-OpenCorpora-Tokenizer');

    my $self = $class->SUPER::new('vectors', $args);

    $self;
}

sub in_list {
    my($self, $value) = @_;

    $self->{data}{$value};
}

sub _parse_list {
    my($self, $list) = @_;

    chomp @$list;
    $self->{data} = +{ map split, @$list };

    return;
}

1;
