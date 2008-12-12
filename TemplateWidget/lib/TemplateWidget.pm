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

package TemplateWidget;
use strict;

my $instance = undef;
sub instance {
    my $class = shift if ! ref $_[0];
    $instance = shift if $_[0];
    $instance;
}

sub init_request {
	my ($cb, $app) = @_;
	instance($cb->{plugin});
}

sub template_widgets_main {
    my $app = shift;
    my ( $tmpl, $param ) = @_;

	my $ctx = $tmpl->context;
	my $blog_id = $app->param('blog_id');

	require MT::Template;
	my $module = MT::Template->load({
		type => 'custom',
		blog_id => $blog_id,
		name => 'TemplateWidget(main)',
	});

	if (! $module) {
		$module = MT::Template->load({
			type => 'custom',
			blog_id => 0,
			name => 'TemplateWidget(main)',
		});
	}

	if ($module) {
		$param->{'content'} = $module->output;
	}
}

sub template_widgets_sidebar {
    my $app = shift;
    my ( $tmpl, $param ) = @_;

	my $ctx = $tmpl->context;
	my $blog_id = $app->param('blog_id');

	require MT::Template;
	my $module = MT::Template->load({
		type => 'custom',
		blog_id => $blog_id,
		name => 'TemplateWidget(sidebar)',
	});

	if (! $module) {
		$module = MT::Template->load({
			type => 'custom',
			blog_id => 0,
			name => 'TemplateWidget(sidebar)',
		});
	}

	if ($module) {
		$param->{'content'} = $module->output;
	}
}

1;
