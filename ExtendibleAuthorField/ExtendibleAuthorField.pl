# Copyright (c) 2009 ToI-Planning, All rights reserved.
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

package MT::Plugin::ExtendibleAuthorField;

use strict;
use warnings;
use MT;
use MT::Plugin;

use base qw( MT::Plugin );

our $VERSION = '1.0';

MT->add_plugin(MT::Plugin::ExtendibleAuthorField->new({
    id => 'ExtendibleAuthorField',
    key => 'addauthorfield',
    description => 'Enable to extend MT::Author\'s field.',
    name => 'ExtendibleAuthorField',
    version => $VERSION,
	l10n_class  => 'MT::Plugin::ExtendibleAuthorField::L10N',
}));

sub init_app {
	my $app = shift;
	if(! $app->isa('MT::App::Upgrader')) {
		no warnings 'redefine';
		my $load = \&MT::BasicAuthor::load;
		*MT::BasicAuthor::load = sub {
			$_[2] ||= {};
			$_[2]->{'fetchonly'} = [
				'id', 'name', 'nickname', 'password', 'type', 'email', 'url',
				'public_key', 'preferred_language', 'api_password',
				'remote_auth_username', 'remote_auth_token', 'entry_prefs',
				'text_format', 'status', 'external_id',
			];

			MT::Object::load(@_);
		};
	}
}

1;
