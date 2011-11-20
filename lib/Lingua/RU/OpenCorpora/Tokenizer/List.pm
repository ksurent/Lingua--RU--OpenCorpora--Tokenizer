package Lingua::RU::OpenCorpora::Tokenizer::List;

use strict;
use warnings;

our $VERSION = 0.04;

use IO::File;
use File::Spec;
use Carp qw(croak);
use Encode qw(decode);
use IO::Uncompress::Gunzip;
use File::ShareDir qw(dist_dir);

sub data_version { 0.03 }

sub new {
    my($class, $name, $args) = @_;

    croak "List name unspecified" unless defined $name;

    $args             ||= {};
    $args->{data_dir} ||= dist_dir('Lingua-RU-OpenCorpora-Tokenizer');
    $args->{root_url} ||= 'http://opencorpora.org/files/export/tokenizer_data';

    my $self = bless {
        %$args,
        name => $name,
    }, $class;

    $self->_load;

    $self;
}

sub in_list {
    my($self, $value) = @_;

    exists $self->{data}{$value};
}

sub _load {
    my $self = shift;

    my $fn = $self->_path;
    my $fh = IO::Uncompress::Gunzip->new($fn) or die "$fn: $IO::Uncompress::Gunzip::GunzipError";

    chomp($self->{version} = $fh->getline);

    my @data = map decode('utf-8', $_), $fh->getlines;
    $self->_parse_list(\@data);

    $fh->close;

    return;
}

sub _update {
    my($self, $new_data) = @_;

    my $fn = $self->_path;
    my $fh = IO::File->new($fn, '>') or croak "$fn: $!";
    $fh->binmode;
    $fh->print($new_data);
    $fh->close;

    $self->_load;
}


sub _parse_list {
    my($self, $list) = @_;

    chomp @$list;
    $self->{data} = +{ map {$_,undef} @$list };

    return;
}

sub _path {
    my $self = shift;

    File::Spec->catfile($self->{data_dir}, "$self->{name}.gz");
}

sub _url {
    my($self, $mode) = @_;

    $mode ||= 'file';

    my $url = join '/', $self->{root_url}, $self->data_version, $self->{name};
    if($mode eq 'file') {
        $url .= '.gz';
    }
    elsif($mode eq 'version') {
        $url .= '.latest';
    }

    $url;
}

1;
