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

my @field_defs = (
	{
		key => 'blog_id',
		order => 0,
		label => 'BlogID',
	},
	{
		key => 'name',
		order => 1,
		label => 'Name',
	},
	{
		key => 'description',
		order => 2,
		label => 'Description',
	},
	{
		key => 'obj_type',
		order => 3,
		label => 'System Object',
	},
	{
		key => 'type',
		order => 4,
		label => 'Type',
	},
	{
		key => 'tag',
		order => 5,
		label => 'Template Tag',
	},
	{
		key => 'default',
		order => 6,
		label => 'Default',
	},
	{
		key => 'options',
		order => 7,
		label => 'Options',
	},
	{
		key => 'required',
		order => 8,
		label => 'Required?',
	},
	{
		key => 'basename',
		order => 9,
		label => 'Basename',
	},
);
shift(@field_defs);

sub cf_manager_select_file {
    my $app = shift;

    my %param;
    %param = @_ if @_;

    for my $field (qw( entry_insert edit_field upload_mode require_type
      asset_select dialog )) {
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

	my %label_to_key = map({
		my $label = MT->translate($_->{label});
		if (utf8::is_utf8($label)) {
			$label = Encode::encode('utf-8', $label);
		}
		($label => $_->{key});
	} @field_defs);
	my %key_to_label = reverse(%label_to_key);

	my $fields = &_parse_file($filename, $original_ext, $encoding);

	if (! ref $fields) {
		return cf_manager_select_file(
			$app, %param,
			error => $plugin->translate(
				$fields, $original_ext, $original_file
			)
		);
	}

	my %required_keys = map(
		{ $_ => $key_to_label{$_} || $_ }
		'name', 'basename', 'tag'
	);

 	$fields = [ grep({
		$_->{$required_keys{name}}
		&& $_->{$required_keys{basename}}
		&& $_->{$required_keys{tag}}
	} @$fields) ];

	if (my @dups = grep(scalar(@$_) >= 2, map({
		my $ff = $_;
		[ grep({
			$ff->{$required_keys{basename}} eq $_->{$required_keys{basename}}
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
			$ff->{$required_keys{tag}} eq $_->{tag}
		} @$fields) ];
	} @$fields))) {
		return cf_manager_select_file(
			$app, %param,
			error => $plugin->translate(
				'Duplicated tag(s):'
			) . $dups[0][0]{tag}
		);
	}

	my $field_class = MT->model('field');
	$field_class->remove({
		blog_id => $blog_id,
	});

	foreach my $f (@$fields) {
		my $field = $field_class->new;
		$field->blog_id($blog_id);
		foreach my $k (keys(%$f)) {
			my $c = $label_to_key{$k} || $k;
			if ($field->has_column($c)) {
				$field->$c($f->{$k});
			}
		}

		$field->save();
	}

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param );
}

sub decode {
	my ($str, $encoding) = @_;
	if (! utf8::is_utf8($str)) {
		$str = Encode::decode('utf-8', $str);
	}

	if ($MT::VERSION < 5) {
		Encode::encode($encoding, $str);
	}
	else {
		$str;
	}
}

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

	my @fields = map($_->{key}, @field_defs);
	my @labels = map(
		&decode(MT->translate($_->{label}), $encoding),
		@field_defs
	);

	my $iter = CustomFields::Field->load_iter({
		blog_id => $blog_id,
	});

	require Text::CSV;

	my $csv = Text::CSV->new({binary => 1});
	$csv->combine(@labels);

	my $ret = $csv->string() . "\n";
	while (my $f = $iter->()) {
		my @cs = ();
		foreach my $k (@fields) {
			push(@cs, &decode($f->$k, $encoding));
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
			push(@cs, &decode(exists($f->{$k}) ? $f->{$k} : '', $encoding));
		}
		$csv->combine(@cs);
		$ret .= $csv->string() . "\n";
	}

    $app->{no_print_body} = 1;
    $app->set_header('Cache-Control' => 'public');
    $app->set_header('Pragma' => 'public');
    $app->set_header('Content-Disposition' => "attachment; filename=$filename");
    $app->send_http_header('application/x-msexcel-csv');

    $app->print(Encode::encode($encoding, $ret));
}

sub init_request {
	my ($cb, $app) = @_;
	CustomFieldsManager->instance($cb->{plugin});
}

1;
