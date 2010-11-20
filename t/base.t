use v6;
use Test;
plan 35;
BEGIN
{
    @*INC.push('lib');
    @*INC.push('blib');
}


#use Algorithm::Diff qw(diff LCS traverse_sequences traverse_balanced sdiff);
use Algorithm::Diff;

my @a = <a b c e h j l m n p>;
my @b = <b c d e f j k l m r s t>;
my @correctResult = <b c e j l m>;
my $correctResult = @correctResult.join(' ');
my $skippedA = 'a h n p';
my $skippedB = 'd f k r s t';

# From the Algorithm::Diff manpage:
my $correctDiffResult = [
 	[ [ '-', 0, 'a' ] ],

 	[ [ '+', 2, 'd' ] ],

 	[ [ '-', 4, 'h' ], [ '+', 4, 'f' ] ],

 	[ [ '+', 6, 'k' ] ],

 	[
 		[ '-', 8,  'n' ], 
 		[ '+', 9,  'r' ], 
 		[ '-', 9,  'p' ],
 		[ '+', 10, 's' ],
 		[ '+', 11, 't' ],
 	]
 ];

# Result of LCS must be as long as @a
my @result = _longestCommonSubsequence( @a, @b );

is(  @result.grep( *.defined ).elems(),
 	@correctResult.elems(),
 	"length of _longestCommonSubsequence" );

# result has b[] line#s keyed by a[] line#
#say "result = " ~ @result;

my @aresult = map { @result[$_].defined ?? @a[$_] !! () } , 0.. @result.elems()-1;



my @bresult = map { @result[$_].defined ?? @b[@result[$_]]  !! () } , 0..@result.elems()-1;

is( ~@aresult, $correctResult, "A results" );
is( ~@bresult, $correctResult, "B results" );

my ( @matchedA, @matchedB, @discardsA, @discardsB, $finishedA, $finishedB );

sub match
{
 	my ( $a, $b ) = @_;
        @matchedA.push( @a[$a] );
        @matchedB.push( @b[$b] );
}

sub discard_b
{
 	my ( $a, $b ) = @_;
        @discardsB.push(@b[$b]);
}

sub discard_a
{
 	my ( $a, $b ) = @_;
        @discardsA.push(@a[$a]);        
}

sub finished_a
{
 	my ( $a, $b ) = @_;
 	$finishedA = $a;
}

sub finished_b
{
 	my ( $a, $b ) = @_;
 	$finishedB = $b;
}

traverse_sequences(@a,@b,
 		MATCH     => &match,
 		DISCARD_A => &discard_a,
 		DISCARD_B => &discard_b
);

is( ~@matchedA, $correctResult);
is( ~@matchedB, $correctResult);
is( ~@discardsA, $skippedA);
is( ~@discardsB, $skippedB);

@matchedA = @matchedB = @discardsA = @discardsB = ();
$finishedA = $finishedB = Mu;

traverse_sequences(@a,@b,
 		MATCH      => &match,
                    DISCARD_A  => &discard_a,
 		DISCARD_B  => &discard_b,
 		A_FINISHED => &finished_a,
 		B_FINISHED => &finished_b,
);

is( ~@matchedA, $correctResult);
is( ~@matchedB, $correctResult);
is( ~@discardsA, $skippedA);
is( ~@discardsB, $skippedB);
is( $finishedA, 9, "index of finishedA" );
ok( !defined($finishedB), "index of finishedB" );

 my @lcs = LCS( @a, @b );
 ok( ~@lcs, $correctResult );

# Compare the diff output with the one from the Algorithm::Diff manpage.
my $diff = diff( @a, @b );

ok( $diff eq $correctDiffResult );

##################################################
# <Mike Schilli> m@perlmeister.com 03/23/2002: 
# Tests for sdiff-interface
#################################################

@a = <abc def yyy xxx ghi jkl>;
@b = <abc dxf xxx ghi jkl>;
$correctDiffResult = [ ['u', 'abc', 'abc'],
                        ['c', 'def', 'dxf'],
                        ['-', 'yyy', ''],
                        ['u', 'xxx', 'xxx'],
                        ['u', 'ghi', 'ghi'],
                        ['u', 'jkl', 'jkl'] ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);


#################################################
@a = <a b c e h j l m n p>;
@b = <b c d e f j k l m r s t>;
$correctDiffResult = [ ['-', 'a', '' ],
                       ['u', 'b', 'b'],
                       ['u', 'c', 'c'],
                       ['+', '',  'd'],
                       ['u', 'e', 'e'],
                       ['c', 'h', 'f'],
                       ['u', 'j', 'j'],
                       ['+', '',  'k'],
                       ['u', 'l', 'l'],
                       ['u', 'm', 'm'],
                       ['c', 'n', 'r'],
                       ['c', 'p', 's'],
                       ['+', '',  't'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a b c d e>;
@b = <a e>;
$correctDiffResult = [ ['u', 'a', 'a' ],
                       ['-', 'b', ''],
                       ['-', 'c', ''],
                       ['-', 'd', ''],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a e>;
@b = <a b c d e>;
$correctDiffResult = [ ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <v x a e>;
@b = <w y a b c d e>;
$correctDiffResult = [ 
                       ['c', 'v', 'w' ],
                       ['c', 'x', 'y' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <x a e>;
@b = <a b c d e>;
$correctDiffResult = [ 
                       ['-', 'x', '' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq  $correctDiffResult);

#################################################
@a = <a e>;
@b = <x a b c d e>;
$correctDiffResult = [ 
                       ['+', '', 'x' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a e v>;
@b = <x a b c d e w x>;
$correctDiffResult = [ 
                       ['+', '', 'x' ],
                       ['u', 'a', 'a' ],
                       ['+', '', 'b'],
                       ['+', '', 'c'],
                       ['+', '', 'd'],
                       ['u', 'e', 'e'],
                       ['c', 'v', 'w'],
                       ['+', '',  'x'],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a=();
@b = <a b c>;
$correctDiffResult = [ 
                       ['+', '', 'a' ],
                       ['+', '', 'b' ],
                       ['+', '', 'c' ],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a b c>;
@b = ();
$correctDiffResult = [ 
                       ['-', 'a', '' ],
                       ['-', 'b', '' ],
                       ['-', 'c', '' ],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a b c>;
@b = <1>;
$correctDiffResult = [ 
                       ['c', 'a', '1' ],
                       ['-', 'b', '' ],
                       ['-', 'c', '' ],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a b c>;
@b = <c>;
$correctDiffResult = [ 
                       ['-', 'a', '' ],
                       ['-', 'b', '' ],
                       ['u', 'c', 'c' ],
                     ];
@result = sdiff(@a, @b);
ok(@result eq $correctDiffResult);

#################################################
@a = <a b c>;
@b = <a x c>;
my $r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                    );

ok($r eq  "M 0 0C 1 1M 2 2");

#################################################
#No CHANGE callback => use discard_a/b instead
@a = <a b c>;
@b = <a x c>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   );
ok($r eq  "M 0 0DA 1 1DB 2 1M 2 2");

#################################################
@a = <a x y c>;
@b = <a v w c>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                   );
ok($r eq  "M 0 0C 1 1C 2 2M 3 3");

#################################################
@a = <x y c>;
@b = <v w c>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                   );
ok($r eq  "C 0 0C 1 1M 2 2");

#################################################
@a = <a x y z>;
@b = <b v w>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                   );
ok($r eq  "C 0 0C 1 1C 2 2DA 3 3");

#################################################
@a = <a z>;
@b = <a>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                   );
ok($r eq  "M 0 0DA 1 1");

#################################################
@a = <z a>;
@b = <a>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                   );
ok($r eq  "DA 0 0M 1 0");

#################################################
@a = <a b c>;
@b = <x y z>;
$r = "";
traverse_balanced( @a, @b, 
                   MATCH     => sub { $r ~= "M " ~@_;},
                   DISCARD_A => sub { $r ~= "DA " ~@_;},
                   DISCARD_B => sub { $r ~= "DB " ~@_;},
                   CHANGE    => sub { $r ~= "C " ~@_;},
                   );
 ok($r eq  "C 0 0C 1 1C 2 2");
