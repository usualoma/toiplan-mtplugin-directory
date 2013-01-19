# Copyright (c) 2010 ToI-Planning, All rights reserved.
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

package BypassDashboard;

use strict;
use warnings;

sub pre_run {
	my ($cb, $app) = @_;
	my $user = $app->user or return 1;

	if ($app->mode eq 'dashboard') {
		require MT::Permission;
		my @perms = MT::Permission->load(
			{ 'author_id' => $user->id, 'blog_id' => {not => 0} },
			{ 'fetch_only' => [ 'blog_id' ] }
		);

		if (scalar(@perms) == 1) {
			$app->param('blog_id', $perms[0]->blog_id);
			$app->delete_param('blog_id') unless $app->is_authorized;
			$app->request('dashboard_bypassed', 1);
		}
	}
}

sub source_header {
	my ($cb, $app, $tmpl) = @_;

	if ($app->request('dashboard_bypassed')) {
		$$tmpl =~ s/Your Dashboard/Dashboard/g;
	}
}

1;
