#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use Archive::Lha;
use Archive::Lha::Stream;
use Archive::Lha::Header;
use Archive::Lha::Decode;
use FindBin;
use autodie;

my @downloads = (
    'http://www.post.japanpost.jp/zipcode/dl/jigyosyo/lzh/jigyosyo.lzh',
    'http://www.post.japanpost.jp/zipcode/dl/kogaki/lzh/ken_all.lzh'
);

my @files;
my $modified = 0;
my $ua = LWP::UserAgent->new;
$ua->env_proxy;
for my $url ( @downloads ){
    my ( $file ) = $url =~ m!([^/]+)$!;
    $file = $FindBin::Bin . '/' .$file;
    push @files, $file;
    my $res = $ua->mirror($url, $file); # If-Last-Modified since 
    if ( $res->is_success ) {
        $modified = 1;
    }
    elsif( $res->code == '304' ){
        next;
    }
    else {
        die $res->status_line;
    }
}
exit unless $modified; # 更新されたファイルが無ければ抜ける

# 展開作業
my @csv_files;
for my $file ( @files ){
    my $stream = Archive::Lha::Stream->new(file => $file);
    while(defined(my $level = $stream->search_header)) {
        my $header = Archive::Lha::Header->new(level => $level, stream => $stream);
        $stream->seek($header->data_top);
        my $csv_file_name = $FindBin::Bin . '/' . $header->pathname; ###
        push @csv_files, $csv_file_name;
        open my $fh, '>:raw', $csv_file_name;
        my $decoder = Archive::Lha::Decode->new(
            header => $header,
            read   => sub { $stream->read(@_) },
            write  => sub { print $fh @_ }, 
        );
        my $crc16 = $decoder->decode;
        die "crc mismatch" if $crc16 != $header->crc16;
    }
}

require $FindBin::Bin . '/csv2jsonzip.pl';

unlink $_ for @csv_files; #容量節約

1;
