use strict;
use warnings;
use Test::More tests => 5;

BEGIN {
	my @files = qw(
lib/EnhancedBlogCreating.pm
lib/EnhancedBlogCreating/L10N.pm
lib/EnhancedBlogCreating/L10N/ja.pm
lib/EnhancedBlogCreating/L10N/en_us.pm
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

ok($app->component('EnhancedBlogCreating'), 'component')
