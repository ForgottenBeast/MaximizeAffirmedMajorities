#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;
use List::Util qw(shuffle);

sub del_ballots{
	for my $f(glob("*.vt")){
		unlink $f;
	}
}

sub make_ballots{
	my ($nb,$nbc) = @_;
	my @candidates;
	my $j = 0;
	for my $i (1..$nbc){
		$candidates[$j] = $i;
		$j++;
	}

	for my $i (0 .. $nb){
		open(my $fh, '>',$i.".vt");
		my @ballot = shuffle(@candidates);
		foreach my $c(@ballot){
			print $fh "$c\n";
		}
		close($fh);
	}
}
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
	my %majorities;
	my %done;
	for my $i (0 .. $#candidates){
		for my $j (0 .. $#candidates){
			my $c1 = $candidates[$i];
			my $c2 = $candidates[$j];
			if($c1 != $c2 && !exists($done{$c1}{$c2}) && !exists($done{$c2}{$c1})){
				$done{$c1}{$c2} = 1;
				my $fori = $votes->{$c1}->{$c2};
				my $forj = $votes->{$c2}->{$c1};
				if($fori == 0){
					$majorities{$c2}{$c1} = 100;
				}
				elsif($forj == 0){
					$majorities{$c1}{$c2} = 100;
				}
				if($fori > $forj){
					$majorities{$c1}{$c2} = ($forj/$fori)*100;
				}
				else{
					$majorities{$c2}{$c1} = ($fori/$forj)*100;
				}
			}
		}
	}
	return \%majorities;
}

sub sort_maj{
	my $majs = shift;

}

sub main{
	my $nbc = shift;
	my @candidates;
	my $j = 0;
	for my $i (1..$nbc){
		$candidates[$j] = $i;
		$j++;
	}

	print "candidates:\n".Dumper(\@candidates);
	my $hash = enumerate(\@candidates);
	my @files = shuffle(glob("*.vt"));
	foreach my $f (@files){
		print "opening $f\n";
		open(my $fh,'<',$f);
		readfile($hash,$fh);
		close($fh);
	}

	my %maj = %{calculate_majorities($hash)};
	print Dumper(\%maj);
}

if(!defined($ARGV[0])||!defined($ARGV[1])){
	print 'usage: ./mam.pl $number_of_candidates $number_of_ballots'."\n";
	exit(0);
}

make_ballots($ARGV[1],$ARGV[0]);
main($ARGV[0]);
del_ballots;
