package Lingua::RU::OpenCorpora::Tokenizer::List;

use strict;
use warnings;

our $VERSION = 0.03;

use IO::File;
use File::Spec;
use Carp qw(croak);
use IO::Uncompress::Gunzip;
use File::ShareDir qw(dist_dir);

sub new {
    my($class, $name, $args) = @_;

    croak "List name unspecified" unless defined $name;

    $args             ||= {};
    $args->{data_dir} ||= dist_dir('Lingua-RU-OpenCorpora-Tokenizer');

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

    my($class, $error, @args);

    my $fn = $self->_path;
    if($fn =~ /\.gz$/) {
        $class = 'IO::Uncompress::Gunzip';
        $error = \$IO::Uncompress::Gunzip::GunzipError;
        @args  = ();
    }
    else {
        $class = 'IO::File';
        $error = \$!;
        @args  = ('<:utf8');
    }

    my $fh = $class->new($fn, @args) or die "$fn: $$error";
    chomp($self->{version} = $fh->getline);
    $self->_parse_list([$fh->getlines]);
    $fh->close;

    return;
}

sub _parse_list {
    my($self, $list) = @_;

    chomp @$list;
    $self->{data} = +{ map {$_,undef} @$list };

    return;
}

sub _path {
    my $self = shift;

    for('.gz', '') { # backwards compatibility
        my $fn = File::Spec->catfile($self->{data_dir}, $self->{name} . $_);

        return $fn if -e $fn;
    }

    Carp::croak "Couldn't find file for '$self->{name}'";
}

1;
