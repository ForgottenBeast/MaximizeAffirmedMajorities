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
		my @ballot = shuffle(@candidates);
		open(my $fh, '>',$i.".vt");
		foreach my $c(@ballot){
			my $line_end = "\n";
			if(int(rand(6)) == 0){#leave all other candidates out
				last;
			}
			elsif(int(rand(2)) == 0){#put one or more candidate on this row
				$line_end = ",";
			}
			else{
				print $fh $c.$line_end;
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
	for my $j($startidx .. $#curvote){

	#if on the lines below I encounter multiple candidates
	#I count a vote against all of them
		if($curvote[$j] =~ /^\d,\d/){
			my @losers = split /,/,$curvote[$j];
			foreach my $l (@losers){
				$votes->{$c}->{$l}++;
			}
		}
		
		#if it is a normal case then I deal with it
		else{
			$votes->{$c}->{$curvote[$j]}++;
		}
	}
}

sub readfile{
	my ($votes,$fh) = @_;
	my $i = 0;
	my @curvote;

	#prepare a hash to check for left out candidates
	my %seen;
	my @keys = keys %{$votes};
	foreach my $k (@keys){
		$seen{$k} = 0;
	}
	while(<$fh>){
		chomp $_;
		$curvote[$i] = $_;
		if($curvote[$i] =~ /\A\d,/){
			my @votes = split /,\s?/, $curvote[$i];
			foreach my $v(@votes){
				$seen{$v} = 1;
			}
		}
		else{
			$seen{$curvote[$i]} = 1;
		}
		$i++;
	}

	#all candidates left out of the ballot are accounted for as if they
	#were added together at the lowest possible position
	my $leftovers = "";
	foreach my $k (@keys){
		if(!$seen{$k}){
			if($leftovers =~ /\d\z/){
				$leftovers = $leftovers . ",$k";
			}
			else{#leftovers is empty
				$leftovers = $k;
			}
		}
	}
	if($leftovers ne ""){
		$curvote[$i] = $leftovers;
	}


	for my $i (0 .. $#curvote){
		my @candidates;
		if($curvote[$i] =~ /^\d,\s?\d/){#more than one candidate on this line
			#I split the candidate list into an array
			@candidates = split /,\s?/,$curvote[$i];

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
	print STDERR "here is the vote we are looking at\n";
	foreach my $v (@curvote){
		print STDERR" $v\n"
	}
	if(!@tiebreak){#empty tiebreak
		print STDERR "empty tiebreak, pushing\n";
		foreach my $v (@curvote){
			push @tiebreak,$v;
			print STDERR "$v\n";
		}
		print STDERR "\n"x3;
	}
	elsif(!$tiebreak_ready){
#idée: lire le curvote, et pour chaque vote pas en tie entre plusieurs candidats
#vérifier que le candidat choisi n'est pas en tie dans le tiebreak
#si il est en tie dans le tiebreak on le sort afin qu'il soit à droite ou à
#gauche
		TIE_ANALYSIS:
		foreach my $v (@curvote){
			if($v =~ /\d,\d/){
				next;
				#curvote alreay has a tie
			}
			else{
				print STDERR "can we solve the tie using current vote $v?\n";
				foreach my $t (@tiebreak){
					if($t =~ /\d,\d/){
						print STDERR "we have a tiebreak issue: @tiebreak\n";
						my @candidates = split /,\s?/, $t;
						print STDERR "tiebreak candidates = @candidates\n";

						my $chosen_idx = firstidx {$_ == $v} @candidates;

						if($chosen_idx == -1){
							#can not solve, untied vote no in tie
							print STDERR "sorry, $v not in @candidates\n";
							next;
						}
						my $curpos = firstidx {$_ =~ /$t/} @tiebreak;
						#current position of the tie inside the tiebreak

						#I get the index of the one not in the tie
						my $split_candidate = $candidates[$chosen_idx];
						my $idx = firstidx {$_ =~ /$split_candidate/} @curvote;

						#remove split candidate
						splice @candidates, $chosen_idx,1;
						my $new_tie = join(',',@candidates);
						print STDERR "extract $split_candidate, now new tie is
						$new_tie\n";

						if(is_updown($split_candidate,\@candidates,\@curvote,0,1)){
							#our split is before every other tied candidate in
							#curvote
							print STDERR "$split_candidate is before everyone
							else\n";
							tiebreak_replace(\@tiebreak,$split_candidate,$new_tie,$curpos);
						}
	
						elsif(is_updown($split_candidate,\@candidates,\@curvote,0,0)){
							print STDERR "$split_candidate is after everyone
							else\n";
							tiebreak_replace(\@tiebreak,$new_tie,$split_candidate,$curpos);
						}
						else{
							print STDERR "split is in between, dying.\n";
							die(0);
						}
					}
				}


			}
		}
	}
	my @cdt = keys %{$votes};
	$tiebreak_ready = $#tiebreak == $#cdt;#ready when we have 
	#one candidate per line
}
sub is_updown{
	my ($split_candidate,$candidates,$curvote,$idx,$dir) = @_;

	if($idx > $#$candidates){
		return 1;
	}

	my $split_idx = firstidx {$_ =~ /$split_candidate/} @$curvote;
	my $nextidx = firstidx {$_ =~ /$candidates->[$idx]/} @$curvote;

	if($dir == 1){#check above in the order
		if($split_idx < $nextidx){
			return
			is_updown($split_candidate,$candidates,$curvote,$idx+1,$dir);
		}
		else{
			return 0;
		}
	}
	else{#check below
		if($split_idx < $nextidx){
			return
			is_updown($split_candidate,$candidates,$curvote,$idx+1,$dir);
		}
		else{
			return 0;
		}
	}
}

sub tiebreak_replace{
	my ($tiebreak, $cd1,$cd2,$curpos) = @_;
	print STDERR "$cd2 is after $cd1\n";
	
	splice @{$tiebreak},$curpos,1,($cd1,$cd2);
	print STDERR "tiebreak after insert =
	@$tiebreak\n";

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

sub get_loser{
	my $hash = shift;
	foreach my $k (keys %$hash){
		if ($k ne 'min'){
			return $k;
		}
	}
}

sub affirm{
	my($winner,$loser,$finishOver) = @_;

	$finishOver->{$winner}->{$loser} = 1;
	my @candidates = keys %$finishOver;
	foreach my $c (@candidates){
		if($c == $winner || $c == $loser){
			next;
		}
	print STDERR "affirming, looking at $c, winner $winner, loser $loser\n";
		if($finishOver->{$c}->{$winner} == 1 && $finishOver->{$c}->{$loser} == 0){
			affirm($c,$loser,$finishOver);
		}
		if($finishOver->{$loser}->{$c} == 1 && $finishOver->{$winner}->{$c} == 0){
			affirm($winner,$c,$finishOver);
		}
	}
}

sub win_order{
	print STDERR "\n"x4;
	my ($majorities,$candidates) = @_;
	my @maj = @{$majorities};
	my $k = 0;

	my $finishOver = enumerate($candidates);

	foreach my $m (@$majorities){
		my $winner = (keys %$m)[0];
		my $loser = get_loser($m->{$winner});;
		
		if($finishOver->{$winner}->{$loser} == 0 && $finishOver->{$loser}->{$winner}
		== 0){
			print STDERR "affirming $winner win over $loser\n";
			affirm($winner,$loser,$finishOver);
		}	
	}

	return $finishOver;
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
	
		print STDERR "$aval min $amin, $bval min $bmin for $a_key vs $a_subkey\n";
		print STDERR "$aval min $amin, $bval min $bmin for $b_key vs $b_subkey\n";
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
			print STDERR "solving using tiebreak for $a_key vs $a_subkey and
			$b_key vs $b_subkey\n";
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

sub scoresort{
	my $a_score = (keys %$a)[0];
	my $b_score = (keys %$b)[0];
	
	return $b->{$b_score} <=> $a->{$a_score};
}

sub relook{
	my $finishOrder = shift;
	my @candidates = keys %$finishOrder;
	my @tmp_results;
	foreach my $c (@candidates){
		my $score = 0;
		foreach my $adv (keys %{$finishOrder->{$c}}){
			$score += $finishOrder->{$c}->{$adv};
		}
		print STDERR "$c has a score of $score\n";
		push @tmp_results, {$c => $score};
	}

	@tmp_results = sort scoresort @tmp_results;
	my @results;
	foreach my $r (@tmp_results){
		my $candidate = (keys %$r)[0];
		push @results, $candidate;
	}
	return \@results;
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
		print STDERR "reading $f\n";
		open(my $fh,'<',$f);
		readfile($hash,$fh);
		close($fh);
	}
	our @tiebreak;
	print STDERR "tiebreak = @tiebreak\n";
	my @maj = @{calculate_majorities($hash)};
	#if fucked up, you left the editions inside majsort
	@maj = sort majsort @maj;
	print Dumper(\@maj);

	my $finish_order = win_order(\@maj,\@candidates);
	my $finish_table = relook($finish_order);
	print STDERR Dumper($finish_order);
	print "Here is the tiebreak used: \n";
	foreach my $t (@tiebreak){
		print "$t\n";
	}
	print "Here is the win order:\n";
	for my $i (0 .. $#$finish_table){
		print " $finish_table->[$i]\n";
	}
}

if(!defined($ARGV[0])||!defined($ARGV[1])){
	print 'usage: ./mam.pl $number_of_candidates $number_of_ballots'."\n";
	exit(0);
}

our @tiebreak;
our $tiebreak_ready = 0;
make_ballots($ARGV[1],$ARGV[0]);
main($ARGV[0]);
del_ballots;
