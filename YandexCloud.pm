#! /usr/bin/env perl
###################################################
#
#  Copyright (C) 2020 Sergey Voloshin <git@varme.pw>
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
###################################################

package YandexCloud;

use lib $ENV{'SHUTTER_ROOT'} . '/share/shutter/resources/modules';

use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;
use Data::Dumper;

use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);

my $d = Locale::gettext->domain("shutter-upload-plugins");
$d->dir($ENV{'SHUTTER_INTL'});

my %upload_plugin_info = (
    'module'                     => "YandexCloud",
    'url'                        => "https://cloud.yandex.ru/",
    'registration'               => "-",
    'name'                       => "YandexCloud",
    'description'                => "Share image to Yandex Cloud",
    'supports_anonymous_upload'  => FALSE,
    'supports_authorized_upload' => FALSE,
    'supports_oauth_upload'      => TRUE,
);

binmode(STDOUT, ":utf8");
if (exists $upload_plugin_info{$ARGV[ 0 ]}) {
    print $upload_plugin_info{$ARGV[ 0 ]};
    exit;
}

###################################################

sub new {
    my $class = shift;

    #call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
    my $self = $class->SUPER::new(shift, shift, shift, shift, shift, shift);

    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;
    my $username = shift;

    use JSON::MaybeXS;
    use LWP::UserAgent;
    use LWP::Simple qw(getstore);
    use HTTP::Request::Common;
    use Path::Class;
    use File::Fetch;
    use Capture::Tiny 'tee';

    $self->{_config} = {};
    $self->{_config_file} = file($ENV{'HOME'}, '/.shutter/shutter-config');

    $self->load_config;
    if (!$self->{_config}->{S3AccessKeyId} && !$self->{_config}->{S3SecretAccessKey} && !$self->{_config}->{S3Bucket}) {
        $self->download_bin;
        return $self->setup;
    }

    return TRUE;
}

sub load_config {
    my $self = shift;

    if (-f $self->{_config_file}) {
        eval {
            $self->{_config} = decode_json($self->{_config_file}->slurp);
        };
    }

    return TRUE;
}

sub download_bin {
    my $download = LWP::UserAgent->new(
        'timeout'    => 20,
        'keep_alive' => 10,
        'env_proxy'  => 1,
    );
    my $url = 'https://raw.githubusercontent.com/varrcan/shutter-s3/master/cloud_upload';

    my $response = $download->get($url);
    die $response->status_line if !$response->is_success;

    my $save = "$ENV{'HOME'}/.shutter/cloud_upload";
    getstore($url, $save);
    system("chmod u+x $ENV{'HOME'}/.shutter/cloud_upload");

    return TRUE;
}

sub setup {
    my $self = shift;

    my $sd = Shutter::App::SimpleDialogs->new;

    my $pin_entry = Gtk2::Entry->new();
    my $pin = '';
    $pin_entry->signal_connect(changed => sub {
        $pin = $pin_entry->get_text;
    });

    my $pin_entry2 = Gtk2::Entry->new();
    my $pin2 = '';
    $pin_entry2->signal_connect(changed => sub {
        $pin2 = $pin_entry2->get_text;
    });

    my $pin_entry3 = Gtk2::Entry->new();
    my $pin3 = '';
    $pin_entry2->signal_connect(changed => sub {
        $pin3 = $pin_entry3->get_text;
    });

    my $pin_entry4 = Gtk2::Entry->new();
    my $pin4 = '';
    $pin_entry2->signal_connect(changed => sub {
        $pin4 = $pin_entry4->get_text;
    });

    my $button = $sd->dlg_info_message(
        "Access Key ID",                  # header
        "Введите идентификатор ключа",    # message
        'gtk-cancel', 'gtk-apply', undef, # button text
        undef, undef, undef,              # button widget
        undef,                            # detail message
        undef,                            # detail checkbox
        $pin_entry,                       # content widget
        undef,                            # content widget2
    );

    my $button2 = $sd->dlg_info_message(
        "Secret Access Key",              # header
        "Введите секретный ключ",         # message
        'gtk-cancel', 'gtk-apply', undef, # button text
        undef, undef, undef,              # button widget
        undef,                            # detail message
        undef,                            # detail checkbox
        $pin_entry2,                      # content widget
        undef,                            # content widget2
    );

    my $button3 = $sd->dlg_info_message(
        "Бакет должен иметь публичный доступ", # header
        "Имя бакета",                          # message
        'gtk-cancel', 'gtk-apply', undef,      # button text
        undef, undef, undef,                   # button widget
        undef,                                 # detail message
        undef,                                 # detail checkbox
        $pin_entry3,                           # content widget
        undef,                                 # content widget2
    );

    my $button4 = $sd->dlg_info_message(
        "По-умолчанию: {bucket}.s3.yandexcloud.net", # header
        "Пользовательский url",                      # message
        'gtk-cancel', 'gtk-apply', undef,            # button text
        undef, undef, undef,                         # button widget
        undef,                                       # detail message
        undef,                                       # detail checkbox
        $pin_entry4,                                 # content widget
        undef,                                       # content widget2
    );

    if ($button == 20 && $button2 == 20 && $button3 == 20 && $button4 == 20) {
        $self->{_config}->{S3AccessKeyId} = $pin;
        $self->{_config}->{S3SecretAccessKey} = $pin2;
        $self->{_config}->{S3Bucket} = $pin3;
        $self->{_config}->{S3Url} = $pin4;
        $self->{_config_file}->openw->print(encode_json($self->{_config}));
        chmod 0600, $self->{_config_file};

        return TRUE;
    }
    else {
        return FALSE;
    }
}

#handle
sub upload {
    my ($self, $upload_filename) = @_;

    $self->{_filename} = $upload_filename;
    utf8::encode $upload_filename;

    #upload the file
    eval {
        my $output = tee {system("$ENV{'HOME'}/.shutter/cloud_upload $upload_filename")};

        $self->{_links}->{'image'} = $output;
        $self->{_links}{'status'} = 200;

    };
    if ($@) {
        $self->{_links}{'status'} = $@;
    }

    #and return links
    return %{$self->{_links}};
}

1;
