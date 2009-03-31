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

package Shell;
use IPC::Open3;
use strict;

sub _hdlr_execute
{
    my($ctx, $args, $cond) = @_;
	my $cmd = $args->{'command'} or return;
	my $status_var = $args->{'status'} || '';
	my @argv = ();

	if (my $p = $args->{'param'}) {
		if (ref $p) {
			@argv = @$p;
		}
		else {
			@argv = ($p);
		}
	}

	for (my $i = 0;; $i++) {
		if (defined($args->{'param' . $i})) {
			push(@argv, $args->{'param' . $i});
		}
		else {
			last;
		}
	}

    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');

	my $input = $builder->build($ctx, $tokens, $cond);

	my($wtr, $rdr, $err);
	my $pid = open3($wtr, $rdr, $err, $cmd, @argv);

	print($wtr $input);
	close($wtr);

	my $res = do{ local $/; <$rdr> };

	if ($status_var) {
		my $status = waitpid($pid, 0);
		$ctx->var($status_var, $status);
	}

    $res;
}

1;
