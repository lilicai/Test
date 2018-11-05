#!usr/bin/perl -w
use strict;
use warnings;

##################
my $indir=shift @ARGV;

my @counts;
my @L001_R1=glob "$indir/00.temp/Undetermined*L001_R1*";
my @L001_R2=glob "$indir/00.temp/Undetermined*L001_R2*";
my @L002_R1=glob "$indir/00.temp/Undetermined*L002_R1*";
my @L002_R2=glob "$indir/00.temp/Undetermined*L002_R2*";
my @L003_R1=glob "$indir/00.temp/Undetermined*L003_R1*";
my @L003_R2=glob "$indir/00.temp/Undetermined*L003_R2*";
my @L004_R1=glob "$indir/00.temp/Undetermined*L004_R1*";
my @L004_R2=glob "$indir/00.temp/Undetermined*L004_R1*";

my $L001_R1_counts=counts($L001_R1[0]);
my $L001_R2_counts=counts($L001_R2[0]);
my $L002_R1_counts=counts($L002_R1[0]);
my $L002_R2_counts=counts($L002_R2[0]);
my $L003_R1_counts=counts($L003_R1[0]);
my $L003_R2_counts=counts($L003_R2[0]);
my $L004_R1_counts=counts($L004_R1[0]);
my $L004_R2_counts=counts($L004_R2[0]);

open OUT,">$indir/fastq/Undetermined_stat.xls"or die;
print OUT join("\t",'Lane','L001_R1','L001_R2','L002_R1','L002_R2','L003_R1','L003_R2','L004_R1','L004_R2'),"\n";
print OUT join("\t",'Reads',$L001_R1_counts,$L001_R2_counts,$L002_R1_counts,$L002_R2_counts,$L003_R1_counts,$L003_R2_counts,$L004_R1_counts,$L004_R2_counts),"\n";
close(OUT);


sub counts{
	my $fastq=shift @_;
	my $i=0;
	open IN,"gunzip -c $fastq |"or die;
	while(<IN>){
		chomp;
		$i++;
		<IN>;
		<IN>;
		<IN>;
	}
	close(IN);
	return($i);
}
