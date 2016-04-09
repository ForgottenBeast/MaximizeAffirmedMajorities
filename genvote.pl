#!/usr/bin/perl
use strict;
use warnings;
use autodie;

sub complete{
	my $hash = shift;
	my %h = %$hash;
	for my $k (keys %h){
		if($h{$k} == 0){
			return 0;
		}
	}
	return 1;
}

for my $i (0 .. 10){
	open(my $fh, '>',$i.".vt");
	my %hash = (1=>0,2=>0,3=>0,4=>0);
	while(!complete(\%hash)){
		my $vote = int(rand(4)) +1;
		print "got vote = $vote\n";
		if($hash{$vote} == 0){
			print $fh "$vote\n";
			$hash{$vote} = 1;
		}
	}
	print "completed hash for $i\n";
	close($fh);
}
