#!usr/bin/perl -w
use strict;
use warnings;

my $in_adapter=shift @ARGV;
my $out_adapter=shift @ARGV;

open OUT,">$out_adapter"or die;
open IN,$in_adapter or die;
while(<IN>){
	chomp;
	my @f=split/\t/,$_;
	if($f[1] == -1){
		next;
	}else{
		print OUT $_,"\n";
	}
}
close(IN);
close(OUT);
`rm $in_adapter`;
