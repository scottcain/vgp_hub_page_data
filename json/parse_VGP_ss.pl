#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Data::Dumper;

open my $PROB, ">problematic_species.txt" or die "couldn't open for writing: $!";

my %assembly;
open IN, "<VGP_VGL_genomes - raw data.tsv" or die "couldn't open for reading: $!";
<IN>; # throw away the first line
while (<IN>) {
    chomp;
    my @la = split("\t", $_);
    my $species = $la[1];
    my $ncbi_species = $la[2];

    next unless $species;

    unless(-e "$ncbi_species.json") {
      # this is the NCBI `datasets` CLI
      system("./datasets summary taxonomy taxon \"$ncbi_species\" > \"$ncbi_species.json\"")
             == 0 or die "system call to datasets failed: $!";
    }

    if (-s "$ncbi_species.json" == 0) {
        warn "Don't know what to do with $ncbi_species.json; it appears to be empty.";
        print $PROB "$ncbi_species\n";
        #    next;
    }

    my $blob;
    {
        local $/ = undef;
        my $file = "$ncbi_species.json";
        open TL, "<$file" or die "couldn't open $file: $!";
        $blob = <TL>;
        close TL;
    }

    my ($class, $order);
    if ($blob) {
        my $json = JSON->new->decode($blob) or die;
        $class = $$json{'reports'}[0]{'taxonomy'}{'classification'}{'class'}{'name'};
        $order = $$json{'reports'}[0]{'taxonomy'}{'classification'}{'order'}{'name'};
    }

    if (!$class) {
        if ($order eq 'Coelacanthiformes') {
            $class = 'Actinistia'; #per https://en.wikipedia.org/wiki/Coelacanth
        }
        if ($order eq 'Testudines') {
            $class = 'Reptilia';
        }
        if ($order eq 'Crocodylia') {
            $class = 'Reptilia';
        }
        if ($species eq 'Notoma floridana') {
            $class = 'Mammalia'; 
        }
        if ($species eq 'Dibamus smithi') {
            $class = 'Reptilia';
        }
    }
    if (!$order) {
        if ($species eq 'Pristiophorus japonicus') {
            $order = 'Pristiophoriformes' # per https://en.wikipedia.org/wiki/Japanese_sawshark
        }
        if ($species eq 'Notoma floridana') {
            $order = 'Rodentia'; # per https://en.wikipedia.org/wiki/Eastern_woodrat
        }
        if ($species eq 'Dibamus smithi') {
            $order = 'Squamata'; #per https://en.wikipedia.org/wiki/Smith%27s_blind_skink
        }
    }

    die "died on $ncbi_species" unless ($class and $order);

    my $size = $la[9];
    if ($size) {
        $size =~ s/\,//g;
        $size = $size/1000000;
    }

    my %localhash;
    $localhash{'NCBI Species'} = $ncbi_species;
    $localhash{"Assembly version"} = $la[4];
    $localhash{"species"} = $species;
    $localhash{'class_'} = $class;
    $localhash{'order'}  = $order;
    $localhash{"size"} = $size;
    $localhash{"het"} = $la[10];
    $localhash{"rep"} = $la[12];
    $localhash{"s_ng50"} = $la[27];
    $localhash{"c_ng50"} = $la[38];
    $localhash{"sGap"} = $la[47];

    push @{$assembly{$class}{$order}}, \%localhash;
    #    print Dumper(%assembly);
    #die;
}
close $PROB;

#print  qw|Mammalia  Aves Lepidosauria Reptilia Amphibia Actinopteri Chondrichthyes|;
my $mn = 0;
my @finallist;
foreach my $classcounter  (qw|Mammalia  Aves Lepidosauria Reptilia Amphibia Actinopteri Chondrichthyes|) {
    for my $ordercounter  (keys %{$assembly{$classcounter}}) {
      #print "$classcounter, $ordercounter, ",scalar @{$assembly{$classcounter}{$ordercounter}}, "\n";
        for my $hash (@{$assembly{$classcounter}{$ordercounter}}) {
            $$hash{'mn'} = $mn;
            $$hash{'mid'} = $mn;
            $mn++;
            $$hash{'mx'}  = $mn;
            push @finallist, $hash;
        }
    }
}

print JSON->new->pretty->encode(\@finallist);

# ./datasets summary taxonomy taxon "Emys orbicularis"
