package Lingua::RU::OpenCorpora::Tokenizer::Vectors;

use strict;
use warnings;
use parent 'Lingua::RU::OpenCorpora::Tokenizer::List';

our $VERSION = 0.06;

sub new {
    my($class, $args) = @_;

    $args ||= {};

    $class->SUPER::new({%$args, list => 'vectors'});
}

sub in_list { $_[0]->{data}{$_[1]} }

sub _write_parsed_data {
    my $self = shift;

    $self->_write_compressed_data(
        join "\n",
        map join(' ', $_, $self->{data}{$_}),
        keys %{ $self->{data} }
    );
}

sub _parse_list {
    my($self, $list) = @_;

    my $parsed = +{ map split, @$list };
    chomp %$parsed;

    $parsed;
}

1;

__END__

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer::Vectors - represents a file with vectors

=head1 DESCRIPTION

This module inherits most of its code from L<Lingua::RU::OpenCorpora::Tokenizer::List>.

The reason to put this code into a separate class is that vectors file has a slightly different format and needs to be processed in a slightly different manner.

=head1 METHODS

=head2 new($args)

Constructor.

Takes an optional hashref with arguments:

=over 4

=item data

Optional. A hashref with vectors and probabilities to load into the module. Note that if you provide this argument then the module won't read vectors file.

Use it to override what have in your files. Can be useful when evaluating how the tokenizer perfroms.

=item data_dir

Path to the directory where vectors file is stored. Defaults to distribution directory (see L<File::ShareDir>).

=back

=head2 in_list($vector)

Given a vector, returns its probability or undef if the vector is unknown.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer::List>

L<Lingua::RU::OpenCorpora::Tokenizer::Updater>

L<Lingua::RU::OpenCorpora::Tokenizer>

=head1 AUTHOR

OpenCorpora team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
