#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;
use List::Util qw(shuffle);
use List::MoreUtils qw(firstidx);
use Carp;

sub del_ballots{
	for my $f(glob("*.vt")){
		unlink $f;
	}
}

sub make_ballots{
	my ($nb,$nbc) = @_;
	my @candidates;
	my $same_rank = "";
	my $j = 0;
	for my $i (1..$nbc){
		$candidates[$j] = $i;
		$j++;
	}

	for my $i (0 .. $nb){
		my $same_rank = "";
		my @ballot = shuffle(@candidates);
		open(my $fh, '>',$i.".vt");
		foreach my $c(@ballot){
			if(int(rand(6)) == 0){#leave all other candidates out
				print STDERR "leaving out in $i.vt\n";
				last;
			}
			elsif(int(rand(2)) == 0){#put one or more candidate on this row
				if($same_rank eq ""){
					$same_rank = $c;
					next;
				}
				else{
					print $fh "$c,$same_rank";
					print STDERR "putting candidates together in $i.vt\n";
				}
			}
			else{
				print $fh "$c\n";
			}
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

sub vote_against_below{
	my ($startidx,$cv,$votes,$candidate) = @_;
	my $c = $candidate;
	my @curvote = @{$cv};
	print STDERR "working on candidate $c\n";
	for my $j($startidx .. $#curvote){

	#if on the lines below I encounter multiple candidates
	#I count a vote against all of them
		if($curvote[$j] =~ /^\d,\d/){
			print STDERR "loser below is multiple\n";
			my @losers = split /,/,$curvote[$j];
			print STDERR @losers;
			foreach my $l (@losers){
				print STDERR "add vote for $c against $l\n";
				$votes->{$c}->{$l}++;
			}
		}
		
		#if it is a normal case then I deal with it
		else{
			print STDERR "add vote for $c against $curvote[$j]\n";
			$votes->{$c}->{$curvote[$j]}++;
		}
	}
}

sub readfile{
	my ($votes,$fh) = @_;
	my $i = 0;
	my @curvote;

	#prepare a hash to check for left out candidates
	print STDERR "\n\nseen setup\n";
	my %seen;
	my @keys = keys %{$votes};
	foreach my $k (@keys){
		print STDERR "adding key $k\n";
		$seen{$k} = 0;
	}
	print STDERR "seen setup done \n\n\n";
	while(<$fh>){
		chomp $_;
		$curvote[$i] = $_;
		if($curvote[$i] =~ /\A\d,/){
			print STDERR "got a match on $curvote[$i]\n";
			my @votes = split /,\s?/, $curvote[$i];
			print STDERR "got multi votes: @votes";
			foreach my $v(@votes){
				print STDERR "adding multivote key $v to seen\n";
				$seen{$v} = 1;
			}
		}
		else{
			$seen{$curvote[$i]} = 1;
		}
		$i++;
	}
	print STDERR "curvote as of end of file:\n";
	foreach my $v (@curvote){
		print STDERR "$v\n";
	}

	#all candidates left out of the ballot are accounted for as if they
	#were added together at the lowest possible position
	my $leftovers = "";
	foreach my $k (@keys){
		if(!$seen{$k}){
			print STDERR "I have not seen $k yet, adding to leftover\n";
			if($leftovers =~ /\d\z/){
				$leftovers = $leftovers . ",$k";
			}
			else{#leftovers is empty
				$leftovers = $k;
			}
		}
	}
	if($leftovers ne ""){
		print STDERR "got leftover string: $leftovers\n";
		$curvote[$i] = $leftovers;
	}


	print STDERR "\nafter adding leftovers, curvote = \n";
	foreach my $v(@curvote){
		print STDERR "$v\n";
	}

	for my $i (0 .. $#curvote){
		my @candidates;
		if($curvote[$i] =~ /^\d,\s?\d/){#more than one candidate on this line
			print STDERR "got a match on skivvy curvote: $curvote[$i]\n";
			#I split the candidate list into an array
			@candidates = split /,\s?/,$curvote[$i];
			print STDERR "splat it in @candidates\n";

			#foreach candidate in the list I count one vote for him
			#against everyone below him
			foreach my $c (@candidates){
				vote_against_below($i+1,\@curvote,$votes,$c);
			}
		}
		else{
			vote_against_below($i+1,\@curvote,$votes,$curvote[$i]);
		}
		our $tiebreak_ready;
		if(!$tiebreak_ready){
			update_tiebreak(\@curvote,$votes);
		}
	}
}

sub update_tiebreak{
	my ($cv,$votes)= @_;
	my @curvote = @{$cv};
	our( @tiebreak,$tiebreak_ready);

	if(!@tiebreak){#empty tiebreak
		print STDERR "empty tiebreak, pushing\n";
		foreach my $v (@curvote){
			push @tiebreak,$v;
			print STDERR "$v\n";
		}
		print STDERR "\n"x3;
	}
	else{
		foreach my $t (@tiebreak){
			if($t =~ /\d,\d/){
				print STDERR "we have a tiebreak issue: @tiebreak\n";
				my @candidates = split /,\s?/, $t;
				print STDERR "tiebreak candidates = @candidates\n";
				for my $i (0 .. $#candidates){
					for my $j (0 .. $#candidates){
						if($i != $j){
							#lets check if the current vote can solve
							#the tiebreak equality issue
							print STDERR "working on tiebreak candidate $candidates[$i]
							and $candidates[$j]\n";
							my $idx = firstidx {$_ =~ /$candidates[$i]/} @curvote;
							my $jdx = firstidx {$_ =~ /$candidates[$j]/} @curvote;
							my $curpos = firstidx {$_ eq $t} @tiebreak;
							print STDERR "issue with $t at $curpos\n";
							if($idx == -1 || $jdx == $idx || $jdx == -1){
								#the vote itself is tied
								print STDERR "vote is tied\n";
								last;
							}
							if($idx < $jdx){
								print STDERR "ci is before cj\n";
								$tiebreak[$curpos] = $j;
								splice @tiebreak,$curpos,0,$candidates[$i];
								#insert i before j
							}
							else{
								print STDERR "ci is after cj\n";
								$tiebreak[$curpos] = $i;
								splice @tiebreak,$curpos,0,$candidates[$j];
								#insert j before i
							}
						}
					}
				}
			}
		}
	}
	print STDERR "tiebreak currently = \n";
	print STDERR "@tiebreak\n";

	my @cdt = keys %{$votes};
	$tiebreak_ready = $#tiebreak == $#cdt;#ready when we have 
	#one candidate per line
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
				
				if($fori > $forj){
					$majorities[$n] = {$c1=>{$c2 => $fori,'min'=>$forj}};
				}
				else{
					$majorities[$n] = {$c2=>{$c1 => $forj,'min'=>$fori}};
				}
				$n++;
			}
		}
	}
	return \@majorities;
}

sub win_order{
	my $majorities = shift;
	my @maj = @{$majorities};
	my @win;
	my $k = 0;
	foreach my $i(@maj){
		my ($a_key,$a_subkey) = getsubkeys($i);
		my $windx = firstidx {$_ == $a_key} @win;
		my $lodx = firstidx {$_ == $a_subkey} @win;

		if($windx == -1){#winner not in the ordering
			if($lodx != -1){#if the loser of the duel is already in the
			#ordering
				splice @win,$lodx,0,$a_key;
				#insert the winner above the loser
			}
			else{#none in the current ordering
				push @win,$a_key;
				push @win,$a_subkey;
			}
		}
		else{#winner already in the ordering
			if($lodx == -1){#loser not in the ordering
				push @win,$a_subkey;
			}
		}
	}
	print "Here is the win order:\n";
	foreach my $c (@win){
		print "$c\n";
	}
}

sub getsubkeys{
	my($a,$b) = @_;#get one keyed/subkeyed hashs
	my ($a_key,$a_subkey,$b_key,$b_subkey);
	if(defined($a)){
		my @keys = keys %{$a};

		$a_key = $keys[firstidx {$_ ne 'min'} @keys];
		@keys = keys %{$a->{$a_key}};
		$a_subkey = $keys[firstidx {$_ ne 'min'} @keys];
		if(defined($b)){
			@keys = keys %{$b};
			$b_key = $keys[firstidx {$_ ne 'min'} @keys];
			@keys = keys %{$b->{$b_key}};
			$b_subkey = $keys[firstidx {$_ ne 'min'} @keys];

			return ($a_key,$a_subkey,$b_key,$b_subkey);
		}
		return ($a_key,$a_subkey);
	}
	elsif(!defined($a) && !defined($b)){
		croak "get subkeys takes at least one arg\n";
	}
}

sub majsort{
	my ($a_key,$a_subkey,$b_key,$b_subkey) = getsubkeys($a,$b);
	my $aval = $a->{$a_key}->{$a_subkey};
	my $bval = $b->{$b_key}->{$b_subkey};
	if($aval < $bval){
		return 1;
	}
	elsif($aval == $bval){
		my $amin = $a->{$a_key}->{min};
		my $bmin = $b->{$b_key}->{min};
	
		print STDERR "$aval min $amin, $bval min $bmin\n";
		print STDERR "$aval min $amin, $bval min $bmin\n";
		#here check for the minority size rule in case of equality
		#the majority opposed by the smallest minority has precedence
		if($amin > $bmin)
		{
			print STDERR "solving using minority rules\n";
			return 1;
		}
		else{
			#use tiebreak
			our @tiebreak;
			my $indb = firstidx {$_ == $a_key} @tiebreak;
			my $inda =firstidx {$_ == $b_key} @tiebreak;
			print STDERR "solving using tiebreak for $a_key and $b_key\n";
			if($inda < $indb){
				return 1;
			}
			else{
				return -1;
			}
		}
	}
	else{
		return -1;
	}
}

sub main{
	my $nbc = shift;
	my @candidates;
	my $j = 0;
	for my $i (1..$nbc){
		$candidates[$j] = $i;
		$j++;
	}

	my $hash = enumerate(\@candidates);
	my @files = shuffle(glob("*.vt"));
	foreach my $f (@files){
		open(my $fh,'<',$f);
		readfile($hash,$fh);
		close($fh);
	}
	our @tiebreak;
	print STDERR "tiebreak = @tiebreak\n";
	my @maj = @{calculate_majorities($hash)};
	print "before sort:\n";
	print Dumper(\@maj);
	#if fucked up, you left the editions inside majsort
	@maj = sort majsort @maj;
	print Dumper(\@maj);

	win_order(\@maj);
}

if(!defined($ARGV[0])||!defined($ARGV[1])){
	print 'usage: ./mam.pl $number_of_candidates $number_of_ballots'."\n";
	exit(0);
}

our @tiebreak;
our $tiebreak_ready = 0;
#make_ballots($ARGV[1],$ARGV[0]);
main($ARGV[0]);
#del_ballots;
