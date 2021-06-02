#!/usr/bin/perl
#

=head1 wellformed.pl

=head1 SYNOPSIS

 wellformed.pl file.wa --stats=[01]

 Checks well-formedness of .wa files
 focusing on alignment part.

 Prints statistics if correct

 Example:

   $ ./wellformed sys --stats=1

 Author: Eneko Agirre        
 Oct. 12, 2014

 Updated: Inigo Lopez
 July 20, 2015
 changes:
        Do not raise an error if chunks are made of non-consecutive tokens (To allow M:N relations)
        Do not raise warnings when token ids are used in several distinct alignments (To allow M:N relations)

 Format example (... used for omissions): 

    <sentence id ="1" status="">
    // ...
    // ...
    <source>
    ...
    </source>
    <translation>
    ...
    </translation>
    <alignment>
    7 <==> 0 // NOALI // 0 // . <==> -not aligned- 
    0 <==> 7 8 // NOALI // NIL // -not aligned- <==> high up 
    3 <==> 6 // EQUI // 5 // standing <==> is 
    4 5 6 <==> 9 10 11 // EQUI // 5 // on tree branches <==> on tree branches 
    0 <==> 12 // NOALI // 0 // -not aligned- <==> . 
    1 2 <==> 1 2 3 4 5 // SPE2 // 4 // A cat <==> A black and white cat 
    </alignment>


=cut


use Getopt::Long qw(:config auto_help); 
use Pod::Usage; 
use warnings;
use strict;
use List::Util qw(max) ;
use Scalar::Util qw(looks_like_number);

my $DBG = 0 ;

GetOptions("stats=i" => \$DBG)
    or
    pod2usage() ;

pod2usage if $#ARGV != 0 ;

my %MAINTYPES = ('EQUI'=>1,'OPPO'=>1,'SPE1'=>1,'SPE2'=>1,'SIMI'=>1,'REL'=>1,'NOALI'=>1,'ALIC'=>1) ;
my %OPTTYPES = ('FACT'=>1,'POL'=>1) ;

my $stats = {} ;

my $correct = loadalignments($ARGV[0]) ;

printf "Well-formedness of %s: %s\n", $ARGV[0], $correct ;

printstats($stats) if $DBG ;

if ($correct eq "correct") {
  exit(0) ; }
else {
  exit(1) ; }


# global variables for reporting error
my $id ;
my $line ;

sub loadalignments {
    my ($f) = @_ ;
    my $alis = {} ;
    my $correct = "correct" ;
    open(I,$f) or die $! ;
    while (<I>) {
	chomp ;
	$id = $1 if /sentence id="([^\"]*)" / ;
	if (/<==>/) {
	    $line = $_ ;
	    raiseerror("Can\'t find id") if not defined $id ;
	    $correct = "incorrect" if not defined $id ;
	    my ($alignment,$types,$score,$comment) = split(/\/\//,$_) ;
	    my ($tokens1,$tokens2) = split(/<==>/,$alignment) ;
	    $tokens1 =~ s/^\s+// ; $tokens1 =~ s/\s+$// ; 
	    $tokens2 =~ s/^\s+// ; $tokens2 =~ s/\s+$// ; 
	    $score =~ s/^\s+// ; $score =~ s/\s+$// ; 
	    $types =~ s/^\s+// ; $types =~ s/\s+$// ; 
	    my @tokens1 =  split(/\s+/,$tokens1) ;
	    my @tokens2 =  split(/\s+/,$tokens2) ;
	    my @types =    split(/_/,$types) ;
	    if (not @tokens1) {raiseerror("wrong alignment") ; $correct = "incorrect" } ;
	    if (not @tokens2) {raiseerror("wrong alignment") ; $correct = "incorrect" } ;
	    foreach (@tokens1,@tokens2) { if (! /^\d+$/) { raiseerror("wrong token"); $correct = "incorrect" } ;} ;
	    if (not(looks_like_number($score)) and $score ne "NIL") {   raiseerror("wrong score") ; $correct = "incorrect" } ;
	    if (looks_like_number($score) and ($score<0 or $score>5)) {   raiseerror("wrong score") ; $correct = "incorrect" } ;
	    # only allow NIL for NOALI
	    if ($score =~ /^NIL$/) {   if ($types !~ /NOALI|ALIC/) { raiseerror("wrong score") ; $correct = "incorrect" } } ;
	    if (sprintf("%d",scalar(@types)) !~ /^[1-3]$/) {
		raiseerror("wrong number of types (one main type, plus two possible optional types)") ;
		$correct = "incorrect ";
	    }
	    my $maintypeN ;
	    foreach (@types) {
		if ((! $MAINTYPES{$_}) and (! $OPTTYPES{$_})) {raiseerror("wrong type") ; $correct = "incorrect" } ;
		$maintypeN++ if $MAINTYPES{$_} ;
	    }
	    if ($maintypeN ne 1) {
		raiseerror("there needs to be exactly one main type") ;
		$correct = "incorrect" ;
	    }

	    # record stats only if correct
	    if ($correct eq "correct") {
		$stats->{'aligns'}{$id}++ ;
		foreach (@types) {$stats->{'types'}{$_}++} ;
	    }
	    
	    # segment alignments include NOALI
	    $alis->{$id}{"segments12"}{$tokens1}{$tokens2} = [ @types ] ;
	    $alis->{$id}{"segments21"}{$tokens2}{$tokens1} = [ @types ] ;
	    # don't introduce NOALI as token alighments
	    next if $tokens1[0] == 0 ;  
	    next if $tokens2[0] == 0 ;   
	    # produce token alignments and store them both by token and as link
	    foreach my $t1 (@tokens1) {
		foreach my $t2 (@tokens2) {
		    $alis->{$id}{"tokens12"}{$t1}{$t2} = [ @types ] ;
		    $alis->{$id}{"tokens21"}{$t2}{$t1} = [ @types ] ;
		    $alis->{$id}{"links12"}{"$t1 $t2"} = [ @types ] ;
		    $alis->{$id}{"links21"}{"$t2 $t1"} = [ @types ] ;
		}
	    }
	}
    }
    return $correct ;
}


sub printstats {
    my ($stats) = @_ ;
    my ($pairswithalignment,$alignments,%alignments) ;
    printf "\n" ;
    foreach (keys %{$stats->{'aligns'}}) {
	$pairswithalignment++ ;
	$alignments+= $stats->{'aligns'}{$_} ;
    }
    printf "   stats: sentence pairs %d\n",$pairswithalignment ;
    printf "   stats: alignments     %d\n",$alignments ;
    foreach (sort keys %{$stats->{'types'}}) {
	printf "   stats:    type %5s     %d\n",$_,$stats->{'types'}{$_} ;
    }
    printf "\n" ;
}

sub consecutive {
    my @idx = sort {$a<=>$b} @_ ;
    my $total ;
    foreach (@idx) {$total+=$_ } ;
    return ($total/(-$idx[0]+$idx[$#idx]+1) == ($idx[0]+$idx[$#idx]) / 2) ;
}

sub raiseerror {
    my ($message) = @_ ;
    warn "$message ($id: $line)\n" ;
}
