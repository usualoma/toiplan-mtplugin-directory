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

package ArchiveUploader::App;

use POSIX;
use strict;

sub extract {
    my ($filename, $dist, $allowed_filename) = @_;
    my @files = ();
	my $err = '';

	my $cwd = getcwd();
	chdir($dist);

	if ($filename =~ m/\.tar\.gz$|\.tgz$|\.tar$/i) {
		my $compressed = $& ne '.tar';
		require Archive::Tar;
		$@ = undef;
		if ($compressed) {
			eval { require IO::Zlib; };
			$err = $@;
		}
		if (! $@) {
			my $tar = Archive::Tar->new;
			$tar->read($filename, $compressed);
			@files = $tar->list_files([ 'name', 'mtime' ]);

			# $tar->extract();
			# Extract files

			require Encode::Guess;
			my $encode = sub {
				my $guess = Encode::Guess::guess_encoding(
					join('', map($_->{'name'}, @files)),
					qw/cp932 euc-jp iso-2022-jp/
				);
				ref $guess ? $guess->name : 'utf8';
			}->();

			@files = grep($_, map({
				my $name = $_->{'name'};

				if (! $allowed_filename->($name)) {
					undef;
				}
				else {
					my $new_name = Encode::encode('utf8', Encode::decode(
						$encode, $name
					));
					$tar->extract_file($name, $new_name);
					utime($_->{'mtime'}, $_->{'mtime'}, $new_name);
					$new_name;
				}
			} @files));
		}
	}
	elsif ($filename =~ m/\.zip$/i) {
		eval { require Archive::Zip; };
		$err = $@;
		if (! $@) {
			my $zip = Archive::Zip->new();
			$zip->read($filename);
			@files = $zip->memberNames();

			# $zip->extractTree();
			# Extract files

			require Encode::Guess;
			my $encode = sub {
				my $guess = Encode::Guess::guess_encoding(
					join('', @files),
					qw/cp932 euc-jp iso-2022-jp/
				);
				ref $guess ? $guess->name : 'utf8';
			}->();

			@files = grep($_, map({
				my $m = $zip->memberNamed($_);

				if (! $allowed_filename->($_)) {
					undef;
				}
				else {
					my $new_name = Encode::encode('utf8', Encode::decode(
						$encode, $_
					));
					$m->extractToFileNamed($new_name);
					$new_name;
				}
			} @files));
		}
	}
	else {
		my $plugin = ArchiveUploader->instance;
		$err = "[_1] is not supported filetype.";
	}

	chdir($cwd);

	$err ? $err : \@files;
}

sub archive_asset_select_file {
    my $app = shift;

	#$app->add_breadcrumb( $app->translate('Upload File') );
    my %param;
    %param = @_ if @_;

	require MT::CMS::Asset;
	MT::CMS::Asset::_set_start_upload_params($app, \%param);

    for my $field (qw( entry_insert edit_field upload_mode require_type
      asset_select dialog )) {
        $param{$field} ||= $app->param($field);
    }

	$param{'upload_mode'} = 'archive_asset_upload_file';
    $param{dialog} = $app->param('dialog');
    my $tmpl_file = $app->param('dialog') ? 'dialog/asset_upload.tmpl' : 'asset_upload.tmpl';

	$app->load_tmpl($tmpl_file, \%param);
}

sub param_asset_upload {
	my ($cb, $app, $param, $tmpl) = @_;
	my $plugin = ArchiveUploader->instance();

	my $before = $tmpl->getElementById('site_path')
		or return;

	return if $app->mode !~ /archive_\w+_(select|upload)_file/;

	my $field = $tmpl->createElement('app:setting', {
		id => 'sort_order',
		label => $plugin->translate('Sort Order'),
		label_class => 'top-label',
		hint => '',
		show_hint => '0'
	});

	$field->innerHTML(<<__EOF__);
<__trans_section component="ArchiveUploader">
<input type="radio" name="sort_order" id="sort_order_time" value="time" /><label for="sort_order_time">: <__trans phrase="Created Time" /></label>
&nbsp;
<input type="radio" name="sort_order" id="sort_order_name" value="name" /><label for="sort_order_name">: <__trans phrase="File Name" /></label>
</__trans_section>
__EOF__
	$tmpl->insertAfter($field, $before);

	my $options = $tmpl->createElement('app:setting', {
		id => 'archive_uploader_options',
		label => $plugin->translate('Archive Uploader Options'),
		label_class => 'top-label',
		hint => '',
		show_hint => '0'
	});

	$options->innerHTML(<<__EOF__);
<__trans_section component="ArchiveUploader">
<input type="checkbox" name="ignore_macosx" id="ignore_macosx" value="1" checked="checked" /><label for="ignore_macosx">: <__trans phrase="Ignore folder named __MACOSX" /></label>
</__trans_section>
__EOF__
	$tmpl->insertAfter($options, $field);
}

sub sort_method {
	my ($q) = @_;
	my $type = $q->param('sort_order') || '';
	if ($type eq 'name') {
		return sub {
			$a->[1] cmp $b->[1];
		};
	}
	else {
		return sub {
			(stat($a->[1]))[9] cmp (stat($b->[1]))[9];
		}
	}
}

sub allowed_filename_func {
	my $app = shift;
	my $ignore_macosx = $app->param('ignore_macosx');
	my (@deny_exts, @allow_exts);

	if ( my $deny_exts = $app->config->DeniedAssetFileExtensions ) {
		@deny_exts = map {
			if   ( $_ =~ m/^\./ ) { qr/$_/i }
			else                  { qr/\.$_/i }
		} split '\s?,\s?', $deny_exts;
	}
	if ( my $allow_exts = $app->config->AssetFileExtensions ) {
		@allow_exts = map {
			if   ( $_ =~ m/^\./ ) { qr/$_/i }
			else                  { qr/\.$_/i }
		} split '\s?,\s?', $allow_exts;
	}

	sub {
		my ($name) = @_;
		return undef if $ignore_macosx && $name =~ /__MACOSX/o;

		if (@deny_exts) {
			my @ret = File::Basename::fileparse( $name, @deny_exts );
			if ( $ret[2] ) {
				return undef;
			}
		}

		if (@allow_exts) {
			my @ret = File::Basename::fileparse( $name, @allow_exts );
			unless ( $ret[2] ) {
				return undef;
			}
		}

		return 1;
	};
}

sub archive_asset_upload_file {
    my $app = shift;
	my $plugin = ArchiveUploader->instance;

	my %param = (
		'logs' => [],
    	'dialog' => $app->param('dialog'),
	);

	if ( my $perms = $app->permissions ) {
		return $app->error( $app->translate("Permission denied.") )
			unless $perms->can_do('upload');
	}
	else {
		return $app->error( $app->translate("Permission denied.") );
	}

    $app->validate_magic() or return;

    my $q = $app->param;
    my ($fh, $info) = $app->upload_info('file');
	if (! $fh) {
		return archive_asset_select_file(
			$app, %param,
			error => $app->translate("Please select a file to upload.")
		);
	}

	my $original_file = $q->param('file') || $q->param('fname');
    my $original_ext = (File::Basename::fileparse(
		$original_file, qr/[A-Za-z0-9]+$/
	))[2];

	my $tmp_dir = $app->config('TempDir');
	require File::Temp;
	my ($out, $filename) = File::Temp::tempfile(
        undef,
		($tmp_dir ? (DIR => $tmp_dir) : ()),
		SUFFIX => '.' . $original_ext
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
	my $basedir = my $short_path = File::Spec->catdir(
		($q->param('middle_path') ? $q->param('middle_path') : ()),
		($q->param('extra_path') ? $q->param('extra_path') : ()),
	);
    if ($q->param('site_path')) {
        $basedir = File::Spec->catdir($blog->site_path, $short_path);
    }

	if (! -d $basedir) {
		require File::Path;
		File::Path::mkpath($basedir) or
			return archive_asset_select_file(
				$app, %param,
				error => $app->translate(
					'Error creating directory [_1] for blog #[_2].',
					$basedir, $blog_id
				)
			);
	}

    my $extracted = &extract($filename, $basedir, &allowed_filename_func($app));
	if (! ref $extracted || ref $extracted ne 'ARRAY') {
		return archive_asset_select_file(
			$app, %param,
			error => $plugin->translate(
				$extracted, $original_ext, $original_file
			)
		);
	}
	elsif (! @$extracted) {
		return archive_asset_select_file(
			$app, %param,
			error => $plugin->translate(
				"[_1] has no files", $original_file
			)
		);
	}

    my $upload_mode = (~ oct($app->config('UploadUmask'))) & oct('777');
    my $dir_mode = (~ oct($app->config('DirUmask'))) & oct('777');

	my @files = grep({ $_ } map({
		my $path = File::Spec->catfile($basedir, $_);
		if (-d $path) {
			chmod($dir_mode, $path);
			'';
		}
		else {
			chmod($upload_mode, $path);
			[ File::Spec->catfile($short_path, $_), $path ];
		}
	} @$extracted));
	my $sort_method = &sort_method($q);
	@files = map($_->[0], sort({ $sort_method->() } @files));

	my $asset_class = $app->model('asset');
	foreach my $f (@files) {
		if (! Encode::is_utf8($f)) {
			$f = Encode::decode('utf8', $f);
		}

		$f =~ s/^\/*//;

    	my $basename = File::Basename::basename($f);
		my $asset_pkg = MT::Asset->handler_for_file($basename);
	    my $ext = ( File::Basename::fileparse( $f, qr/[A-Za-z0-9]+$/ ) )[2];
		my $filepath = File::Spec->catfile('%r', $f);

		my $obj = $asset_pkg->load({
			'file_path' => $filepath,
			'blog_id' => $blog_id,
		}) || $asset_pkg->new;
		my $is_new = not $obj->id;

		$obj->file_path($filepath);
		$obj->url("%r/$f");
		$obj->blog_id($blog_id);

        $obj->file_name($basename);
        $obj->file_ext($ext);
        $obj->created_by( $app->user->id );

		$obj->save();

		push(
			@{ $param{logs} },
			"$f," . $obj->id . "," . ($is_new ? 'inserted' : 'replaced')
		);
	}

	$app->log({
		message => $plugin->translate(
			'ArchiveUpload \'[_1]\' uploaded by \'[_2]\'',
        	$original_file, $app->user->name
		)
	});

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param);
}

sub archive_index_select_file {
    my $app = shift;

	#$app->add_breadcrumb( $app->translate('Upload File') );
    my %param;
    %param = @_ if @_;

	require MT::CMS::Asset;
	MT::CMS::Asset::_set_start_upload_params($app, \%param);

    for my $field (qw( entry_insert edit_field upload_mode require_type
      asset_select dialog )) {
        $param{$field} ||= $app->param($field);
    }

	$param{'upload_mode'} = 'archive_index_upload_file';
    $param{dialog} = $app->param('dialog');
    my $tmpl_file = $app->param('dialog') ? 'dialog/asset_upload.tmpl' : 'asset_upload.tmpl';

	$app->load_tmpl($tmpl_file, \%param);
}

sub archive_index_upload_file {
    my $app = shift;
	my $plugin = ArchiveUploader->instance;

	my %param = (
		'logs' => [],
    	'dialog' => $app->param('dialog'),
	);

	if ( my $perms = $app->permissions ) {
		return $app->error( $app->translate("Permission denied.") )
			unless $perms->can_do('edit_templates');
	}
	else {
		return $app->error( $app->translate("Permission denied.") );
	}

    $app->validate_magic() or return;

    my $q = $app->param;
    my ($fh, $info) = $app->upload_info('file');
	if (! $fh) {
		return archive_index_select_file(
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
	my $basedir = my $short_path = File::Spec->catdir(
		($q->param('middle_path') ? $q->param('middle_path') : ()),
		($q->param('extra_path') ? $q->param('extra_path') : ()),
	);
    $short_path =~ s/^(\/|\\)*//;
    if ($q->param('site_path')) {
        $basedir = File::Spec->catdir($blog->site_path, $short_path);
    }

    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $extracted = &extract($filename, $basedir, &allowed_filename_func($app));
	if (! ref $extracted) {
		return archive_asset_select_file(
			$app, %param,
			error => $app->translate($extracted)
		);
	}
	elsif (! @$extracted) {
		return archive_asset_select_file(
			$app, %param,
			error => $app->translate(
				"[_1] has no files", $original_file
			)
		);
	}

	my @files = grep({ $_ } map({
		my $path = File::Spec->catfile($tempdir, $_);
		if (-d $path) {
			'';
		}
		else {
			[ $_, $path ];
		}
	} @$extracted));
	my $sort_method = &sort_method($q);
	@files = map($_->[0], sort({ $sort_method->() } @files));


	foreach my $f (@files) {
		if (! Encode::is_utf8($f)) {
			$f = Encode::decode('utf8', $f);
		}

        my $cont = do{
            open(my $fh, '<', File::Spec->catfile($tempdir, $f));
            local $/;
            <$fh>;
        };
        my $file = $short_path ? File::Spec->catfile($short_path, $f) : $f;
    	my $basename = File::Basename::basename($f);
        my $tmpl_class = MT->model('template');

	    my $ext = ( File::Basename::fileparse( $f, qr/[A-Za-z0-9]+$/ ) )[2];
        my %identifiers = qw(
            js  javascript
            css styles
        );
        
        my $obj = $tmpl_class->load({
			'outfile' => $file,
			'blog_id' => $blog_id,
		}) || $tmpl_class->new;
		my $is_new = not $obj->id;

        $obj->blog_id($blog_id);
        $obj->name($basename);
        $obj->text($cont);
        $obj->outfile($file);
        $obj->type('index');
        $obj->identifier($identifiers{$ext} || undef);

        $obj->save();

		push(
			@{ $param{logs} },
			"$f," . $obj->id . "," . ($is_new ? 'inserted' : 'replaced')
		);
	}

	$app->log({
		message => $plugin->translate(
			'ArchiveUpload \'[_1]\' uploaded by \'[_2]\'',
        	$original_file, $app->user->name
		)
	});

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param);
}

sub tag_hdlr_zip {
    eval { require Archive::Zip; };
    return not $@;
}

sub tag_hdlr_tgz {
    eval { require IO::Zlib; };
    return not $@;
}

1;
