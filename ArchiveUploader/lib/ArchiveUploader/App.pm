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
    my ($filename, $dist) = @_;
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
			@files = $tar->read($filename, $compressed, { extract => 1 });
		}
	}
	elsif ($filename =~ m/\.zip$/i) {
		eval { require Archive::Zip; };
		$err = $@;
		if (! $@) {
			my $zip = Archive::Zip->new();
			$zip->read($filename);
			@files = $zip->memberNames();
			$zip->extractTree();
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
      asset_select )) {
        $param{$field} ||= $app->param($field);
    }

	$param{'upload_mode'} = 'archive_asset_upload_file';

	$app->load_tmpl('dialog/asset_upload.tmpl', \%param);
}

sub archive_asset_upload_file {
    my $app = shift;
	my $plugin = ArchiveUploader->instance;

	my %param = ('logs' => []);

    if (my $perms = $app->permissions) {
        return $app->error( $app->translate("Permission denied.") )
          unless $perms->can_upload;
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

    my $extracted = &extract($filename, $basedir);
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
			File::Spec->catfile($short_path, $_);
		}
	} @$extracted));

	my $asset_class = $app->model('asset');
	foreach my $f (@files) {
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

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param );
}

sub archive_index_select_file {
    my $app = shift;

	#$app->add_breadcrumb( $app->translate('Upload File') );
    my %param;
    %param = @_ if @_;

	require MT::CMS::Asset;
	MT::CMS::Asset::_set_start_upload_params($app, \%param);

    for my $field (qw( entry_insert edit_field upload_mode require_type
      asset_select )) {
        $param{$field} ||= $app->param($field);
    }

	$param{'upload_mode'} = 'archive_index_upload_file';

	$app->load_tmpl( 'dialog/asset_upload.tmpl', \%param );
}

sub archive_index_upload_file {
    my $app = shift;
	my $plugin = ArchiveUploader->instance;

	my %param = ('logs' => []);

    if (my $perms = $app->permissions) {
        return $app->error( $app->translate("Permission denied.") )
          unless $perms->can_edit_templates;
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
    my $extracted = &extract($filename, $tempdir);
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
			$_;
		}
	} @$extracted));


	foreach my $f (@files) {
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

	$plugin->load_tmpl('upload_succeeded.tmpl', \%param );
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
