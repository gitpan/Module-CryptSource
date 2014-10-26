# $File: //member/autrijus/Module-CryptSource/CryptSource.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 675 $ $DateTime: 2002/08/16 19:24:21 $

package CryptSource;
$CryptSource::VERSION = '0.01';

use strict;

use Storable		qw(thaw nfreeze);
use MIME::Base64	qw(encode_base64 decode_base64);
use Term::ReadKey	qw(ReadMode);
use Digest::MD5		qw(md5_hex);
use Crypt::Rijndael;

=head1 NAME

Module::CryptSource - Encrypt and Decrypt source for Binary Packagers

=head1 SYNOPSIS

In myprog.pl:

    use Module::CryptSource;
    
Afterwards:

    % perl myprog.pl --ensrc
    % perlapp -f myprog.pl	# or perl2exe
    % myprog.exe --desrc

=head1 DESCRIPTION

One of the problems in binary packages such as perlapp or perl2exe is
the difficulty of uncovering the source code.  While it can be argued
that obscuring source code may be neccessary in some environments, it
could be diasastrous when you accidentally lose the source code.

This self-modifying module let you specify a key to encrypted source
code and modules, so you can use that key to retrieve them back.

To use this module, simply put C<use Module::CryptSource;> in all scripts
and modules you wish to encrypt. Run it once with the C<--ensrc> option
before running B<perlapp> or B<perl2exe>, so it can store the modified
F<CryptSource.pm> along with your F<.exe> file; a copy of encrypted source
code is stored in the F<CryptSource.pm> file. Run the resulting executable
with C<--desrc> to decrypt the sources back.

=head1 CAVEATS

B<Storable>, B<Crypt::Rijndael> and B<Term::ReadKey> are three XS
modules you'll have to install it yourself. It's probably possible
to use B<Crypt::Rijndael_PP> and C<Win32::*> as the alternative,
but I don't have the motivation yet to investigate.

If user enters a wrong decryption key, chances are that the
C<unpack('N/a*')> will report an C<Out of memory!> error.

=cut

my %Files;

sub import {
    return $Files{(caller)[1]}++
	if ($0 !~ /\.exe$/i) and (($ARGV[0] || '') eq '--ensrc');

    return unless ($ARGV[0] || '') eq '--desrc'; local *FH;

    %Files = %{+eval{thaw(unpack('N/a*', Crypt::Rijndael->new(md5_hex(
	ReadMode(2), print("Enter the decryption key:"), scalar <STDIN>
    ))->decrypt(decode_base64(SRC()))))} or die "\nDecryption failed!"};

    while (my ($file, $src) = each %Files) {
	print "\nDecrypting $file...";
	chmod 0644, $file; open FH, ">$file" or die $!;
	print FH $src;
    }

    %Files = (); print "\n"; exit;
}

INIT {
    return unless %Files; local *FH;
    my $src = do { local $/; open FH, __FILE__; <FH> };

    $src =~ s[# <!--\n.*\n# -->]["# <!--\n".
	encode_base64(Crypt::Rijndael->new(md5_hex(
	ReadMode(2), print("Enter the encryption key:"), scalar <STDIN>
    ))->encrypt(do{
	my $d = pack('N/a*', nfreeze({map{
	    print "\nEncrypting $_...";
	    local $/; open FH, $_; $_ => <FH>;
	} keys %Files}));
	$d . (' ' x (-length($d) % 16));
    })).".\n# -->"]es; die $@ if $@;

    chmod 0644, __FILE__; open FH, ">".__FILE__ or die $!;
    print FH $src; close FH;
    print "\n"; exit;
};

use constant SRC => (($ARGV[0] || '') ne '--desrc') ? '' : << '.'; # <!--
JFSyy9z2AkYiUhbDSayD1TufUlobh2bV52famlzo5gAc1ySpD9DvbUdhlg733VaseUzC1ni2OuC0
To1FI9w2yA==
.
# -->

1;

__END__

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2001, 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
