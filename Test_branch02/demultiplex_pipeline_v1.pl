#!/usr/bin/perl -w
use warnings;
use strict;
use File::Basename;
use Getopt::Long;
use FindBin qw($Bin);
use File::Path qw(make_path remove_tree);
use Config::IniFiles;
use Pod::Usage qw(pod2usage);

########################################################Help for you###################################################################
#                                        #Help information for unkonwer
#######################################################################################################################################
my $USAGE = qq{
Name:
        $0
Function:
        This is a pipeline for bcl2fastq and preDealData;
Usage:
        perl $0 -i <inputdir> -j <max_job number> -o <outdir> ;
Options:
	-i/-inputdir <string> the inputdir mush contain sequencing data ;
	-j/-jobs     <string> the max jobs you can submit defalut is 2;
	-o/-outputdir<string> the outputdir;
Author:
        cailili;cailili\@celloud.cn;
	2018-9-3 v_1.0
Notice:
        ;
};

########################################################################################################################################
#########################################################################################################################################
my $help = 0;

my ($input_dir,$max_jobs_number,$output_dir);
GetOptions(
	"i|inputdir=s" => \$input_dir, 
	"j|jobs=s" => \$max_jobs_number,
	"o|outputdir=s" =>\$output_dir,
	"h|help=s" => \$help,
) or pod2usage();
die "$USAGE" unless ($input_dir);
die "$USAGE" unless ($output_dir);

pod2usage(-verbose => 1) if $help;

$max_jobs_number ||= 2;
######################
main($input_dir,$output_dir);
########main
sub main{
	my $input_dir=shift @_;
	my $output_dir=shift @_;
	my %read;
	my $readref=\%read;
	my %data;
	my $dataref=\%data;
	my %parameter;
	my $parameteref=\%parameter;
	my %software;
	my $softwaref=\%software;

	my $outtime1 = localtime;
	print STDOUT "Start All thing at $outtime1\n";
	Check_format($input_dir);
	($parameteref,$softwaref)=config_info($input_dir,$parameteref,$softwaref);
	($readref,$dataref)=sampleSheet($input_dir,$readref,$dataref);
	my $start_time = time;
	my $outtime2 = localtime;
	my $bcl2fastq_time;
	make_path("$output_dir/00.temp", {verbose => 1, mode => 0755}) unless (-d "$output_dir/00.temp");
	sleep(5);
	make_path("$output_dir/sh/01.bcl2fastq", {verbose => 1, mode => 0755}) unless (-d "$output_dir/sh/01.bcl2fastq");
	sleep(5);
	print STDOUT "	Start bcl2fastq at $outtime2\n";
	bcl2fastq($softwaref,$parameteref,$input_dir,$output_dir,$readref);
	$bcl2fastq_time=time;
	my $bcl2fastq_localtime=localtime;
	my $bcl2fastq_use_time=$bcl2fastq_time-$start_time;
	print STDOUT "	bcl2fastq use time : $bcl2fastq_use_time..........\n	Start mergefastq at $bcl2fastq_localtime\n";

	make_path("$output_dir/fastq", {verbose => 1, mode => 0755}) unless (-d "$output_dir/fastq");
	sleep(5);
	make_path("$output_dir/sh/02.mergefastq", {verbose => 1, mode => 0755}) unless (-d "$output_dir/sh/02.mergefastq");
	sleep(5);
	mergefastq($dataref,$output_dir);
	my $mergefastq_time=time;
	my $mergefastq_localtime=localtime;
	my $mergefastq_use_time=$mergefastq_time-$bcl2fastq_time;
	print STDOUT "	mergefastq use time : $mergefastq_use_time..........\n	Start cutadapt at $mergefastq_localtime\n";

	make_path("$output_dir/sh/03.cutadapt", {verbose => 1, mode => 0755}) unless (-d "$output_dir/sh/03.cutadapt");
	sleep(5);
	cutadapt($parameteref,$softwaref,$dataref,$output_dir);
	my $cutadapt_time=time;
	my $cutadapt_localtime=localtime;
	my $cutadapt_use_time=$cutadapt_time-$mergefastq_time;
	print STDOUT "	cutadapt use time : $cutadapt_use_time..........\n	Start qc at $cutadapt_localtime\n";

	make_path("$output_dir/sh/04.qc", {verbose => 1, mode => 0755}) unless (-d "$output_dir/sh/04.qc");
	sleep(5);
	qc($softwaref,$parameteref,$dataref,$output_dir);
	my $qc_time=time;
	my $qc_localtime=localtime;
	my $qc_use_time=$qc_time-$cutadapt_time;
	print STDOUT "	qc use time : $qc_use_time..........\n	Start stat at $qc_localtime\n";

	make_path("$output_dir/sh/05.stat", {verbose => 1, mode => 0755}) unless (-d "$output_dir/sh/05.stat");
	sleep(5);
	statInfo($output_dir,$softwaref,$input_dir);
	my $stat_time=time;
	my $stat_localtime=localtime;
	my $stat_use_time=$stat_time-$qc_time;
	print STDOUT "	stat use time : $stat_use_time..........\n";
	print STDOUT "All end  time : $stat_localtime\n";
}
###################################################################################################################################stat
sub statInfo{
	my $output_dir=shift @_;
	my $softwaref=shift @_;
	my $input_dir=shift @_;
print "###############\n";
	my %software=%$softwaref;
	my $cmd="$software{'perl'} $software{'bin'}/subscript/rawData_stat.pl $output_dir\n";
	$cmd.="$software{'perl'} $software{'bin'}/subscript/cleanData_stat.pl $output_dir\n";
	$cmd.="$software{'perl'} $software{'bin'}/subscript/Undetermined_stat.pl $output_dir\n";
	$cmd.="$software{'perl'} $software{'bin'}/subscript/result_stat.pl $output_dir $input_dir/sampleSheet.csv\n";
print $cmd,"\n";
	open OUT ,">$output_dir/sh/05.stat/05.stat.sh"or die;
	print OUT $cmd;
	close(OUT);
	chdir("$output_dir/sh/05.stat");
	`nohup sh 05.stat.sh &`;
}

######################################################################################################################################qc
sub qc{
	my $softwaref=shift @_;
	my $parameteref=shift @_;
	my $dataref=shift @_;
	my $output_dir=shift @_;

	my %software=%$softwaref;
	my %parameter=%$parameteref;
	my %data=%$dataref;


	my @jobs;
	foreach my $k(sort keys %data){
		make_path("$output_dir/fastq/$data{$k}/$k/cleanData", {verbose => 1, mode => 0755}) unless (-d "$output_dir/fastq/$data{$k}/$k/cleanData");
		my $fq1="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1.fq.gz";
		my $fq2="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R2.fq.gz";
		my $ad1="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1.adapter.txt.gz";
		my $ad2="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1.adapter.txt.gz";

		my $cmd="$software{'qc'} -i $fq1,$fq2 -a $ad1,$ad2 $parameter{'qc_command'} -o $output_dir/fastq/$data{$k}/$k/cleanData";
		push @jobs,$cmd;
	}
#	open OUT,">$output_dir/sh/04.qc/04.qc.sh"or die;
#	print OUT join("\n",@jobs);
#	close(OUT);
	chdir("$output_dir/sh/04.qc");
	con_jobs(@jobs,$max_jobs_number,"$output_dir/sh/04.qc");
#	`nohup sh 04.qc.sh &`;
}

######################################################################################################################################cutadapt
sub cutadapt{
	my $parameteref=shift @_;
	my $softwaref=shift @_;
	my $dataref=shift @_;
	my $output_dir=shift @_;
	
	my %parameter=%$parameteref;
	my %software=%$softwaref;
	my %data=%$dataref;

	my @jobs;
        foreach my $k(sort keys %data){
                my $fq1="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1.fq.gz";
                my $fq2="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R2.fq.gz";
		my $tmp_ad1="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1";
		my $tmp_ad2="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R2";
                my $ad1="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1.adapter.txt";
                my $ad2="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R2.adapter.txt";

                my $cmd1="$software{'cutadapt'} -a $parameter{'fq1_adapter'} $parameter{'cutadapt_command'} --info-file=$tmp_ad1 $fq1 1>/dev/null 2>/dev/null;";
		$cmd1.="$software{'perl'} $software{'bin'}/subscript/submit_adapter.pl $tmp_ad1 $ad1 && gzip $ad1;";
                my $cmd2="$software{'cutadapt'} -a $parameter{'fq2_adapter'} $parameter{'cutadapt_command'} --info-file=$tmp_ad2 $fq2 1>/dev/null 2>/dev/null;";
		$cmd2.="$software{'perl'} $software{'bin'}/subscript/submit_adapter.pl $tmp_ad2 $ad2 && gzip $ad2;";

                push @jobs,$cmd1;
                push @jobs,$cmd2;
        }
#	open OUT,">$output_dir/sh/03.cutadapt/03.cutadapter.sh"or die;
#       print OUT join("\n",@jobs);
#        close(OUT);
	chdir("$output_dir/sh/03.cutadapt");
	con_jobs(@jobs,$max_jobs_number,"$output_dir/sh/03.cutadapt");
#	`nohup sh 03.cutadapter.sh &`;
	
}
######################################################################################################################################mergefastq
sub mergefastq{
	my $dataref=shift @_;
	my $output_dir=shift @_;

	my %data=%$dataref;
	
	my @jobs;
	foreach my $k(sort keys %data){
		make_path("$output_dir/fastq/$data{$k}/$k/rawData", {verbose => 1, mode => 0755}) unless (-d "$output_dir/fastq/$data{$k}/$k/rawData");
		my $fq1="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R1.fq";
		my $fq2="$output_dir/fastq/$data{$k}/$k/rawData/$k\_part1_R2.fq";
		my @fq1_files=glob "$output_dir/00.temp/$k*_R1_*.fastq.gz";
		my @fq2_files=glob "$output_dir/00.temp/$k*_R2_*.fastq.gz";
#print "@fq1_files=============\n";
		my $cmd1="\`zcat ".join(" ", @fq1_files)." >$fq1 && gzip $fq1\`";
		my $cmd2="\`zcat ".join(" ", @fq2_files)." >$fq2 && gzip $fq2\`";
		push @jobs,$cmd1;
		push @jobs,$cmd2;
	}
#	open OUT,">$output_dir/sh/02.mergefastq/02.mergefastq.sh"or die;
#	print OUT join("\n",@jobs);
#	close(OUT);
	chdir("$output_dir/sh/02.mergefastq");
	con_jobs(@jobs,$max_jobs_number,"$output_dir/sh/02.mergefastq");
#	`nohup sh 02.mergefastq.sh &`;
}
#########################################################################################################################################bcl2fastq
sub bcl2fastq{
	my $softwaref=shift @_;
	my $parameteref=shift @_;
	my $input_dir=shift @_;
	my $output_dir=shift @_;
	my $readref=shift @_;

	my %software=%$softwaref;
	my %parameter=%$parameteref;
	my %read=%$readref;

	my $cmd="$software{'bcl2fastq'} --runfolder-dir $input_dir -o $output_dir/00.temp $parameter{'bcl2fastq_command'} --sample-sheet $input_dir/sampleSheet.csv --create-fastq-for-index-reads --use-bases-mask $read{'Type'}";
	open OUT,">$output_dir/sh/01.bcl2fastq/01.bcl2fastq.sh"or die;
	print OUT "$cmd\n";
	close(OUT);
	chdir("$output_dir/sh/01.bcl2fastq");
	`nohup sh 01.bcl2fastq.sh &`;
}
##########################################################################################################read config
sub config_info{
	my $inputdir = shift @_;
	my $parameteref=shift @_;
	my $softwaref=shift @_;
	my %parameter=%$parameteref;
	my %software=%$softwaref;
	my %ini;
	tie %ini,'Config::IniFiles',( -file => "$inputdir/config.txt" );
	foreach my$key1(keys %ini){
		if($key1 eq "software"){
			foreach my$key2(keys %{$ini{$key1}}){
				$software{$key2} = $ini{"software"}{$key2};
			}	
		}
		if($key1 eq "parameter"){
			foreach my$key2(keys %{$ini{$key1}}){
				$parameter{$key2} = $ini{"parameter"}{$key2};

			}
		}
	}
	return (\%parameter,\%software);
}


###########################################################################################################Check config
sub Check_format{
	my $inputdir = shift @_;
	my $i = 1;
	open IN,"$inputdir/config.txt"||die;	
	while(<IN>){
		chomp;
		if($_ =~ /^\[/){
			$i++;
		}elsif($_ =~ /^\w+=/){
			$i++;
		}elsif($_ =~ /^#/ or $_ =~ /^\s*$/ or $_ =~ /^\s+/){
			$i++;
			next;
		}elsif($_ =~ /;$/){
			die "Error in $i line You config shouldn't include ;\n";
		}else{
			die "Error :: please Check the config is error at $i\n";
		}
	}
	close IN;
}


############################################################################################################read sampleSheet
sub sampleSheet{
	my $inputdir=shift @_;
	my $readref=shift @_;
	my $dataref=shift @_;
	
	my %read=%$readref;
	my %data=%$dataref;

	local $/='[';
	open IN,"$inputdir/sampleSheet.csv"or die;
	<IN>;
	while(<IN>){
		chomp;
		next if(/^\s+$/);
		my @fields=split/\n/,$_;
		if($fields[0]=~/Reads/){
			foreach my $f(@fields){
				next if($f=~/^Reads/);
				next if($f=~/^\s+$/);
				my @tmp=split/\,/,$f,2;
				$read{$tmp[0]}=$tmp[1];
			}
		}
		if($fields[0]=~/Data/){
                        foreach my $f(@fields){
                                next if($f=~/^Data/);
                                next if($f=~/^\s+$/);
				next if($f=~/^Lane/);
                                my @tmp=split/\,/,$f;
                                $data{$tmp[1]}=$tmp[-1];
                        }
                }

	}
	close(IN);
	return(\%read,\%data);
}
sub con_jobs($$$){
        my$outsh = pop @_;
        my$size = pop @_;
        my@jobs = @_;
        my$numersize = @jobs;
        my $temp1;my $temp2;
        if($numersize <= $max_jobs_number){
                &execute(@jobs,$outsh);
                #`cat *sh.log* >>error.info`;
                #unlink glob "*sh.e*";
        }elsif($numersize == 0){
                print STDERR "$outsh not any jobs\n";
                next;
        }else{
                my$newn = $numersize/$max_jobs_number;
                for ($temp1 = 0;$temp1 < $newn;$temp1++){
                        my @newjobs;
                        for($temp2 = 0; $temp2 < $max_jobs_number; $temp2++){
                                if($jobs[$temp1*$max_jobs_number+$temp2]){
                                        push @newjobs,$jobs[$temp1*$max_jobs_number+$temp2];
                                }else{
                                        next;
                                }
                        }
                        &execute(@newjobs,$outsh);
                       # `cat *sh.e* >>error.info`;
                       # unlink glob "*sh.e*";
                }
        }
}
sub execute {
        my $outsh = pop @_;
        my @jobs = @_;

        for (my $i = 0; $i < @jobs; $i++) {
                open TMP,">$outsh/work$i.sh" or die $!;
                print TMP "$jobs[$i]\n";
                close TMP;
                my $string;
                #chomp (my $string = `qsub $opt ./$keyname\_$i.sh`);
        #       while(1){
                        chomp ($string = `nohup sh $outsh/work$i.sh >$outsh/work$i.log &`);
                #       print STDOUT "qsub $opt ./$keyname\_$i.sh\n";
#               }
                print "$string\n";
        }
        while (&stillRun(@jobs)) {
                sleep(60);
        }
       # for (my $i = 0; $i < @jobs; $i++) {
       #         unlink glob "$keyname\_$i.sh";
       #         unlink glob "$keyname\_$i.sh.o*";
       # }
}
sub stillRun {
        my %hash;
        my $flag = 0;
        for(my $i=0;$i<@_;$i++) {
                my $id='work'.$i.'.sh';
print $id,"\n";
                $hash{$id}++;
        }
        my @string = `ps -u cailili -f`;
        foreach my $s (@string) {
               # $s =~ s/^\s+//;
               next unless ($s =~ /(work\d+\.sh)$/);
        print $s,"\n";
                $flag ++ if (exists $hash{$1});
        }
        return $flag;
}

