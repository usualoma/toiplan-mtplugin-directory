package EnhancedCategory;
use strict;
use warnings;

use utf8;
use Encode;

sub enabled {
	my $blog_id = shift;
	if (! $blog_id) {
		my $blog = MT->instance->blog
			or return 0;
		$blog_id = $blog->id;
	}
	my $plugin = MT->component('EnhancedCategory');
	$plugin->get_config_value('enabled', 'blog:' . $blog_id);
}

sub save_filter {
	return 1 unless &enabled();

	my ($cb, $app) = @_;

	my $plugin = MT->component('EnhancedCategory');
	my $q = $app->param;
	my $vars = $q->Vars;

	my $found = $vars->{'category_ids'};

	foreach my $k (keys(%$vars)) {
		if ($k =~ m/^add_category_id_\d+/ && $vars->{$k}) {
			$found = 1;
			last;
		}
	}

	if (! $found) {
		return $cb->error($plugin->translate('Category is required.'));
	}

	1;
}

sub edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;
	my $blog_id = $app->blog->id;
	require MT::Category;
	my @ids = map($_->id, grep($_->disabled, MT::Category->load({
		'blog_id' => $blog_id,
	})));
	my $css = join("\n", map({
		'input[name="add_category_id_'.$_.'"] { display: none }'
	} @ids));

	$param->{'html_head'} ||= '';
	$param->{'html_head'} .= <<__EOH__;
<style type="text/css">
$css
</style>
__EOH__
}

sub edit_category {
    my ( $cb, $app, $param, $tmpl ) = @_;

    my $field = $tmpl->createElement('app:setting', {
		id => 'disabled',
		label => $app->translate('Disabled'),
	});
    $field->innerHTML(<<__EOH__);
<input type="checkbox" value="1" name="disabled" <mt:If name="disabled">checked="checked"</mt:If> />
__EOH__

    my $description = $tmpl->getElementById('description');
    $tmpl->insertAfter($field, $description);
}

sub cms_pre_save_category {
    my ( $cb, $app, $category, $original ) = @_;
    $category->disabled($app->param('disabled') ? 1 : 0);
    1;
}

1;
