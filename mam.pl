#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;

sub enumerate{
	my $candidates = shift;
	my $votehash = {};
	foreach my $c(@$candidates){
		foreach my $d(@$candidates){
			if($c != $d){
				$votehash->{$c}->{$d} = 0;
			}
		}
	}
	return $votehash;
}

sub readfile{
	my ($votes,$fh) = @_;
	my $i = 0;
	my @curvote;
	while(<$fh>){
		print "read $_";
		chomp $_;
		$curvote[$i] = $_;
		$i++;
	}
	for my $i (0 .. $#curvote){
		for my $j ($i+1 .. $#curvote){
			$votes->{$curvote[$i]}->{$curvote[$j]}++;
		}
	}
}

sub calculate_majorities{
	my $votes = shift;
	my @candidates = keys %$votes;
	my $majorities = [];
	my $k = 0;
	for my $i (0 .. $#candidates){
		for my $j (0 .. $#candidates){
			my $c1 = $candidates[$i];
			my $c2 = $candidates[$j];
			if($c1 != $c2){
				print "checking for candidates $c1 and $c2\n";
				my $fori = $votes->{$c1}->{$c2};
				my $forj = $votes->{$c2}->{$c1};
				print "$c1 sur $c2 = $fori\n$c2 sur $c1 = $forj\n\n";
				if($fori == 0){
					$majorities->[$k] = $c2;
					$majorities->[$k+1] = $c1;
					$majorities->[$k+2] = 100;
				}
				elsif($forj == 0){
					$majorities->[$k] = $c1;
					$majorities->[$k+1] = $c2;
					$majorities->[$k+2] = 100;
				}
				if($fori > $forj){
					$majorities->[$k] = $c1;
					$majorities->[$k+1] = $c2;
					$majorities->[$k+2] = ($forj/$fori)*100;
					$k += 3;
				}
				else{
					$majorities->[$k] = $c2;
					$majorities->[$k+1] = $c1;
					$majorities->[$k+2] = ($fori/$forj)*100;
					$k += 3;
				}
			}
		}
	}
	return $majorities;
}

my @candidates = (1,2,3,4);
my $hash = enumerate(\@candidates);
my @files = glob("*.vt");
foreach my $f (@files){
	print "opening $f\n";
	open(my $fh,'<',$f);
	readfile($hash,$fh);
	close($fh);
}

my @maj = @{calculate_majorities($hash)};
my $i = 0;
while($i < $#maj-3){
	print("$maj[$i] wins over $maj[$i+1] by $maj[$i+2]\n");
	$i += 3;
}
