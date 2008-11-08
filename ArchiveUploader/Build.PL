use strict;
use warnings;
use Module::Build;
use File::Spec;
use File::Basename;
use YAML qw/ LoadFile /;

my $class = Module::Build->subclass(
	class => 'MTToiplanPluginDirectoryBuilder',
	code => q{
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
	}
);

my $yaml = LoadFile(File::Spec->catfile(dirname(__FILE__), 'config.yaml'));

my $builder = $class->new(
	dist_name           => $yaml->{name},
    dist_author         => 'Taku Amano <taku@toi-planning.net>',
    dist_version        => $yaml->{version},
    module_name         => $yaml->{name} . '::App',
    license             => 'MIT License',
    add_to_cleanup      => [ $yaml->{name} . '-*' ],
);

$builder->create_build_script();
