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

package MT::Plugin::MovableTypeAnniversary;

use strict;
use warnings;

use MT;
use MT::Plugin;

our $VERSION = '1.00';
our $SCHEMA_VERSION = '0.1';
our @ordinal = qw( 1st 2nd 3rd 4th 5th 6th 7th 8th );
unshift(@ordinal, '');

use base qw( MT::Plugin );

my $plugin = MT::Plugin::MovableTypeAnniversary->new( {
    name => 'MovableTypeAnniversary',
    author_name => 'ToI Planning',
    author_link => 'http://tec.toi-planning.net/',
    version => $VERSION,
    schema_version => $SCHEMA_VERSION,
} );
MT->add_plugin( $plugin );

sub init_registry {
    my $plugin = shift;

	my @msgs = ();
	my $i = 0;
	my $version;
	my $script = '';
	foreach (<DATA>) {
		chomp;
		if (! $_) {
			$msgs[$i] .= $script;
			$i++;
		}
		else {
			$msgs[$i] ||= '';

			if (m/([\d\.]+):([\d\.]+)(.*)/) {
				my $ord = $ordinal[$i];
				$version = $2;
				$msgs[$i] .= $_ . '<br />';
				$script = <<__EOS__;
&nbsp;<script defer="defer" type="text/javascript">
(function() {
	jQuery('#release').
		css('width', Math.round($version / window.max_version * 100) + '%').
		html('$version$3');
	jQuery('#anniversary').html('$ord' ? '$ord Anniversary' : '&nbsp;');
})();
</script>
__EOS__
			}
			else {
				$msgs[$i] .= $_;
			}
		}
	}
	$msgs[$i] .= $script;
	$msgs[0] =
		'&nbsp;<script defer="defer" type="text/javascript">window.max_version = ' .
		$version . '</script>' . $msgs[0];

	my $lh = MT->language_handle;
	my $package = ref $lh;
	my $override = <<__EOF__;
package $package;
\$Lexicon{'Upgrading database...'} = 'Upgrading Movable Type...';
__EOF__
	eval $override;

	my %funcs = ();
	for (my $i = 0; $msgs[$i];$i++) {
		my $index = $i;
		my $msg = $msgs[$i];
		$funcs{'show_chronological_table' . $i} = {
			priority => $i,
			code => sub {
				if ($index) {
					sleep(1);
				}

				my ($upgrade) = @_;
				$upgrade->progress($msg);
			},
		};
	}

    $plugin->registry({
		upgrade_functions => \%funcs,
	});
}

1;
__DATA__
&nbsp;<script defer="defer" type="text/javascript">
(function() {
	jQuery('<div id="anniversary">&nbsp;</div>').
		insertBefore('.upgrade').
		css('font-weight', 'bold').
		css('font-size', '120%').
		css('width', '100%');
	jQuery('<div id="release">&nbsp;</div>').
		insertBefore('.upgrade').
		css('background', 'url(http://unkown.bakersterrace.net/~taku/mt50/mt-static/images/progress-bar-indeterminate.gif)').
		css('padding', '5px').
		css('text-align', 'right').
		css('font-weight', 'bold').
		css('font-size', '120%').
		css('width', '0%');
})();
</script>
2001.09.23:0.01
2001.09.25:0.02
2001.09.26:0.03
2001.09.27:0.04
2001.09.30:0.05
2001.10.01:0.06
2001.10.02:0.07
2001.10.03:0.08
2001.10.06:0.09
2001.10.06:0.10
2001.10.08:1.00

2001.10.22:1.1
2001.11.04:1.2
2001.12.11:1.3
2001.12.13:1.31
2002.01.07:1.4
2002.03.20:2.0
2002.02.18:2.0b1
2002.02.20:2.0b2
2002.02.23:2.0b3
2002.02.25:2.0b4
2002.02.27:2.0b5
2002.03.12:2.0b6
2002.05.02:2.1
2002.05.03:2.11
2002.06.26:2.2
2002.06.28:2.21
2002.10.08:2.5

2002.10.29:2.51
2003.02.13:2.6
2003.02.16:2.61
2003.02.16:2.62
2003.02.23:2.63
2003.05.28:2.64

2003.12.18:2.65
2004.01.13:2.66
2004.07.08:3.01D
2004.05.13:3.0D
2004.08.31:3.1
2004.09.03:3.11

2004.10.19:3.12
2004.12.20:3.14
2005.01.24:3.15
2005.04.13:3.16
2005.06.02:3.17
2005.08.25:3.2

2006.07.11:3.3
2006.08.28:3.32
2006.09.26:3.33

2007.01.16:3.34
2007.04.12:3.35

2007.12.13:4.0
2007.12.13:4.01
2008.01.25:4.1
2008.03.01:4.11
2008.08.08:4.12
2008.08.15:4.2
2008.08.22:4.21

2008.12.03:4.22
2008.12.03:4.23
2009.02.27:4.24
2009.03.18:4.25
2009.06.11:4.26
2009.09.30:4.261
2009.08.21:4.3
2009.08.21:4.31
2009.09.30:4.32
2009.09.03:5.0b1
