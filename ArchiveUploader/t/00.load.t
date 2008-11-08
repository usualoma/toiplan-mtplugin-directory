use strict;
use warnings;
use Test::More tests => 5;

BEGIN {
	my @files = qw(
lib/ArchiveUploader/App.pm
lib/ArchiveUploader/L10N.pm
lib/ArchiveUploader/L10N/en_us.pm
lib/ArchiveUploader/L10N/ja.pm
	);
	foreach (@files) {
		s#/#::#g;
		s/\.pm$//;
		use_ok $_;
	}
}   

# preprare app object
use MT::App::Test;
my $app = MT::App::Test->test_instance_of
	or die MT::App::Test->errstr;

ok($app->component('archiveuploader'), 'component')
