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

package Holiday;
use strict;

my %holidays = ();

sub _hdlr_days
{
    my($ctx, $args, $cond) = @_;
	my @dmy;

	if ($args->{'day'}) {
		@dmy = reverse(split(/\D+/, $args->{'day'}));
	}

	if ($args->{'month'}) {
		@dmy[1..2] = reverse(split(/\D+/, $args->{'month'}));
	}

	if ($args->{'year'}) {
		$dmy[2] = $args->{'year'};
	}

	my ($start_min, $start_max);
	if (! $dmy[2]) {
		return '';
	}
	elsif (! $dmy[1]) {
		$start_min = sprintf('%04d-%02d-%02d', $dmy[2], 1, 1);
		$start_max = sprintf('%04d-%02d-%02d', $dmy[2], 12, 31);
	}
	else {
		$start_min = sprintf('%04d-%02d-%02d', $dmy[2], $dmy[1], 1);
		$start_max = sprintf('%04d-%02d-%02d', $dmy[2], $dmy[1], 31);
	}

	my $key = $start_min . '_' . $start_max;

	if (! $holidays{$key}) {
		$holidays{$key} = {};

		require LWP::UserAgent;
		require JSON;
		my $ua = LWP::UserAgent->new;
		if (my $proxy = MT->config('HTTPProxy')) {
			$ua->proxy('http', $proxy);
		}
		$ua->timeout(10);
		my $response = $ua->get(
			"http://www.google.com/calendar/feeds/japanese\@holiday.calendar.google.com/public/full?start-min=$start_min&start-max=$start_max&max-results=30&alt=json"
		);

		if (! $response->is_success) {
			die $response->status_line;
		}
		my $obj = JSON::jsonToObj($response->content);
		foreach my $e (@{ $obj->{'feed'}{'entry'} }) {
			$holidays{$key}{$e->{'gd$when'}[0]{'startTime'}} = 1;
		}
	}

	if ($holidays{$key}{'2009-02-11'}) {
		$holidays{$key}{'2009-03-20'} = 1;
	}

	my $res = '';
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $glue = exists $args->{glue} ? $args->{glue} : '';
    my $vars = $ctx->{__stash}{vars} ||= {};

	my $i = 0;
	my $len = scalar(keys(%{ $holidays{$key} }));
	foreach my $d (sort(keys(%{ $holidays{$key} }))) {
        $i++;
        local $ctx->{__stash}{holiday} = $d;

        local $vars->{__first__} = $i == 1;
        local $vars->{__last__} = $i == $len;
        local $vars->{__odd__} = ($i % 2) == 1;
        local $vars->{__even__} = ($i % 2) == 0;
        local $vars->{__counter__} = $i;

        defined(my $out = $builder->build($ctx, $tokens, $cond))
            or return $ctx->error( $builder->errstr );
        $res .= $glue if $res ne '';
        $res .= $out;
    }
    $res;
}

sub _hdlr_date
{
    my($ctx, $args) = @_;
	my $holiday = $ctx->stash('holiday')
		or return;
	my $ts = $holiday;
	$ts =~ s/\D//g;
	$ts .= '000000';

	if ($args->{'format'}) {
		require MT::Template::Context;
		$args->{ts} = $ts;
		MT::Template::Context::_hdlr_date($ctx, $args);
	}
	else {
		$ts;
	}
}

1;
