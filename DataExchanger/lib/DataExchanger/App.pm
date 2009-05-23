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

package DataExchanger::App;

use POSIX;
use strict;

sub data_exchanger_select_file {
    my $app = shift;

    my %param;
    %param = @_ if @_;

    for my $field (qw( entry_insert edit_field upload_mode require_type
      asset_select )) {
        $param{$field} ||= $app->param($field);
    }

	$param{'upload_mode'} = 'data_exchanger_upload_file';

	$app->load_tmpl('dialog/asset_upload.tmpl', \%param);
}

sub _parse_file {
	my ($file, $ext) = @_;

	if ($ext =~ m/yaml|yml/i) {
		require YAML::Tiny;
		my $yaml = YAML::Tiny->read($file);
		return $yaml->[0];
	}
	elsif ($ext =~ m/js/i) {
		my $js = do{ open(my $fh, '<', $file); local $/; <$fh> };
		require JSON;
		my $obj = JSON::jsonToObj($js);
		return $obj;
	}
	elsif ($ext =~ m/csv/i) {
		my $obj = [];
		open(my $fh, '<', $file);

		require Text::CSV_PP;
		my $csv = Text::CSV_PP->new({binary => 1});
		my $headers = $csv->getline($fh);
		$csv->column_names(@$headers);

		while (my $ref = $csv->getline_hr($fh)) {
			push(@$obj, $ref);
		}

		return $obj;
	}
	else {
		return "[_1] is not supported filetype.";
	}
}

sub data_exchanger_upload_file {
    my $app = shift;
	my $plugin = MT->component('DataExchanger');

	my %param = ();

    if (my $perms = $app->permissions) {
        return $app->error( $app->translate("Permission denied.") )
          unless $perms->can_upload;
    }

    $app->validate_magic() or return;

    my $q = $app->param;
    my ($fh, $info) = $app->upload_info('file');
	if (! $fh) {
		return data_exchanger_select_file(
			$app, %param,
			error => $app->translate("Please select a file to upload.")
		);
	}

	my $original_file = $q->param('file') || $q->param('fname');
    my $original_ext = (File::Basename::fileparse(
		$original_file, qr/[A-Za-z0-9]+$/
	))[2];

	require File::Temp;
	my ($out, $filename) = File::Temp::tempfile(
        undef, SUFFIX => '.' . $original_ext
    );
	while (read($fh, my $cont, 512)) {
		print($out $cont);
	}
	close($out);
	close($fh);

	require File::Spec;
	require File::Basename;

	my $blog_id = $q->param('blog_id') or return;
	my $blog = MT::Blog->load($blog_id) or return;

	my $entries = &_parse_file($filename, $original_ext);
	if (! ref $entries) {
		return data_exchanger_select_file(
			$app, %param,
			error => $plugin->translate(
				$entries, $original_ext, $original_file
			)
		);
	}
	my $entry_class = MT->model('entry');

		require CustomFields::Util;
		require CustomFields::Field;
	my $has_customfields = ! $@;

	my %defaults = (
		'entryid' => 'id',
		'entrytitle' => 'title',
		'entrybody' => 'text',
		'entrymore' => 'text_more',
		'entryexcerpt' => 'excerpt',
		'entrydate' => 'authored_on',
		'entrybasename' => 'basename',
		'entrykeywords' => 'keywords',
		'entrystatus' => sub {
			my ($obj, $value) = @_;
			$obj->status(
				MT::Entry::status_int($value) || MT::Entry::RELEASE()
			);
		},
	);
	my $author_id = $app->user->id;
	my %fields = ();
	foreach my $e (@$entries) {
		my $obj = $entry_class->new;
		$obj->author_id($author_id);
		$obj->blog_id($blog_id);
		$obj->status(MT::Entry::RELEASE());
		my $meta = {};
		foreach my $k (keys(%$e)) {
			my $ek = 'efields_' . $k;

			if (my $kk = $defaults{lc($k)}) {
				if (ref $kk) {
					if (ref $kk eq 'CODE') {
						$kk->($obj, $e->{$k});
					}
				}
				else {
					$obj->$kk($e->{$k});
				}
			}
			elsif ($obj->has_column($k)) {
				$obj->$k($e->{$k});
			}
			elsif ($obj->has_column($ek)) {
				$obj->$ek($e->{$k});
			}
			elsif ($has_customfields) {
				my $field = undef;
				if (exists($fields{lc($k)})) {
					$field = $fields{lc($k)};
				}
				else {
					$fields{lc($k)} = $field = CustomFields::Field->load({
						tag => lc($k),
					}) || 0;
				}

				if ($field) {
					$meta->{$field->basename} = $e->{$k};
				}
			}
		}

		$obj->save();
		if ($has_customfields) {
			CustomFields::Util::save_meta($obj, $meta);
		}

		if ($e->{tags}) {
			my @tags = ref($e->{tags}) ? @{$e->{tags}} : $e->{tags};
			foreach my $t (@tags) {
				$obj->add_tags($t);
			}
			$obj->save_tags;
		}

		if ($e->{categories}) {
			my @cats = ref($e->{categories})
				? @{$e->{categories}} : $e->{categories};
			my $is_primary = 1;
			foreach my $c (@cats) {
				my $cat = MT::Category->load({
					label => $c,
				});
				my $pmt = MT::Placement->new;
				$pmt->blog_id($obj->blog_id);
				$pmt->entry_id($obj->id);
				$pmt->category_id($cat->id);
				$pmt->is_primary($is_primary);
				$pmt->save();
				$is_primary = 0;
			}
		}
	}

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param );
}

1;