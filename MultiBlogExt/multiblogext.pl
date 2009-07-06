# Copyright (c) 2008 ToI Planning, All rights reserved.
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

package MT::Plugin::MultiBlogExt;

use strict;
use warnings;

use base qw( MT::Plugin );

our $VERSION = '0.1';
my $plugin = MT::Plugin::MultiBlogExt->new({
	id => 'multiblogext',
	name => 'MultiBlogExt',
	description => 'Extending MultiBlog',
	version => $VERSION,
	author_name => 'ToI Planning',
	author_link => 'http://tec.toi-planning.net/',
	registry => {
		callbacks => {
			'pre_run' => \&pre_run,
			'cms_post_delete.entry' => \&cms_post_save,
		},
	},
});
MT->add_plugin($plugin);

our %processed;

sub pre_run {
	require MultiBlog;
	%processed = ();
}

sub cms_post_save {
	my $plugin = MT->component('MultiBlog');
	my ($eh, $app, $obj) = @_;

	return if $processed{$obj->blog_id};
	$processed{$obj->blog_id} = 1;

	MultiBlog::post_entry_save($plugin, @_);
}

1;
