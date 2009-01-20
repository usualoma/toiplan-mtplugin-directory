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

package EnhancedAdminMenu;

my $instance = undef;
sub instance {
    my $class = shift if ! ref $_[0];
    $instance = shift if $_[0];
    $instance;
}

sub init_request {
	my ($cb, $app) = @_;
    my $plugin = $cb->{plugin};
	instance($plugin);

	local $SIG{__WARN__} = sub {  }; 

	my $build_blog_selector = \&MT::App::CMS::build_blog_selector;
	*MT::App::CMS::build_blog_selector = sub {
		*MT::Blog::load = sub {
			my ($class, $args, $cond) = @_;
			$cond->{limit} =
                int($plugin->get_config_value('list_blog_numbers')) || 10;
			MT::Object::load($class, $args, $cond);
		};
		my (@ret, $ret);
		if (wantarray) {
			@ret = $build_blog_selector->(@_);
		}
		else {
			$ret = $build_blog_selector->(@_);
		}
		*MT::Blog::load = undef;

		wantarray ? @ret : $ret;
	};
}

1;
