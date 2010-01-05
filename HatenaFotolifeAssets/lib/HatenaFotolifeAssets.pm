# Copyright (c) 2009 ToI-Planning, All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# $Id$

use strict;
use warnings;

package HatenaFotolifeAssets::SAX::Handler;
use XML::SAX::Base;
use base qw(XML::SAX::Base);

sub new {
    my $class = shift;
    my (%param) = @_;
    my $self = bless \%param, $class;

	$self->{'photos'} = [];

    return $self;
}

sub start_element {
	my $self = shift;
	my $data = shift;

	if ($data->{'Name'} eq 'item') {
		$self->{'current_photo'} = MT::Asset::Image->new;
		$data->{'Attributes'}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}about'}->{'Value'} =~ m/(\d+)$/;
 		$self->{'current_photo'}->id($1);
	}
	elsif (grep($_ eq lc($data->{'Name'}), 'hatena:imageurlmedium'))  {
		$self->{'current_akey'} = lc($data->{'Name'});
	}
	elsif (grep($_ eq lc($data->{'Name'}), 'hatena:imageurl', 'title'))  {
		$self->{'current_key'} = lc($data->{'Name'});
	}
}

sub characters {
	my $self = shift;
	my $data = shift;

	my %map = qw(
		title label
		hatena:imageurl url
		hatena:imageurlmedium thumbnail_url
	);

	if ($self->{'current_photo'} && $self->{'current_key'}) {
		my $method = $map{$self->{'current_key'}};
		$self->{'current_photo'}->$method($data->{'Data'});
	}
	elsif ($self->{'current_photo'} && $self->{'current_akey'}) {
		my $attr = $map{$self->{'current_akey'}};
		$self->{'current_photo'}->{$attr} = $data->{'Data'};
	}
}

sub end_element {
	my $self = shift;
	my $data = shift;

	if ($data->{'Name'} eq 'item') {
		push(@{ $self->{'photos'} }, $self->{'current_photo'});
		delete($self->{'current_photo'});
	}
	else {
		delete($self->{'current_key'});
		delete($self->{'current_akey'});
	}
}

package HatenaFotolifeAssets;

use XML::XPath;
use File::Basename;
use Image::Size;

sub _user_agent {
	use LWP::UserAgent;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	if (my $proxy = MT->config('HTTPProxy')) {
		$ua->proxy('http', $proxy);
	}
	$ua->timeout(10);

	$ua;
}

sub make_iter {
	my ($list) = @_;

	sub {
		shift(@$list);
	};
}

sub photos {
	my $plugin = MT->component('HatenaFotolifeAssets');
	my $blog = MT->instance->blog
		or return undef;
	my $username = $plugin->get_config_value(
		'HatenaFotolifeUsername', 'blog:' . $blog->id
	) or return undef;

	*MT::Asset::Image::thumbnail_url = sub {
		my $self = shift;
		($self->{thumbnail_url}, 120);
	};

	if (my $photos = MT->request('HatenaFotolifeAssets_photos')) {
		return $photos;
	}

	my $ua = &_user_agent;
	my $response = $ua->get("http://f.hatena.ne.jp/$username/rss");

	if ($response->is_success) {
		my $content = $response->content;

		if (MT->version_number < 5) {
			require Encode;
			$content = Encode::encode('utf-8', $content);
		}

		require XML::SAX;
		my $handler = HatenaFotolifeAssets::SAX::Handler->new;

		require MT::Util;
		my $parser = MT::Util::sax_parser();
		$parser->{Handler} = $handler;
		$parser->parse_string($content);

		return MT->request('HatenaFotolifeAssets_photos', $handler->{'photos'});
	}
	else {
		die $response->status_line;
	}
}

sub init_request {

	*MT::Asset::load = sub {
		my $class = shift;
		my ($terms, $args) = @_;

		if (
			(MT->instance->mode eq 'complete_insert')
			&& (! ref($terms) && $terms =~ m/^\d{14}/)
		) {
			my $blog = MT->instance->blog
				or return undef;
			my $user = MT->instance->user
				or return undef;

			my $photos = &photos;
			my ($pdata) = grep($_->id eq $terms, @$photos)
				or return undef;

			my $ua = &_user_agent;
			my $response = $ua->get($pdata->url);

			if (! $response->is_success) {
				die $response->status_line;
			}

			my $basename = basename($pdata->url);
			(my $ext = $basename) =~ s/.*\.//;
			my $file = File::Spec->catfile($blog->site_path, $basename);
			open(my $fh, '>', $file);
			print($fh $response->content);

			require MT::Asset;
			my $asset_pkg = MT::Asset->handler_for_file($file);
			my $asset;
			unless($asset = $asset_pkg->load({ file_path => $file })) {
				$asset = $asset_pkg->new();
			}

			$asset->blog_id($blog->id);
			$asset->file_path('%r/' . $basename);
			$asset->url('%r/' . $basename);
			$asset->file_name($basename);
			(my $content_type = $response->header('content-type')) =~ s{.*/}{};
			$asset->mime_type($content_type);
			$asset->file_ext($ext);

			my $label = $pdata->label;
			if (MT->version_number < 5) {
				require Encode;
				$label = Encode::encode('utf-8', $label);
			}
			$asset->label($label);
			$asset->class('image');

			$asset->created_by($user->id);
			$asset->modified_by($user->id);
			my ($w,$h) = imgsize($file);
			$asset->image_width($w);
			$asset->image_height($h);
			$asset->save
				or die $asset->errstr;
			$asset;
		}
		else {
			MT::Object::load($class, @_);
		}
	};

	*MT::Asset::load_iter = sub {
		my $class = shift;
		my ($terms, $args) = @_;

		if ($terms->{'class'} && ref $terms->{'class'}
			&& $terms->{'class'}[0] eq 'hatena_fotolife') {
			return &make_iter(&photos);
		}
		else {
			MT::Object::load_iter($class, @_);
		}
	};

	*MT::Asset::count = sub {
		my $class = shift;
		my ($terms, $args) = @_;

		if ($terms->{'class'} && ref $terms->{'class'}
			&& $terms->{'class'}[0] eq 'hatena_fotolife') {
			my $photos = &photos;
			$photos ? scalar(@$photos) : 0;
		}
		else {
			MT::Object::count($class, @_);
		}
	};
}

sub source_archetype_editor {
	my ($cb, $app, $tmpl) = @_;
	my $plugin = $app->component('HatenaFotolifeAssets');
	(my $static = $app->static_path) =~ s{/+$}{};

	my ($tmpl_line) = ($$tmpl =~ m/^(.*Insert Image.*)/m);
	$tmpl_line =~ s/Insert Image/Insert Hatena Fotolife/;
	$tmpl_line =~ s/filter_val=image/filter_val=hatena_fotolife/;
	$tmpl_line =~ s{<a }{<a style="background: url($static/plugins/HatenaFotolifeAssets/img/button.gif);" };
	$$tmpl =~ s/^(.*Insert File.*)/$1$tmpl_line/m;
}

1;
