#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;
use List::Util qw(shuffle);
use Carp;

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
	my @majorities;
	my %done;
	my $n = 0;
	for my $i (0 .. $#candidates){
		for my $j (0 .. $#candidates){
			my $c1 = $candidates[$i];
			my $c2 = $candidates[$j];
			if($c1 != $c2 && !exists($done{$c1}{$c2}) && !exists($done{$c2}{$c1})){
				$done{$c1}{$c2} = 1;
				my $fori = $votes->{$c1}->{$c2};
				my $forj = $votes->{$c2}->{$c1};
				if($fori == 0){
					$majorities[$n] = {$c2 =>{$c1 => 100}};
				}
				elsif($forj == 0){
					$majorities[$n] = {$c1=>{$c2 => 100}};
				}
				elsif($fori > $forj){
					$majorities[$n] = {$c1=>{$c2 => ($forj/$fori)*100}};
				}
				else{
					$majorities[$n] = {$c2=>{$c1 => ($fori/$forj)*100}};
				}
				$n++;
			}
		}
	}
	return \@majorities;
}

sub is_in{
	my ($val,$arr_ref) = @_;
	foreach my $i (@{$arr_ref}){
		if($i == $val){
			return 1;
		}
	}
	return 0;
}

sub win_order{
	my $majorities = shift;
	my @maj = @{$majorities};
	my @win;
	my $k = 0;
	foreach my $i(@maj){
		my ($a_key,$a_subkey) = getsubkeys($i);
		if(is_in($a_key,\@win)){
			next;#winner already in the order, jump to next
		}
		else{
			$win[$k] = $a_key;
			$k++;
		}
	}
	print Dumper(\@win);
}

sub getsubkeys{
	my($a,$b) = @_;#get one keyed/subkeyed hashs
	my ($a_key,$a_subkey,$b_key,$b_subkey);
	if(defined($a) && defined($b)){
		$a_key = (keys $a)[0];
		$a_subkey =(keys $a->{$a_key})[0];

		$b_key = (keys $b)[0];
		$b_subkey = (keys $b->{$b_key})[0];

		return ($a_key,$a_subkey,$b_key,$b_subkey);
	}
	elsif(defined($a) && !defined($b)){
		$a_key = (keys $a)[0];
		$a_subkey =(keys $a->{$a_key})[0];
		return ($a_key,$a_subkey);
	}
	else{
		croak "get subkeys takes at least one arg\n";
	}
}

sub majsort{
	my ($a_key,$a_subkey,$b_key,$b_subkey) = getsubkeys($a,$b);

	$b->{$b_key}->{$b_subkey} <=> $a->{$a_key}->{$a_subkey};
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

	my @maj = @{calculate_majorities($hash)};
	@maj = sort majsort @maj;
	print Dumper(\@maj);

	win_order(\@maj);
}

if(!defined($ARGV[0])||!defined($ARGV[1])){
	print 'usage: ./mam.pl $number_of_candidates $number_of_ballots'."\n";
	exit(0);
}


make_ballots($ARGV[1],$ARGV[0]);
main($ARGV[0]);
del_ballots;
