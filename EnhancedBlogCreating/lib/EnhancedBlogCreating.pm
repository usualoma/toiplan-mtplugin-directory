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

package EnhancedBlogCreating;
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

my @keys = qw(
	file_extension include_cache include_system
	status_default convert_paras allow_comments_default allow_pings_default
);
sub blog_pre_insert {
	my ($cb, $obj) = @_;
	my $app = MT->instance;

	return if !($app->can('param')); # God knows where we'll be coming from!
	return if !($app->param('enhancedblogcreating_plugin_beacon'));
	$obj->$_($app->param($_) || 0) foreach (@keys);
}

sub source_edit_blog {
	my ($cb, $app, $tmpl) = @_;
    my $plugin = &instance();

	require MT::Blog;
	my $blog = MT::Blog->load(undef, {
		'sort' => 'created_on',
		direction => 'descend',
	});
	
	if (! $blog) {
		return;
	}

    my %param = ();
	$param{$_} = $blog->$_ foreach (@keys);
	$param{ALLOW_COMMENTS_DEFAULT_1} = ($param{allow_comments_default} == 1);
	$param{STATUS_DEFAULT_1} = ($param{status_default} == 1);
	$param{STATUS_DEFAULT_2} = ($param{status_default} == 2);

	my $cfg = $app->config;
	$param{system_allow_comments} = $cfg->AllowComments;
	$param{system_allow_pings} = $cfg->AllowPings;

    my $filters = MT->all_text_filters;
    $param{text_filters} = [];
    for my $filter ( keys %$filters ) {
        if (my $cond = $filters->{$filter}{condition}) {
            $cond = MT->handler_to_coderef($cond) if !ref($cond);
            next unless $cond->( 'entry' );
        }
        push @{ $param{text_filters} },
          {
            key      => $filter,
            label    => $filters->{$filter}{label},
            selected => ($param{convert_paras} eq $filter),
          };
    }
    $param{text_filters} =
      [ sort { $a->{filter_key} cmp $b->{filter_key} }
          @{ $param{text_filters} } ];
    unshift @{ $param{text_filters} },
      {
        key      => '0',
        label    => $app->translate('None'),
      };

	my $html = $plugin->load_tmpl('edit_blog.tmpl', \%param )->output;

	my $replace = '\s*<mt:setvarblock name="action_buttons">\s*';
	$$tmpl =~ s#$replace#$html$&#i;
}

1;
