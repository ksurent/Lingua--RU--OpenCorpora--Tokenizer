package Lingua::RU::OpenCorpora::Tokenizer::List;

use utf8;
use strict;
use warnings;

use Carp                   ();
use Encode                 ();
use File::Spec             ();
use File::ShareDir         ();
use IO::Compress::Gzip     ();
use IO::Uncompress::Gunzip ();

our $VERSION = 0.06;

sub data_version { 0.05 }

sub new {
    my($class, $args) = @_;

    $args->{data_dir} ||= File::ShareDir::dist_dir('Lingua-RU-OpenCorpora-Tokenizer');
    $args->{root_url} ||= 'http://opencorpora.org/files/export/tokenizer_data';

    my $self = bless {%$args}, $class;
    $self->_load_from_file unless defined $self->{data};

    $self;
}

sub in_list { exists $_[0]->{data}{lc $_[1]} }

sub _load_from_file {
    my $self = shift;

    my $fn = $self->_path;
    my $fh = IO::Uncompress::Gunzip->new($fn) or die "$fn: $IO::Uncompress::Gunzip::GunzipError";

    chomp($self->{version} = $fh->getline);

    my @data      = map lc Encode::decode('utf-8', $_), $fh->getlines;
    my $parsed    = $self->_parse_list(\@data);
    $self->{data} = $parsed;

    $fh->close;

    return;
}

sub _write_parsed_data {
    my $self = shift;

    $self->_write_compressed_data(join "\n", @{ $self->{data} });
}

sub _write_compressed_data {
    my($self, $new_data) = @_;

    my $fn = $self->_path;
    my $fh = IO::Compress::Gzip->new($fn, '>') or Carp::croak "$fn: $IO::Compress::Gzip::GzipError";
    $fh->print($new_data);
    $fh->close;
}

sub _parse_list {
    my($self, $list) = @_;

    +{ map { chomp; $_,undef } @$list };
}

sub _path {
    my $self = shift;

    File::Spec->catfile($self->{data_dir}, "$self->{list}.gz");
}

sub _url {
    my($self, $mode) = @_;

    $mode ||= 'file';

    my $url = join '/', $self->{root_url}, $self->data_version, $self->{list};
    if($mode eq 'file') {
        $url .= '.gz';
    }
    elsif($mode eq 'version') {
        $url .= '.latest';
    }

    $url;
}

1;

__END__

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer::List - represents a data file

=head1 DESCRIPTION

This module provides an API to access files that are used by tokenizer.

It's useful to know that this module actually has 2 versions: the code version and the data version. These versions do not depend on each other.

=head1 METHODS

=head2 new($args)

Constructor.

Takes a hashref as an argument:

=over 4

=item list

Required. List name is one of these: exceptions, prefixes and hyphens.

=item data_dir

Optional. Path to the directory where files are stored. Defaults to distribution directory (see L<File::ShareDir>).

=item data

Optional. An arrayref with list entries to load into the module. Note that if you provide this argument then the module won't read list file.

Use it to override what have in your files. Can be useful when evaluating how the tokenizer perfroms.

=back

=head2 in_list($value)

Checks if given value is in the list.

Returns true or false correspondingly.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer::Vectors>

L<Lingua::RU::OpenCorpora::Tokenizer::Updater>

L<Lingua::RU::OpenCorpora::Tokenizer>

=head1 AUTHOR

OpenCorpora team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
