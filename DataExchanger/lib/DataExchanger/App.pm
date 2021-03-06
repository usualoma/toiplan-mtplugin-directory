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

use strict;
use warnings;

use POSIX;

my %obj_columns = (
	'entry' => {
		'entryid' => 'id',
		'entrytitle' => 'title',
		'entrybody' => 'text',
		'entrymore' => 'text_more',
		'entryexcerpt' => 'excerpt',
		'entrydate' => 'authored_on',
		'entrybasename' => 'basename',
		'entrykeywords' => 'keywords',
		'entrystatus' => {
			'column' => 'status',
			'import' => sub {
				my ($obj, $value) = @_;
				$obj->status(
					MT::Entry::status_int($value) || MT::Entry::RELEASE()
				);
			},
			'export' => sub {
				my ($obj) = @_;
				MT::Entry::status_text($obj->status);
			},
		},
	},
	'page' => {
		'pageid' => 'id',
		'pagetitle' => 'title',
		'pagebody' => 'text',
		'pagemore' => 'text_more',
		'pageexcerpt' => 'excerpt',
		'pagedate' => 'authored_on',
		'pagebasename' => 'basename',
		'pagekeywords' => 'keywords',
	},
	'category' => {
		'categoryid' => 'id',
		'categorylabel' => 'label',
		'categorybasename' => 'basename',
		'categorydescription' => 'description',
		'parentcategory' => {
			'column' => 'parent',
			'import' => sub {
				my ($obj, $value) = @_;
				if ($value =~ m/^\d+$/) {
					$obj->parent($value);
				}
				else {
					my $parent = scalar MT::Category->load({
						'blog_id' => $obj->blog_id,
						'label' => $value,
					});
					$obj->parent($parent->id) if $parent;
				}
			},
			'export' => sub {
				my ($obj) = @_;
				$obj->parent;
			},
		},
	}
);

sub data_exchanger_select_file {
	my $app = shift;

	my %param;
	%param = @_ if @_;

	$param{'require_type'} = $app->param('_type');
	$param{'upload_mode'} = 'data_exchanger_upload_file';
	$param{'dialog'} = 1;

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

		my $tmp_dir = MT->config('TempDir');
		require File::Temp;
		my ($fh, $filename) = File::Temp::tempfile(
			undef, ($tmp_dir ? (DIR => $tmp_dir) : ()),
		);
		print(
			$fh
			Encode::encode('utf-8', Encode::decode('CP932',
				do{ open(my $fh, '<', $file); local $/; <$fh>; }
			))
		);
		seek($fh, 0, 0);

		require Text::CSV_PP;
		my $csv = Text::CSV_PP->new({binary => 1});
		my @headers = @{ $csv->getline($fh) };

		while (my $ref = $csv->getline($fh)) {
			my %entry = ();
			for (my $i = 0; $i <= $#headers; $i++) {
				my $h = $headers[$i];
				if ($entry{$h}) {
					if (! ref $entry{$h}) {
						$entry{$h} = [ $entry{$h}, $ref->[$i] ];
					}
					else {
						push(@{ $entry{$h} }, $ref->[$i]);
					}
				}
				else {
					$entry{$h} = $ref->[$i];
				}
			}

			push(@$obj, \%entry);
		}

		close($fh);

		return $obj;
	}
	else {
		return "[_1] is not supported filetype.";
	}
}

my %_load_asset_keys = (
	'assetfilepath' => sub {
		('file_path' => '%r/' . $_[0]);
	},
	'asseturl' => sub {
		('url' => '%r/' . $_[0]);
	},
	'assetfilename' => sub {
		('file_name' => $_[0]);
	},
);

sub _load_asset {
	my ($blog_id, $v) = @_;
	my $asset_class = MT->model('asset');

	my @terms = map({
		my $k = lc($_);
		$_load_asset_keys{$k} ? $_load_asset_keys{$k}->($v->{$_}) : ();
	} keys(%$v));

	return undef unless @terms;
	scalar $asset_class->load({
		'blog_id' => $blog_id,
		'class' => {'not' => ''},
		@terms
	});
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
	eval {
		require CustomFields::Util;
		require CustomFields::Field;
	};
	my $has_customfields = ! $@;

	my $obj_type = $app->param('require_type');
	my $obj_class = MT->model($obj_type);
	my %columns = %{ $obj_columns{$obj_type} };

	my $initialize = sub { ; };
	if ($obj_type eq 'entry') {
		$initialize = sub {
			my ($obj) = @_;
			$obj->status(MT::Entry::RELEASE());
		};
	}
	elsif ($obj_type eq 'page') {
		$initialize = sub {
			my ($obj) = @_;
			$obj->status(MT::Entry::RELEASE());
		};
	}

	my @reserved = ('categories', 'tags');

	my $author_id = $app->user->id;
	my %fields = ();
	foreach my $e (@$entries) {
		my $obj = $obj_class->new;
		$obj->author_id($author_id);
		$obj->blog_id($blog_id);
		$initialize->($obj);
		my $meta = {};
		foreach my $k (keys(%$e)) {

			if (grep($_ eq $k, @reserved)) {
				next;
			}

			my $ek = 'efields_' . $k;
			my $value = $e->{$k};
			if (ref $value eq 'HASH') {
				$value = &_load_asset($blog_id, $value);
				next unless $value;
			}
			elsif (ref $value eq 'ARRAY') {
				$value = [ grep($_, map(&_load_asset($blog_id, $_), @$value)) ];
				next unless @$value;
			}

			if (my $kk = $columns{lc($k)}) {
				if ((ref $kk) && (ref $kk->{'import'} eq 'CODE')) {
					$kk->{'import'}($obj, $value);
				}
				else {
					$obj->$kk($value);
				}
			}
			elsif ($obj->has_column($k)) {
				$obj->$k($value);
			}
			elsif ($obj->has_column($ek)) {
				if (ref $value eq 'ARRAY') {
					$value = join(',', map($_->id, $value));
				}
				elsif (ref $value) {
					if ($value->isa('MT::Asset')) {
						$value = $value->id;
					}
				}
				$obj->$ek($value);
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
					if (ref $value) {
						if ($value->isa('MT::Asset')) {
							$value = '<form mt:asset-id="' . $value->id . '" class="mt-enclosure mt-enclosure-image" style="display: inline;"><a href="' . $value->url . '">' . $app->translate('Show') . '</a></form>'
						}
					}
					$meta->{$field->basename} = $value;
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

sub decode {
	my $str = shift;
	if (! utf8::is_utf8($str)) {
		$str = Encode::decode('utf-8', $str);
	}

	if ($MT::VERSION < 5) {
		Encode::encode('CP932', $str);
	}
	else {
		$str;
	}
}

sub data_exchanger_export_file {
	my $app = shift;

	my $blog_id = $app->param('blog_id') or return;

	eval {
		require CustomFields::Util;
		require CustomFields::Field;
	};
	my $has_customfields = ! $@;

	my $obj_type = $app->param('_type');
	my $obj_class = MT->model($obj_type);
	my %columns = %{ $obj_columns{$obj_type} };
	my @column_names = values(%columns);
	my $get_columns = sub {
		my ($obj) = @_;
		map({
			if (ref $_) {
				$_->{'export'}($obj);
			}
			else {
				$obj->$_;
			}
		} @column_names);
	};
	my $res = '';

    require Encode;

	$app->{cgi_headers}{'Cache-Control'} = 'public';
	$app->{cgi_headers}{'Pragma'} = 'public';
	$app->{cgi_headers}{'Content-Type'} = 'application/x-msexcel-csv';
	$app->{cgi_headers}{'Content-Disposition'} = 'attachment; filename=' . $blog_id . '_' . $obj_type . '.csv';
	$app->charset('CP932');

	$res .= &decode(join(',', keys(%columns)) . "\r\n");

	my $iter = $obj_class->load_iter({'blog_id' => $blog_id});
	my $i = 0;
	my $buf = '';
	while (my $m = $iter->()) {
		$i++;

		$buf .= '"' . join('","', map({ (my $str = $_) =~ s/"/""/g; $str; }
			$get_columns->($m)
		)) . '"' . "\r\n";

		if ($i % 100 == 0) {
			$res .= &decode($buf);
			$buf = '';
		}
	}

	$res .= &decode($buf);

	$res;
}


1;
