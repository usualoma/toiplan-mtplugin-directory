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

package CustomFieldsManager::App;

use CustomFieldsManager;
use POSIX;
use strict;

sub cf_manager_select_file {
    my $app = shift;

    my %param;
    %param = @_ if @_;

    for my $field (qw( entry_insert edit_field upload_mode require_type
      asset_select )) {
        $param{$field} ||= $app->param($field);
    }

	$param{'require_type'} = $app->param('cf_manager_encoding');

	$param{'upload_mode'} = 'cf_manager_upload_file';

	$app->load_tmpl('dialog/asset_upload.tmpl', \%param);
}

sub _parse_file {
	my ($file, $ext, $encoding) = @_;
	my %encoding_map = (
		'utf8' => 'utf-8',
		'sjis' => 'CP932',
	);
	$encoding = $encoding_map{$encoding} if $encoding_map{$encoding};

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
		require Encode;

		my $obj = [];

		my $tmp_dir = MT->config('TempDir');
		require File::Temp;
		my ($fh, $filename) = File::Temp::tempfile(
			undef, ($tmp_dir ? (DIR => $tmp_dir) : ()),
		);
		print(
			$fh
			Encode::encode('utf-8', Encode::decode($encoding,
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

sub cf_manager_upload_file {
    my $app = shift;
	my $plugin = CustomFieldsManager->instance;

	my %param = ();

    if (my $perms = $app->permissions) {
        return $app->error( $app->translate("Permission denied.") )
          unless $perms->can_upload;
    }

    $app->validate_magic() or return;

    my $q = $app->param;
    my ($fh, $info) = $app->upload_info('file');
	if (! $fh) {
		return cf_manager_select_file(
			$app, %param,
			error => $app->translate("Please select a file to upload.")
		);
	}

	my $encoding = $q->param('require_type') || 'sjis';


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

	my $blog_id = $q->param('blog_id') || 0;

	my $fields = &_parse_file($filename, $original_ext, $encoding);
	if (! ref $fields) {
		return cf_manager_select_file(
			$app, %param,
			error => $plugin->translate(
				$fields, $original_ext, $original_file
			)
		);
	}

	$fields = [ grep({
		$_->{name} && $_->{basename} && $_->{tag}
	} @$fields) ];

	if (my @dups = grep(scalar(@$_) >= 2, map({
		my $ff = $_;
		[ grep({
			$ff->{basename} eq $_->{basename}
		} @$fields) ];
	} @$fields))) {
		return cf_manager_select_file(
			$app, %param,
			error => $plugin->translate(
				'Duplicated basename(s):'
			) . $dups[0][0]{basename}
		);
	}

	if (my @dups = grep(scalar(@$_) >= 2, map({
		my $ff = $_;
		[ grep({
			$ff->{tag} eq $_->{tag}
		} @$fields) ];
	} @$fields))) {
		return cf_manager_select_file(
			$app, %param,
			error => $plugin->translate(
				'Duplicated tag(s):'
			) . $dups[0][0]{tag}
		);
	}

	require Jcode;

	my $field_class = MT->model('field');
	$field_class->remove({
		blog_id => $blog_id,
	});

	foreach my $f (@$fields) {
		my $field = $field_class->new;
		$field->blog_id($blog_id);
		foreach my $k (keys(%$f)) {
			if ($field->has_column($k)) {
				#$field->$k(Jcode->new($f->{$k}, $encoding)->utf8);
				$field->$k($f->{$k});
			}
		}

		$field->save();
	}

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param );
}

my @fields = qw(
	blog_id
	name
	description
	obj_type
	type
	tag
	default
	options
	required
	basename
);
shift(@fields);

sub cf_manager_export_file {
    my $app = shift;
	my $plugin = CustomFieldsManager->instance;

    my $q = $app->param;
	my $blog_id = $q->param('blog_id') || 0;
	my $filename = 'customfields.csv';
	if ($blog_id) {
		$filename = 'customfields_blog_' . $blog_id . '.csv';
	}

	my $encoding = $q->param('cf_manager_encoding') || 'sjis';

	$app->{cgi_headers}{'Cache-Control'} = 'public';
	$app->{cgi_headers}{'Pragma'} = 'public';
	$app->{cgi_headers}{'Content-Type'} = 'application/x-msexcel-csv';
	$app->{cgi_headers}{'Content-Disposition'} = "attachment; filename=$filename";

	my $iter = CustomFields::Field->load_iter({
		blog_id => $blog_id,
	});

	require Text::CSV;
	require Jcode;

	my $csv = Text::CSV->new({binary => 1});
	$csv->combine(@fields);

	my $ret = $csv->string() . "\n";
	while (my $f = $iter->()) {
		my @cs = ();
		foreach my $k ( @fields ) {
			push(@cs, Jcode->new($f->$k, 'utf8')->$encoding);
		}
		$csv->combine(@cs);
		$ret .= $csv->string() . "\n";
	}

	my @examples = (
		{},
		{},
	);

	my @obj_types = ('entry', 'category', 'page', 'folder');
	my @requireds = ("0", "1");
	my @types = ();
	require CustomFields::App::CMS;
	my $types_hash = &CustomFields::App::CMS::load_customfield_types;
	foreach my $k (keys(%$types_hash)) {
		push(@types, $k);
	}
	@types = reverse(sort(@types));

	my @names = ();
	my @blog_ids = ();
	if ($fields[0] eq 'blog_id') {
		unshift(@blog_ids, $plugin->translate('Examples'));
	}
	else {
		unshift(@names, $plugin->translate('Examples'));
	}

	while (@types) {
		push(@examples, {
			blog_id => shift(@blog_ids),
			name => shift(@names),
			obj_type => shift(@obj_types),
			type => shift(@types),
			required => shift(@requireds),
		});
	}

	foreach my $f (@examples) {
		my @cs = ();
		foreach my $k ( @fields ) {
			push(@cs, Jcode->new(exists($f->{$k}) ? $f->{$k} : '', 'utf8')->$encoding);
		}
		$csv->combine(@cs);
		$ret .= $csv->string() . "\n";
	}

	$ret;
}

sub init_request {
	my ($cb, $app) = @_;
	CustomFieldsManager->instance($cb->{plugin});
}

1;
