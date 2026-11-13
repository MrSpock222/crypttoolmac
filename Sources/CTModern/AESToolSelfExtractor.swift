/// macOS counterpart of AES-Tool's self-extracting EXE: a `.command` shell script that is used as
/// the PREFIX of an AES-Tool file. Double-clicked in the Finder it opens the Terminal, asks for the
/// key (password or hex key – both are tried, the info block's magic tells which one is right) and
/// decrypts with the system's /usr/bin/perl (key derivation, file handling) and /usr/bin/openssl
/// (LibreSSL, AES-CBC). The appended data is the unchanged AES-Tool format, so CrypTool and the
/// Windows AES-Tool can decrypt the file as well.
public enum AESToolSelfExtractor {
    public static let fileExtension = "command"

    public static var prefix: [UInt8] { Array(script.utf8) }

    static let script = #"""
#!/bin/sh
# ---------------------------------------------------------------------------
#  AES-Tool (CrypTool) - self-decrypting file for macOS
#
#  Open: double-click in the Finder (starts the Terminal). If macOS prevents
#  opening, choose right-click > Open in the Finder or enter in the Terminal:
#      sh "/path/to/file.command"
#  Requires only /usr/bin/perl and /usr/bin/openssl (part of macOS).
#  The appended data is in the format of AES-Tool (CrypTool 1) and can also
#  be decrypted with CrypTool or AES-Tool on Windows.
# ---------------------------------------------------------------------------
exec /usr/bin/perl -x "$0" "$0"
exit 1
#!/usr/bin/perl
use strict;
use warnings;
use Digest::SHA qw(sha256);
use File::Temp qw(tempfile);
use File::Basename qw(dirname basename);
use Encode qw(decode encode);

$SIG{PIPE} = 'IGNORE';
my $self = $ARGV[0];
my $MAGIC = 0x32904ffc;
my $interactive = -t STDIN;

sub pause_exit {
    my $code = shift;
    if ($interactive) { print "\nPress Return to quit ..."; my $x = <STDIN>; }
    exit $code;
}
sub fail { print "\n$_[0]\n"; pause_exit(1); }
my $CORRUPT = 'This encrypted file is corrupt.';

print "AES-Tool (CrypTool) - self-decrypting file\n";
print "File: ", basename($self), "\n\n";

open(my $fh, '<:raw', $self) or fail("The file $self cannot be read.");
my $size = -s $fh;
fail($CORRUPT) if $size < 12;
seek($fh, $size - 12, 0);
read($fh, my $tail, 12) == 12 or fail($CORRUPT);
my ($dlen, $ilen, $magic) = unpack('V3', $tail);
fail('The file does not contain AES-Tool data.') if $magic != $MAGIC;
if ($size >= 4294967296) {
    $dlen += $size - ($size % 4294967296);
    $dlen -= 4294967296 if $dlen > $size;
}
fail($CORRUPT) if $ilen < 16 || $ilen % 16 || $dlen % 16 || 12 + 32 + $ilen + $dlen > $size;
seek($fh, $size - 12 - $ilen - 16, 0);
read($fh, my $iv, 16) == 16 or fail($CORRUPT);
read($fh, my $info, $ilen) == $ilen or fail($CORRUPT);
my $dataoff = $size - 12 - 16 - $ilen - $dlen;

sub aeskey {
    my $k = substr($_[0], 0, 32);
    my $l = length($k) <= 16 ? 16 : (length($k) <= 24 ? 24 : 32);
    return $k . ("\0" x ($l - length($k)));
}
sub openssl_args {
    my $key = shift;
    return ('/usr/bin/openssl', 'enc', '-d', '-aes-' . (length($key) * 8) . '-cbc',
            '-K', unpack('H*', $key), '-iv', unpack('H*', $iv), '-nopad');
}
sub decrypt_small {
    my ($key, $data) = @_;
    my ($t, $tname) = tempfile(UNLINK => 1);
    binmode $t; print $t $data; close $t;
    open(my $p, '-|', openssl_args($key), '-in', $tname) or return undef;
    binmode $p; local $/; my $out = <$p>; close $p;
    return $out;
}
# AES-Tool "PKCS#5": D = SHA256(P || Salt || 00000001), then 9999 times D ^= SHA256(P || D)
sub derive {
    my $pw = shift;
    my $d = sha256($pw . 'theNotSoRandomCrypToolSalt' . pack('N', 1));
    $d ^= sha256($pw . $d) for 2 .. 10000;
    return $d;
}

my ($key, $name);
for (my $try = 0; $try < 3 && !defined $name; $try++) {
    print "Enter key (password or hex key): ";
    system('stty', '-echo') if $interactive;
    my $in = <STDIN>;
    system('stty', 'echo') if $interactive;
    print "\n";
    fail('Canceled.') unless defined $in;
    $in =~ s/[\r\n]+$//;
    redo if $in eq '' && $interactive;
    my @keys;
    my $copy = $in;
    my $pw = eval { encode('cp1252', decode('UTF-8', $copy, 1)) };
    $pw = $in unless defined $pw;
    push @keys, derive(substr($pw, 0, 32));
    (my $hex = $in) =~ s/\s+//g;
    if ($hex =~ /^[0-9a-fA-F]+$/) {
        $hex .= '0' if length($hex) % 2;
        push @keys, pack('H*', substr($hex, 0, 64));
    }
    for my $k (@keys) {
        my $kk = aeskey($k);
        my $p = decrypt_small($kk, $info);
        next unless defined $p && length($p) >= 8;
        my ($m, $nl) = unpack('V2', $p);
        next unless $m == $MAGIC && 8 + $nl <= length($p);
        ($key, $name) = ($kk, substr($p, 8, $nl));
        last;
    }
    print "Wrong key or file corrupt.\n" unless defined $name;
}
fail('Decryption canceled.') unless defined $name;

$name = encode('UTF-8', decode('cp1252', $name));
$name =~ s{[/:\x00-\x1f]}{_}g;
$name = 'decrypted' if $name eq '' || $name =~ /^\.+$/;
my $dir = dirname($self);
my $out = "$dir/$name";
if (-e $out) {
    my $ok = 0;
    if ($interactive) {
        print "The file $out already exists. Overwrite? (y/n) ";
        my $a = <STDIN>;
        $ok = defined $a && $a =~ /^\s*[jJyY]/;
    }
    unless ($ok) {
        my ($base, $ext) = $name =~ /^(.*?)(\.[^.]*)?$/;
        $ext = '' unless defined $ext;
        my $i = 2;
        $i++ while -e "$dir/$base ($i)$ext";
        $out = "$dir/$base ($i)$ext";
    }
}
my $tmp = "$out.part$$";
open(my $o, '|-', openssl_args($key), '-out', $tmp) or fail('/usr/bin/openssl kann nicht gestartet werden.');
binmode $o;
seek($fh, $dataoff, 0);
my $left = $dlen;
while ($left > 0) {
    my $n = $left > 1048576 ? 1048576 : $left;
    read($fh, my $buf, $n) == $n or do { close $o; unlink $tmp; fail($CORRUPT) };
    print $o $buf;
    $left -= $n;
}
close $o or do { unlink $tmp; fail('File decryption error (openssl).') };
if ($dlen > 0) {
    open(my $r, '+<:raw', $tmp) or fail("The file $tmp cannot be opened.");
    my $last = ($dlen - 1) % 4096 + 1;
    seek($r, $dlen - $last, 0);
    read($r, my $lb, $last);
    my $i = $last - 1;
    $i-- while $i > 0 && substr($lb, $i, 1) eq "\0";
    if (substr($lb, $i, 1) ne "\x01") { close $r; unlink $tmp; fail('Wrong key or file corrupt.'); }
    truncate($r, $dlen - $last + $i);
    close $r;
}
rename($tmp, $out) or fail("The file $out cannot be written.");
print "The decrypted file $out has been successfully created.\n";
pause_exit(0);
__END__

"""#
}
