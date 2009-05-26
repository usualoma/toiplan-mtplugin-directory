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

package MT::Author;

use strict;
use warnings;

sub shared_preferences_widgets {
	my $self = shift;
	$self->SUPER::widgets;
}

package MT::Permission;

use strict;
use warnings;

sub shared_preferences_entry_prefs {
	my $self = shift;
	$self->SUPER::entry_prefs;
}

package SharedPreferences;

use strict;
use warnings;

my $plugin = undef;

sub pre_run {
	my ($cb, $app) = @_;
    $plugin = $cb->{plugin};

	return unless $app->can('param');

	my $blog_id = $app->param('blog_id')
		or return;
	my $user_id = $app->user->id;

	my $hash = $plugin->get_config_hash('blog:' . $blog_id);
	if (
		($hash->{'widget_enabled'})
		&& ($hash->{'widget_author_id'} != $user_id)
	) {
		my $class = MT->model('author');
		my $author = $class->load($hash->{'widget_author_id'});
		if ($author) {
			*MT::Author::widgets = undef;
			*MT::Author::widgets = sub {
				my $orig = shift;
				MT::Author::shared_preferences_widgets($author, @_);
			};
		}
	}

	if (
		($hash->{'field_enabled'})
		&& ($hash->{'field_author_id'} != $user_id)
	) {
		my $class = MT->model('permission');
		my $perm = $class->load({
			'author_id' => $hash->{'field_author_id'},
			'blog_id' => $blog_id,
		});
		if ($perm) {
			*MT::Permission::entry_prefs = undef;
			*MT::Permission::entry_prefs = sub {
				my $orig = shift;
				MT::Permission::shared_preferences_entry_prefs($perm, @_);
			};
		}
	}
}

1;
