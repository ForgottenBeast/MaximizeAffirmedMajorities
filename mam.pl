#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;
use List::Util qw(shuffle);
use List::MoreUtils qw(firstidx);
use Getopt::Long;

sub del_ballots{
	for my $f(glob("*.bt")){
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
        my $more_to_come = 0;
	for my $i (0 .. $nb){
		my @ballot = shuffle(@candidates);
		open(my $fh, '>',$i.".bt");
		foreach my $i ( 0..$#ballot){
                        my $c = $ballot[$i];
			my $line_end = "\n";
			if(int(rand(6)) == 0 && !$more_to_come){#leave all other candidates out
				last;
			}
			elsif(int(rand(2)) == 0 && $i < $#ballot){#put one or more candidate on this row
				$line_end = ",";
                                $more_to_come = 1;
				print $fh $c.$line_end;
			}
			else{
                                $more_to_come = 0;
				print $fh $c.$line_end;
			}
		}
		close($fh);
	}
}

sub rand_tiebreak_set{
	our @tiebreak;
	my ($cand_ref,$votes) = @_;
	my @ballot = shuffle(@{$cand_ref});
	update_tiebreak(\@ballot,$votes);
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
		if($curvote[$j] =~ /^\d+\s?,\s?\d+/){
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
		if($curvote[$i] =~ /\A\d+\s?,\s?/){
			my @votes = split /\s?,\s?/, $curvote[$i];
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
			if($leftovers =~ /\d+\z/){
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
		if($curvote[$i] =~ /^\d+\s?,\s?\d+/){#more than one candidate on this line
			#I split the candidate list into an array
			@candidates = split /\s?,\s?/,$curvote[$i];

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
		foreach my $v (@curvote){
			push @tiebreak,$v;
		}
	}
	elsif(!$tiebreak_ready){
		foreach my $v (@curvote){
			if($v =~ /\d+\s?,\s?\d+/){
				next;
				#curvote alreay has a tie
			}
			else{
				foreach my $t (@tiebreak){
					if($t =~ /\d+\s?,\s?\d+/){
						my @candidates = split /\s?,\s?/, $t;

						my $chosen_idx = firstidx {$_ == $v} @candidates;

						if($chosen_idx == -1){
							#can not solve, untied vote no in tie
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

						if(is_updown($split_candidate,\@candidates,\@curvote,0,1)){
							#our split is before every other tied candidate in
							#curvote
							tiebreak_replace(\@tiebreak,$split_candidate,$new_tie,$curpos);
						}
	
						elsif(is_updown($split_candidate,\@candidates,\@curvote,0,0)){
							tiebreak_replace(\@tiebreak,$new_tie,$split_candidate,$curpos);
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
	
	splice @{$tiebreak},$curpos,1,($cd1,$cd2);

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
				elsif($fori < $forj){
					$majorities[$n] = {$c2=>{$c1 => $forj,'min'=>$fori}};
				}
                                else{#record both and let the tiebreak do his
                                #job
					$majorities[$n] = {$c2=>{$c1 => $forj,'min'=>$fori}};
                                        $n++;
					$majorities[$n] = {$c1=>{$c2 => $fori,'min'=>$forj}};
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
		if($finishOver->{$c}->{$winner} == 1 && $finishOver->{$c}->{$loser} == 0){
			affirm($c,$loser,$finishOver);
		}
		if($finishOver->{$loser}->{$c} == 1 && $finishOver->{$winner}->{$c} == 0){
			affirm($winner,$c,$finishOver);
		}
	}
}

sub win_order{
	my ($majorities,$candidates) = @_;
	my @maj = @{$majorities};
	my $k = 0;

	my $finishOver = enumerate($candidates);

	foreach my $m (@$majorities){
		my $winner = (keys %$m)[0];
		my $loser = get_loser($m->{$winner});;
		
		if($finishOver->{$winner}->{$loser} == 0 && $finishOver->{$loser}->{$winner}
		== 0){
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
		die("get subkeys takes at least one arg\n");
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
	
		#here check for the minority size rule in case of equality
		#the majority opposed by the smallest minority has precedence
                print STDERR "solving $a_key -> $a_subkey vs $b_key -> $b_subkey using minority rules\n";
		if($amin > $bmin)
		{
			return 1;
		}
                elsif($amin < $bmin){
                    return -1;
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
			elsif($inda == $indb){
				my $indb = firstidx {$_ == $a_subkey} @tiebreak;
				my $inda =firstidx {$_ == $b_subkey} @tiebreak;
				if($inda < $indb){
					return 1;
				}
				else{
					return -1;
				}
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
	
	if( $b->{$b_score}->{score} < $a->{$a_score}->{score}){
            return -1;
        }
        elsif($b->{$b_score}->{score} == $a->{$a_score}->{score}){
            our @tiebreak;
            my $idx_a = firstidx {$_ == $a->{$a_score}->{self}} @tiebreak;
            my $idx_b = firstidx {$_ == $b->{$b_score}->{self}} @tiebreak;

            if($idx_a < $idx_b){
                return -1;
            }
            else{
                return 1;
            }
        }
        else{
            return 1;
        }
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
		push @tmp_results, {$c => {score=>$score,self=>$c}};
	}

	@tmp_results = sort scoresort @tmp_results;
	my @results;
	foreach my $r (@tmp_results){
		my $candidate = (keys %$r)[0];
		push @results, $candidate;
	}
	return \@results;
}

sub getdistance{
    my $votes = shift;
    my @candidates = keys %$votes;
    my @distances;

    foreach my $c (@candidates){
        foreach my $a(@candidates){
            if($a != $c){
                $distances[$c][$a] = $votes->{$c}->{$a};
                $distances[$a][$c] = $votes->{$a}->{$c};
            }
        }
    }
    return \@distances;
}

sub max{
    my($x,$y) = @_;
    if($x > $y){
        return $x;
    }
    else{
        return $y;
    }
}

sub min{
    my($x,$y) = @_;
    if($x < $y){
        return $x;
    }
    else{
        return $y;
    }
}

sub compute_path{
    my $distances = shift;
    print STDERR "I have $#$distances candidates\n";

    my @path;
    for my $i (1 .. $#$distances){
        for my $j (1 .. $#$distances){
            if($i != $j){
                print STDERR "distance for $i and $j = $distances->[$i][$j]\n
                reverse $j $i = $distances->[$j][$i]\n";
               if($distances->[$i][$j] > $distances->[$j][$i]){
                    $path[$i][$j]= $distances->[$i][$j];
               }
               else{
                    $path[$i][$j]=0;
               }
            }
        }
    }

    print STDERR "paths state before compute:\n".Dumper(\@path);

    for my $i (1..$#$distances){
        for my $j (1..$#$distances){
            for my $k (1..$#$distances){
                if($i != $j){
                    if($i != $k && $j != $k){
                        $path[$j][$k] =
                        max($path[$j][$k],min($path[$j][$i],$path[$i][$k]));
                    }
                }
            }
        }
    }
    return \@path;
}

sub shulze_winner{
    my $path = shift;
    my %results;

    for my $i(1 .. $#$path){
        for my $j (1 .. $#$path){
            if($i != $j){
                $results{$i}->{$j} = $path->[$i][$j];
            }
        }
    }
    print STDERR "schulze winner hash = \n".Dumper(\%results);
    return \%results;
}

sub main{
    my ($nbc,$schulze) = @_;
    my @candidates;
    my $j = 0;
    my $finish_table;
    for my $i (1..$nbc){
            $candidates[$j] = $i;
            $j++;
            print "adding candidate $i\n";
    }


    my $hash = enumerate(\@candidates);
    my @files = shuffle(glob("*.bt"));
    foreach my $f (@files){
            open(my $fh,'<',$f);
            readfile($hash,$fh);
            close($fh);
    }

    our $tiebreak_ready;
    if(!$tiebreak_ready){
            print STDERR "autocompleting tiebreaker with strict random ballot\n";
            rand_tiebreak_set(\@candidates,$hash);
    }
    if(!defined($schulze)){
        my @maj = @{calculate_majorities($hash)};
        @maj = sort majsort @maj;
        print STDERR "majorities list:\n".Dumper(\@maj);

        my $finish_order = win_order(\@maj,\@candidates);
        $finish_table = relook($finish_order);
        print STDERR "Finish order:\n".Dumper($finish_order);
    }
    else{
        my $distances = getdistance($hash);
        print STDERR "distances:\n\n".Dumper($distances);
        my $strongest_path = compute_path($distances);
        print STDERR "paths:\n".Dumper($strongest_path);
        $finish_table = relook(shulze_winner($strongest_path));
    }
    our @tiebreak;
    print STDERR "Tiebreak:\n";
    foreach my $t (@tiebreak){
            print STDERR "$t\n";
    }
    print "Here is the win order:\n";
    for my $i (0 .. $#$finish_table){
            print "$finish_table->[$i]\n";
    }
}


Getopt::Long::Configure ("bundling");
our @tiebreak;
our $tiebreak_ready = 0;

my($autogen,$delete,$schulze,$candidates,$help);
GetOptions("autogen|a=i" => \$autogen,
		   "delete|d" => \$delete,
		   "candidates|c=i" =>\$candidates,
		   "help|h" =>\$help,
                   "schulze|s"=>\$schulze) or exit;

if(defined($help)||!defined($candidates)){
	print "to run a voting simulation with randomly generated ballots:\n";
	print "./mam.pl --(autogen|a) number_of_generated_ballots --(candidates|c)
	number_of_candidates\n\n";
	print "--delete option will remove all .bt files in the same directory after
	computation\n";
        print "--schulze|s will use the schulze method to compute the winning
        order\n\n\n";
	print "candidate option is obligatory\n";
	exit;
}

if(defined($autogen)){
	make_ballots($autogen,$candidates);
}
main($candidates,$schulze);
if(defined($delete)){
	del_ballots;
}
