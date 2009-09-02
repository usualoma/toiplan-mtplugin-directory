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

package TabbedEditPage::App;

use strict;
use warnings;

sub source_blog_config {
	my ($cb, $app, $str, $fname) = @_;
	my $blog_id = $app->param('blog_id');
	$$str =~ s/\$blog_id/$blog_id/g;
}

sub edit {
    my $app = shift;
    my $blog_id = $app->param('blog_id')
        or return;
	my $type = $app->param('_type')
		or return;

	require CustomFields::Field;
	my $plugin = MT->component('TabbedEditPage');
    my %param = (
		'settings' => $plugin->get_config_value(
			'settings_' . $type, 'blog:' . $blog_id
		),
		'enabled' => $plugin->get_config_value(
			'enabled_' . $type, 'blog:' . $blog_id
		),
		'obj_type' => $type,
		'updated' => $app->param('updated') ? 1 : 0,
		'customfields' => [CustomFields::Field->load({
			'blog_id' => [ 0, $blog_id ],
			'obj_type' => $type,
		})],
    );
    my $tmpl = $plugin->load_tmpl('edit.tmpl', \%param);

    $tmpl;
}

sub update {
    my $app = shift;
    my $blog_id = $app->param('blog_id')
        or return;
	my $type = $app->param('_type')
		or return;

	my $plugin = MT->component('TabbedEditPage');
	$plugin->set_config_value(
		'settings_' . $type, $app->param('settings'), 'blog:' . $blog_id
	);
	$plugin->set_config_value(
		'enabled_' . $type, $app->param('enabled'), 'blog:' . $blog_id
	);

	return $app->redirect(
		$app->base . $app->mt_uri . "?__mode=tabbed_edit_page_edit&_type=$type&blog_id=$blog_id&updated=1"
	);
}

sub copy {
    my $app = shift;
    my $blog_id = $app->param('blog_id')
        or return;
	my $type = $app->param('_type')
		or return;
	my $from = $app->param('from')
		or return;

	my $plugin = MT->component('TabbedEditPage');
	$plugin->set_config_value(
		'settings_' . $type,
		$plugin->get_config_value(
			'settings_' . $type, 'blog:' . $from
		),
		'blog:' . $blog_id
	);
	$plugin->set_config_value(
		'enabled_' . $type,
		$plugin->get_config_value(
			'enabled_' . $type, 'blog:' . $from
		),
		'blog:' . $blog_id
	);

	return $app->redirect(
		$app->base . $app->mt_uri . "?__mode=tabbed_edit_page_edit&_type=$type&blog_id=$blog_id&updated=1"
	);
}

sub source_edit_entry {
	my ($cb, $app, $tmpl) = @_;
	my $plugin = MT->component('TabbedEditPage');
	my $blog_id = $app->param('blog_id') or return;
	my $type = $app->param('_type') or return;

	my $hash = $plugin->get_config_hash('blog:' . $blog_id) || {};

	if (! $hash->{'enabled_' . $type}) {
		return;
	}

    my $src = $plugin->load_tmpl(
		'edit_entry.tmpl', { 'settings' => $hash->{'settings_' . $type} }
	)->output;

	my $replace = '(<mt:?include[^>]*name="include/footer.tmpl"[^>]*>)';
	$$tmpl =~ s#$replace#$src$1#i;

	my $css = <<__EOS__
<mt:setvarblock name="html_head" append="1">
<link rel="stylesheet" href="@{[ $app->static_path ]}plugins/TabbedEditPage/css/edit_entry.css" type="text/css" media="screen,print" />
</mt:setvarblock>
__EOS__
	;
	$replace = '(<mt:include\s+name="include/header.tmpl")';
	$$tmpl =~ s#$replace#$css$1#i;
}

1;
