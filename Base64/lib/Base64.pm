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

package Base64;
use MIME::Types;
use MIME::Base64::Perl;

sub _hdlr_asset_binary {
    my ($ctx) = @_;
    my $a = $ctx->stash('asset')
        or return $ctx->_no_asset_error();
    my $path = $a->file_path
		or '';
	do { open(my $fh, '<', $path); local $/; <$fh> };
}

sub _hdlr_asset_mime {
    my ($ctx) = @_;
    my $a = $ctx->stash('asset')
        or return $ctx->_no_asset_error();
    my $ext = $a->file_ext
		or '';

	my $mimetypes = MIME::Types->new;
	return $mimetypes->mimeTypeOf($ext);
}

sub _fltr_base64 {
	MIME::Base64::Perl::encode_base64($_[0]);
}

1;
