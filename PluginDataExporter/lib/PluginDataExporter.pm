# Copyright (c) 2008 ToI-Planning, All rights reserved.
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

package PluginDataExporter;

use warnings;
use strict;

sub can_manage_blog {
	my $blog = shift;
	return MT->instance->user->permissions($blog->id)->can_manage_plugins;
}

sub can_manage_system {
	return MT->instance->user->permissions(0)->can_manage_plugins;
}

sub apply {
    my ($element, $theme, $obj_to_apply) = @_;
    my $data = $element->{data};
    my $plugindata = MT->model('plugindata');

	my $save = sub {
		my ($dkey, $pkey) = @_;

		foreach my $k (keys(%{ $data->{$dkey} })) {
			my $values = {
				'key' => $pkey,
				'plugin' => $k,
			};
			my $d = $plugindata->load($values) || $plugindata->new;

			$values->{'data'} = $data->{$dkey}{$k};

			$d->set_values($values);
			$d->save;
		}
	};

	if ($data->{'system'}) {
		if (! &can_manage_system) {
			my $plugin = MT->component('PluginDataExporter');
			return $element->error($plugin->translate(
				"This theme contains system-wide plugin data. However, [_1] doesn't have a permissions for system-wide plugin.",
				MT->instance->user->nickname
			));
		}
		$save->('system', 'configuration');
	}
	$save->('blog', 'configuration:blog:' . $obj_to_apply->id);

    return 1;
}

sub info {
    my ($element, $theme, $blog) = @_;
    my $data = $element->{data};

	my %plugins;
	$plugins{$_} = 1 for keys %{ $data->{'blog'} };
	$plugins{$_} = 1 for keys %{ $data->{'system'} };

	my $plugin = MT->component('PluginDataExporter');
    return sub {
		$plugin->translate('[_1] plugins.', scalar(keys(%plugins)))
	};
}

sub export_template {
    my $app = shift;
    my ($blog, $saved) = @_;
    my %checked_ids;
    if ($saved) {
        %checked_ids = map { $_ => 1 } @{$saved->{plugin_data_export_ids}};
    }

	my %plugins = ();
    my @datas = MT->model('plugindata')->load([
		{ 'key' => {'like' => 'configuration:blog:' . $blog->id } },
		'-or',
		{ 'key' => 'configuration' },
	]);

	foreach my $d (@datas) {
		my $plugin = MT->component($d->plugin);
		next unless $plugin;

		my $scope = $d->key eq 'configuration' ? 'system' : 'blog';
		next if $scope eq 'system' && ! &can_manage_system;

		$plugins{$d->plugin} ||= {
			name => $plugin->name,
			description => $plugin->description,
		};

		my $skey = $d->plugin.':'.$scope;
		$plugins{$d->plugin}{$scope} = $skey;
		$plugins{$d->plugin}{$scope . ':checked'}
			= $saved ? $checked_ids{$skey} : ($scope eq 'blog' ? 1 : 0);
	}

    my %param = (
		plugins => [ values(%plugins) ],
		can_manage_system => &can_manage_system,
	);

	my $plugin = MT->component('PluginDataExporter');
	return $plugin->load_tmpl('export.tmpl', \%param);
}

sub export {
    my ($app, $blog, $settings) = @_;

	my @blogs = ();
	my @systems = ();
    if (defined $settings) {
		my @bid = ();
		my @sid = ();
        my @ids = @{ $settings->{plugin_data_export_ids} };
		foreach my $id (@ids) {
			if ($id =~ m/(.*):(blog|system)\Z/) {
				if ($2 eq 'blog') {
					push(@bid, $1);
				}
				else {
					push(@sid, $1);
				}
			}
		}

		@blogs = MT->model('plugindata')->load({
			'key' => {'like' => 'configuration:blog:' . $blog->id },
			'plugin' => \@bid,
		});

		if (&can_manage_system) {
			@systems = MT->model('plugindata')->load({
				'key' => {'like' => 'configuration'},
				'plugin' => \@sid,
			});
		}
    }
    else {
		@blogs = MT->model('plugindata')->load({
			'key' => {'like' => 'configuration:blog:' . $blog->id }
		});
    }

    my %data = (
		(@blogs ? ('blog', {}) : ()),
		(@systems ? ('system', {}) : ()),
	);
	foreach my $d (@blogs) {
		$data{'blog'}{$d->plugin} = $d->data;
	}
	foreach my $d (@systems) {
		$data{'system'}{$d->plugin} = $d->data;
	}

    return %data ? \%data : undef;
}

sub condition {
    my ($blog) = @_;

	return 0 unless &can_manage_system || &can_manage_blog($blog);

    my $data = MT->model('plugindata')->load([
		{ 'key' => {'like' => 'configuration:blog:' . $blog->id } },
		'-or',
		{ 'key' => 'configuration' },
	], { limit => 1 });
    return defined $data ? 1 : 0;
}

1;
