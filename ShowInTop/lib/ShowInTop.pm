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

package ShowInTop;

use strict;
use warnings;

my $plugin = undef;
sub init_request {
	my ($cb, $app) = @_;
	$plugin = $cb->{plugin};

	return if !($app->can('param'));
    my $blog_id = $app->param('blog_id')
        or return;

	if ($plugin->get_config_value('enabled', 'blog:' . $blog_id)) {
		my $actions = ($plugin->{registry}->{list_actions} ||= {});
		$actions->{entry} = {
			'show_in_top_on' => {
				'label' => 'Show in top',
				'code' => 'ShowInTop::on',
				'order' => 100,
				'permission' => 'administer',
			},
			'show_in_top_off' => {
				'label' => 'Remove from top',
				'order' => 100,
				'code' => 'ShowInTop::off',
				'permission' => 'administer',
			}
		};
    }
}

sub on {
	&update_status(1, @_);
}

sub off {
	&update_status(0, @_);
}

sub update_status {
	my $status = shift;
	my ($app) = @_;
	my %ids;

	require MT::Entry;

	foreach my $id ($app->param('id')) {
		my $entry = MT::Entry->load($id);
		$entry->show_in_top($status);
		$entry->save and $ids{$id} = 1;
	}

	$app->rebuild_these(\%ids, how => MT::App::CMS::NEW_PHASE());
}

sub _hdlr_entries {
    my($ctx, $args, $cond) = @_;
	
	if ($args->{'show_in_top'}) {
		require MT::Entry;

		my @ids = map($_->entry_id, MT::Entry->meta_pkg->search(
			{
				'type' => 'show_in_top',
				'vinteger' => 1,
			},
			{
				'fetchonly' => [ 'entry_id' ],
			}
		));

		if (! @ids) {
			return '';
		}
		else {
			$args->{'id'} = \@ids;
		}
	}

    defined(my $result = $ctx->super_handler( $args, $cond ))
        or return $ctx->error($ctx->errstr);

    return $result;
}

1;
