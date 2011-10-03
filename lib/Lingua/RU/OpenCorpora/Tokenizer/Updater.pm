package Lingua::RU::OpenCorpora::Tokenizer::Updater;

use strict;
use warnings;

use File::Spec;
use LWP::UserAgent;
use Carp qw(croak);
use File::ShareDir qw(dist_dir);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

our $VERSION = 0.03;

sub new {
    my $class = shift;

    my $self = bless {
        vectors_latest    => 'http://opencorpora.org/files/export/tokenizer_data/vectors.latest',
        vectors_url       => 'http://opencorpora.org/files/export/tokenizer_data/vectors.gz',
        hyphens_latest    => 'http://opencorpora.org/files/export/tokenizer_data/hyphens.latest',
        hyphens_url       => 'http://opencorpora.org/files/export/tokenizer_data/hyphens.gz',
        exceptions_latest => 'http://opencorpora.org/files/export/tokenizer_data/exceptions.latest',
        exceptions_url    => 'http://opencorpora.org/files/export/tokenizer_data/exceptions.gz',
        prefixes_latest   => 'http://opencorpora.org/files/export/tokenizer_data/prefixes.latest',
        prefixes_url      => 'http://opencorpora.org/files/export/tokenizer_data/prefixes.gz',

    }, $class;
    $self->_init;

    $self;
}

sub vectors_update_available    { $_[0]->_update_available('vectors')    }
sub hyphens_update_available    { $_[0]->_update_available('hyphens')    }
sub exceptions_update_available { $_[0]->_update_available('exceptions') }
sub prefixes_update_available   { $_[0]->_update_available('prefixes')   }

sub update_vectors    { $_[0]->_update('vectors')    }
sub update_hyphens    { $_[0]->_update('hyphens')    }
sub update_exceptions { $_[0]->_update('exceptions') }
sub update_prefixes   { $_[0]->_update('prefixes')   }

sub _init {
    my $self = shift;

    my $ua = LWP::UserAgent->new(
        agent     => __PACKAGE__ . ' ' . $VERSION . ', ',
        env_proxy => 1,
    );
    $ua->default_header('Accept-Encoding' => 'gzip, identity');
    my %m_spec = (
        m_code       => 200,
        m_media_type => 'application/x-gzip',
    );
    $ua->add_handler(
        response_header => sub { $_[0]->{default_add_content} = 1 },
        %m_spec,
    );
    $ua->add_handler(
        response_done => \&_uncompress,
        %m_spec,
    );
    $self->{ua} = $ua;

    $self->_get_current_version($_) for qw(vectors hyphens prefixes exceptions);

    return;
}

sub _get_current_version {
    my($self, $mode) = @_;

    my $file = $self->_path($mode);
    open $fh, '<', $file or croak "$file: $!";
    $self->{"${mode}_current"} = <$fh>;
    chomp $self->{"${mode}_current"};
    close $fh;

    return;
}

sub _update_available {
    my($self, $mode) = @_;

    my $res = $self->{ua}->get($self->{"${mode}_latest"});
    return unless $res->is_success;
    $self->{"${mode}_latest"} = $res->content;

    $self->{"${mode}_latest"} gt $self->{"${mode}_current"};
}

sub _update {
    my($self, $mode) = @_;

    my $res = $self->{ua}->get(
        $self->{"${mode}_url"},
        ':content_file' => $self->_path($mode),
    );

    $res->is_success;
}

sub _path {
    my($self, $mode) = @_;

    File::Spec->catfile(dist_dir('Lingua-RU-OpenCorpora-Tokenizer'), $mode);
}

sub _uncompress {
    my $res = shift;
    my $output;

    gunzip \$res->content, \$output or croak $GunzipError;
    $res->content($output);

    return;
}

1;

__END__

=head1 NAME

Lingua::RU::OpenCorpora::Tokenizer::Updater - download newer data for tokenizer

=head1 DESCRIPTION

This module is not supposed to be used directly. Instead use C<opencorpora-update-tokenizer> script that comes with this distribution.

=head1 SEE ALSO

L<Lingua::RU::OpenCorpora::Tokenizer>

=head1 AUTHOR

OpenCorpora team L<http://opencorpora.org>

=head1 LICENSE

This program is free software, you can redistribute it under the same terms as Perl itself.
