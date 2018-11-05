#!usr/bin/perl -w
use strict;
use warnings;

my $indir=shift @ARGV;
my $sampleSheet=shift @ARGV;

my %project;
my @dirs=glob "$indir/fastq/*";
foreach my $subdir(sort @dirs){
	next if($subdir=~/xls/);
	my $pro=(split/\//,$subdir)[-1];
	$project{$pro}++;
}

my %index;
open IN,$sampleSheet or die;
<IN>;
while(<IN>){
	chomp;
	next if(/^\s+$/);
	my @fields=split/\,/,$_;
        next if($#fields < 8);
        next if($fields[0]=~/^Lane/);
        $index{$fields[1]}=$fields[6];
}
close(IN);

foreach my $k(sort keys %project){
	open OUT,">$indir/fastq/$k/rawData_stat_result.xls"or die;
	print OUT "Project\tSample id\tIndex\tRaw reads(M)\tRaw Data(G)\tQ20(%)\tQ30(%)\n";
	my @stat=glob "$indir/fastq/$k/*/cleanData/*.stat";
	`md5sum $indir/fastq/$k/*/rawData/*.fq.gz >$indir/fastq/$k/rawData_stat_result.md5`;
	for(@stat){
		open IN,"$_" or die $!;
	        my ($sample) =  (split /\//)[-3];
		my $data = "";
        	my @temp=();
		open IN,$_ or die;
        	while(<IN>){
                	chomp;
	                next if(/^Type/);
        	        next if(/^Discard Reads related to N and low qual/);
                	next if(/^Discard Reads related to Adapter/);
			next if(/^N of/);
			next if(/^Low qual/);
			next if(/^GC of/);
			next if(/^Error of/);
	                my @t = split /\t/;
        	        push @temp,sprintf("%.2f",$t[1]/1000000) if($t[0]=~/Number of Reads/);
        	        push @temp,sprintf("%.2f",$t[1]/1000000000) if($t[0]=~/Data Size/);
			if($t[0]=~/Q20 of fq1/){
				my $tmp=<IN>;
				my @t1=split/\t/,$tmp;
				$t1[1]=~s/%//;
				$t[1]=~s/%//;
				push @temp,sprintf("%.2f",($t1[1]+$t[1])/2);
			}
			if($t[0]=~/Q30 of fq1/){
        	                my $tmp=<IN>;
                	        my @t1=split/\t/,$tmp;
				$t1[1]=~s/%//;
				$t[1]=~s/%//;
                	        push @temp,sprintf("%.2f",($t1[1]+$t[1])/2);
	                }
		}
        	close IN;
        	$data=join("\t",@temp);
       		print OUT "$k\t$sample\t$index{$sample}\t$data\n";
	}
	close(OUT);
}
