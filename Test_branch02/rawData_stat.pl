#!usr/bin/perl -w
use strict;
use warnings;

die "perl $0 <project outdir>"unless @ARGV==1;
##############
my $outdir=shift @ARGV;

open OUT,">$outdir/fastq/rawData_stat.xls"or die;
print OUT "Project\tSample id\tRaw reads\tRaw Data\tRaw Data(M)\tN of fq1\tN of fq2\tLow qual base of fq1:(<=5)\tLow qual base of fq2:(<=5)\tQ20 of fq1\tQ20 of fq2\tQ30 of fq1\tQ30 of fq2\tGC of fq1\tGC of fq2\tError of fq1\tError of fq2\n";
my @stat=glob "$outdir/fastq/*/*/cleanData/*.stat";
for(@stat){
	chomp;
	open IN,"$_" or die $!;
	my ($sample) =  (split /\//)[-3];
	my ($project) = (split /\//)[-4];
	my $data = "";
	my @temp=();
	while(<IN>){
		chomp;
		next if(/^Type/);
		next if(/^Discard Reads related to N and low qual/);
		next if(/^Discard Reads related to Adapter/);
		my @t = split /\t/;
		push @temp,$t[1];
		push @temp,$t[1]/1000000 if($t[0]=~/Data Size/);
#		$data .= "$t[-1]\t";
	}
	close IN;
	$data=join("\t",@temp);
	print OUT "$project\t$sample\t$data\n";
}
close(OUT);
