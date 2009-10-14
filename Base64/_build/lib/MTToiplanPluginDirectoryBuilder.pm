package MTToiplanPluginDirectoryBuilder;
use Module::Build;
@ISA = qw(Module::Build);

		# Don't make blib
		# sub ACTION_code {};
		# Don't make blib
		sub ACTION_docs {};
		# Don't make META.yml
		sub ACTION_distmeta {
			# no warning on ACTION_distdir
			$_[0]->{metafile} = 'MANIFEST';
		};
		# Don't add MEATA.yml to MANIFEST
		sub ACTION_manifest {
			$_[0]->{metafile} = 'MANIFEST',
			$_[0]->SUPER::ACTION_manifest(@_);
		};
		sub ACTION_test {
			my $p = $_[0]->{properties};
			unshift(
				@INC,
				File::Spec->catdir($p->{base_dir}, 'extlib'),
				File::Spec->catdir($p->{base_dir}, '../../lib'),
				File::Spec->catdir($p->{base_dir}, '../../extlib'),
			);

			$_[0]->SUPER::ACTION_test(@_);
		};
		sub ACTION_upload_google {
			my ($self) = @_;
			my $prj = 'toiplan-mtplugin-directory';
			my $ver = $self->dist_version;
			my $dist_dir = $self->dist_dir;
			my $name = $self->dist_name;

			$self->depends_on('dist');
			#$self->_call_action('distdir');
			$self->ACTION_distdir;
			$self->depends_on('zipdist');
			system(
				"googlecode_upload.py -s 'Release $ver (TGZ)' -p $prj -l $name $dist_dir.tar.gz"
			);
			system(
				"googlecode_upload.py -s 'Release $ver (ZIP)' -p $prj -l $name $dist_dir.zip"
			);
			unlink("$dist_dir.tar.gz");
			unlink("$dist_dir.zip");
		};

		sub ACTION_zipdist {
			my ($self) = @_;
			my $dist_dir = $self->dist_dir;
			$self->depends_on('distdir');
			print "Creating $dist_dir.zip\n";
			system("zip -r $dist_dir.zip $dist_dir") == 0 or die $?;
			$self->delete_filetree($dist_dir);
		}

		sub ACTION_distdir {
			my ($self) = @_;

			$_[0]->SUPER::ACTION_distdir(@_);

			my $dist_dir = $self->dist_dir;
			rename($dist_dir, $self->{properties}{dist_name});
			use File::Path;
			use File::Spec;
			use File::Basename;
			my $plugins = File::Spec->catfile($dist_dir, 'plugins');
			mkpath($plugins, 1, 0755);

			my $new_dist_dir = File::Spec->catfile(
				$plugins, $self->{properties}{dist_name}
			);
			rename($self->{properties}{dist_name}, $new_dist_dir);

			foreach my $f (glob(File::Spec->catfile($new_dist_dir, 'LIC*'))) {
				rename($f, File::Spec->catfile($dist_dir, basename($f)));
			}
		}
	
1;
