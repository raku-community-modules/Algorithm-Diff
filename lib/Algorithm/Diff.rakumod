class Algorithm::Diff {

# # McIlroy-Hunt diff algorithm
# # Adapted from the Smalltalk code of Mario I. Wolczko, <mario@wolczko.com>
# # by Ned Konz, perl@bike-nomad.com
# # Updates by Tye McQueen, http://perlmonks.org/?node=tye
#
# Raku port by Philip Mabon aka: takadonet.
# Additional porting by Stephen Schulze, aka: thundergnat.



# default key generator to use in the most common case:
# comparison of two strings

my &default_keyGen = { @_[0] }

# Create a hash that maps each element of @aCollection to the set of
# positions it occupies in @aCollection, restricted to the elements
# within the range of indexes specified by $start and $end.
# The fourth parameter is a subroutine reference that will be called to
# generate a string to use as a key.
#
# my %hash = _withPositionsOfInInterval( @array, $start, $end, &keyGen );

sub _withPositionsOfInInterval( @aCollection, $start, $end, &keyGen ) {
    my %d;
    for $start .. $end -> $index {
        %d{keyGen(@aCollection[$index])}.unshift($index);
    }
    %d
}

# Find the place at which aValue would normally be inserted into the
# array. If that place is already occupied by aValue, do nothing, and
# return undef. If the place does not exist (i.e., it is off the end of
# the array), add it to the end, otherwise replace the element at that
# point with aValue.  It is assumed that the array's values are numeric.
# This is where the bulk (75%) of the time is spent in this module, so
# try to make it fast!

our sub _replaceNextLargerWith( @array, $aValue, $high is copy ) {
    $high ||= +@array-1;

    # off the end?
    if  $high == -1 || $aValue > @array[*-1] {
        @array.push($aValue);
        return $high + 1;
    }

    # binary search for insertion point...
    my $low = 0;
    my $index;
    my $found;
    while $low <= $high {
        $index = (( $high + $low ) / 2).Int;
        $found = @array[$index];

        if $aValue == $found {
            return Int;
        }
        elsif  $aValue > $found {
            $low = $index + 1;
        }
        else {
            $high = $index - 1;
        }
    }

    # now insertion point is in $low.
    @array[$low] = $aValue;    # overwrite next larger
    $low
}

# This method computes the longest common subsequence in @a and @b.

# Result is array whose contents is such that
#   @a[ $i ] == @b[ @result[ $i ] ]
# foreach $i in ( 0 .. ^@result ) if @result[ $i ] is defined.

# An additional argument may be passed; this is a hash or key generating
# function that should return a string that uniquely identifies the given
# element.  It should be the case that if the key is the same, the elements
# will compare the same. If this parameter is undef or missing, the key
# will be the element as a string.

# By default, comparisons will use "eq" and elements will be turned into keys
# using the default stringizing operator '""'.

# If passed two arrays, trim any leading or trailing common elements, then
# process (&prepare) the second array to a hash and redispatch
our proto sub _longestCommonSubsequence(@a,$,$counting?,&fcn?,%args?,*%) {*}

our multi sub _longestCommonSubsequence(
    @a,
    @b,
    $counting = 0,
    &keyGen = &default_keyGen
) {
    my sub compare( $a, $b ) { keyGen( $a ) eq keyGen( $b ) }

    my ( $aStart, $aFinish ) = ( 0, +@a-1 );
    my ( $bStart, $bFinish ) = ( 0, +@b-1 );
    my @matchVector;
    my ( $prunedCount, %bMatches ) = ( 0, %({}) );

    # First we prune off any common elements at the beginning
    while  $aStart <= $aFinish
        and $bStart <= $bFinish
        and compare( @a[$aStart], @b[$bStart]) {
            @matchVector[ $aStart++ ] = $bStart++;
            $prunedCount++;
    }

    # now the end
    while  $aStart <= $aFinish
        and $bStart <= $bFinish
        and compare( @a[$aFinish], @b[$bFinish] ) {
            @matchVector[ $aFinish-- ] = $bFinish--;
            $prunedCount++;
    }

    # Now compute the equivalence classes of positions of elements
    %bMatches = _withPositionsOfInInterval( @b, $bStart, $bFinish, &keyGen);

    # and redispatch
    _longestCommonSubsequence(
        @a,
        %bMatches,
        $counting,
        &keyGen,
        PRUNED   => $prunedCount,
        ASTART   => $aStart,
        AFINISH  => $aFinish,
        MATCHVEC => @matchVector
    )
}

our multi sub _longestCommonSubsequence(
    @a,
    %bMatches,
    $counting = 0,
    &keyGen = &default_keyGen,
    :PRUNED( $prunedCount ),
    :ASTART( $aStart ) = 0,
    :AFINISH( $aFinish ) = +@a-1,
    :MATCHVEC( @matchVector ) = []
) {
    my ( @thresh, @links, $ai );
    for $aStart .. $aFinish -> $i {
         $ai = keyGen( @a[$i] );

         if %bMatches{$ai}:exists {
             my $k;
             for @(%bMatches{$ai}) -> $j {
                 # optimization: most of the time this will be true
                 if ( $k and @thresh[$k] > $j and @thresh[ $k - 1 ] < $j ) {
                      @thresh[$k] = $j;
                 }
                 else {
                      $k = _replaceNextLargerWith( @thresh, $j, $k );
                 }

                 # oddly, it's faster to always test this (CPU cache?).
                 # ( still true for Raku? need to test. )
                 if $k.defined {
                      @links[$k] = $k
                        ?? [  @links[ $k - 1 ] , $i, $j ]
                        !! [  Mu, $i, $j ];
                 }
            }
        }
    }
    if @thresh {
        return $prunedCount + @thresh if $counting;
        loop ( my $link = @links[+@thresh-1] ; $link ; $link = $link[0] ) {
             @matchVector[ $link[1] ] = $link[2];
        }
    }
    elsif $counting {
        return $prunedCount;
    }
    @matchVector
}

sub traverse_sequences(
    @a,
    @b,
    &keyGen = &default_keyGen,
    :MATCH( &match ),
    :DISCARD_A( &discard_a ),
    :DISCARD_B( &discard_b ),
    :A_FINISHED( &finished_a ) is copy,
    :B_FINISHED( &finished_b ) is copy
) is export(:traverse_sequences :DEFAULT) {

    my @matchVector = _longestCommonSubsequence( @a, @b, 0, &keyGen );

   # Process all the lines in @matchVector
    my ( $lastA, $lastB, $bi ) = ( +@a-1, +@b-1, 0 );
    my $ai;

    loop ( $ai = 0 ; $ai < +@matchVector ; $ai++ ) {
        my $bLine = @matchVector[$ai];
        if $bLine.defined {    # matched
             discard_b( $ai, $bi++ ) while $bi < $bLine;
             match( $ai, $bi++ );
        }
        else {
             discard_a( $ai, $bi);
        }
    }

    # The last entry (if any) processed was a match.
    # $ai and $bi point just past the last matching lines in their sequences.

    while  $ai <= $lastA or $bi <= $lastB {
        # last A?
        if  $ai == $lastA + 1 and $bi <= $lastB {
            if &finished_a.defined {
                finished_a( $lastA );
                &finished_a = sub {};
            }
            else {
                discard_b( $ai, $bi++ ) while $bi <= $lastB;
            }
        }

        # last B?
        if ( $bi == $lastB + 1 and $ai <= $lastA ) {
            if &finished_b.defined {
                finished_b( $lastB );
                &finished_b = sub {};
            }
            else {
                discard_a( $ai++, $bi ) while $ai <= $lastA;
            }
        }

        discard_a( $ai++, $bi ) if $ai <= $lastA;
        discard_b( $ai, $bi++ ) if $bi <= $lastB;
    }

    1
}

sub traverse_balanced(
    @a,
    @b,
    &keyGen = &default_keyGen,
    :MATCH( &match ),
    :DISCARD_A( &discard_a ),
    :DISCARD_B( &discard_b ),
    :CHANGE( &change )
) is export {
    my @matchVector = _longestCommonSubsequence( @a, @b, 0, &keyGen );
    # Process all the lines in match vector
    my ( $lastA, $lastB ) = ( +@a-1, +@b-1);
    my ( $bi, $ai, $ma )  = ( 0, 0, -1 );
    my $mb;

    loop {
        # Find next match indices $ma and $mb
        repeat {
            $ma++;
        } while
                $ma < +@matchVector
            &&  !(@matchVector[$ma].defined);

        last if $ma >= +@matchVector;    # end of matchVector?
        $mb = @matchVector[$ma];

        # Proceed with discard a/b or change events until
        # next match
        while  $ai < $ma || $bi < $mb {

            if  $ai < $ma && $bi < $mb {

                # Change
                if &change.defined {
                    change( $ai++, $bi++);
                }
                else {
                    discard_a( $ai++, $bi);
                    discard_b( $ai, $bi++);
                }
            }
            elsif $ai < $ma {
                discard_a( $ai++, $bi);
            }
            else {
                # $bi < $mb
                discard_b( $ai, $bi++);
            }
        }

        # Match
        match( $ai++, $bi++ );
    }

    while  $ai <= $lastA || $bi <= $lastB {
        if  $ai <= $lastA && $bi <= $lastB {
            # Change
            if &change.defined {
                 change( $ai++, $bi++);
            }
            else {
                discard_a( $ai++, $bi);
                discard_b( $ai, $bi++);
            }
        }
        elsif  $ai <= $lastA {
            discard_a( $ai++, $bi);
        }
        else {
            # $bi <= $lastB
            discard_b( $ai, $bi++);
        }
    }

    1
}

sub prepare ( @a, &keyGen = &default_keyGen ) is export {
    _withPositionsOfInInterval( @a, 0, +@a-1, &keyGen )
}

proto sub LCS(|) is export {*}
multi sub LCS( %b, @a, &keyGen = &default_keyGen ) {
   # rearrange args and re-dispatch
   LCS( @a, %b, &keyGen )
}

multi sub LCS( @a, @b, &keyGen = &default_keyGen ) {
    my @matchVector = _longestCommonSubsequence( @a, @b, 0, &keyGen);
    @a[(^@matchVector).grep: { @matchVector[$^a].defined }]
}


multi sub LCS( @a, %b, &keyGen = &default_keyGen ) {
    my @matchVector = _longestCommonSubsequence( @a, %b, 0, &keyGen);
    @a[(^@matchVector).grep: { @matchVector[$^a].defined }];
}

sub LCS_length( @a, @b, &keyGen = &default_keyGen ) is export {
    _longestCommonSubsequence( @a, @b, 1, &keyGen )
}


sub LCSidx( @a, @b, &keyGen = &default_keyGen ) is export {
     my @match = _longestCommonSubsequence( @a, @b, 0, &keyGen );
     my $amatch_indices = (^@match).grep({ @match[$^a].defined }).list;
     my $bmatch_indices = @match[@$amatch_indices];
     ($amatch_indices, $bmatch_indices);
}

sub compact_diff( @a, @b, &keyGen = &default_keyGen ) is export {
     my ( $am, $bm ) = LCSidx( @a, @b, &keyGen );
     my @am = $am.list;
     my @bm = $bm.list;
     my @cdiff;
     my ( $ai, $bi ) = ( 0, 0 );
     @cdiff.append: $ai, $bi;
     loop {
         while @am && $ai == @am.[0] && $bi == @bm.[0] {
             @am.shift;
             @bm.shift;
             ++$ai, ++$bi;
         }
         @cdiff.append: $ai, $bi;
         last if !@am;
         $ai = @am.[0];
         $bi = @bm.[0];
         @cdiff.append: $ai, $bi;
     }
     @cdiff.append( +@a, +@b )
         if  $ai < @a || $bi < @b;
     @cdiff
}

sub diff( @a, @b ) is export {
    my ( @retval, @hunk );
    traverse_sequences(
      @a, @b,
      MATCH     => sub ($x,$y) { @retval.append( @hunk ); @hunk = ()   },
      DISCARD_A => sub ($x,$y) { @hunk.push( [ '-', $x, @a[ $x ] ] ) },
      DISCARD_B => sub ($x,$y) { @hunk.push( [ '+', $y, @b[ $y ] ] ) }
    );
    @retval, @hunk
}

sub sdiff( @a, @b ) is export {
    my @retval;
    traverse_balanced(
      @a, @b,
      MATCH     => sub ($x,$y) { @retval.push( [ 'u', @a[ $x ], @b[ $y ] ] ) },
      DISCARD_A => sub ($x,$y) { @retval.push( [ '-', @a[ $x ],    ''    ] ) },
      DISCARD_B => sub ($x,$y) { @retval.push( [ '+',    ''   , @b[ $y ] ] ) },
      CHANGE    => sub ($x,$y) { @retval.push( [ 'c', @a[ $x ], @b[ $y ] ] ) }
    );
    @retval
}

#############################################################################
# Object Interface
#

has @._Idx  is rw; # Array of hunk indices
has @._Seq  is rw; # First , Second sequence
has $._End  is rw; # Diff between forward and reverse pos
has $._Same is rw; # 1 if pos 1 contains unchanged items
has $._Base is rw; # Added to range's min and max
has $._Pos  is rw; # Which hunk is currently selected
has $._Off  is rw; # Offset into _Idx for current position
has $._Min = -2;   # Added to _Off to get min instead of max+1

method new ( @seq1, @seq2, &keyGen = &default_keyGen ) {
    my @cdif = compact_diff( @seq1, @seq2, &keyGen );
    my $same = 1;
    if 0 == @cdif[2]  &&  0 == @cdif[3] {
        $same = 0;
        @cdif.splice( 0, 2 );
    }

    Algorithm::Diff.bless(
        :_Idx( @cdif ),
        :_Seq( '', [@seq1], [@seq2] ),
        :_End( ((1 + @cdif ) / 2).Int ),
        :_Same( $same ),
        :_Base( 0 ),
        :_Pos( 0 ),
        :_Off( 0 ),
    )
}

# sanity check to make sure Pos index is a defined & non-zero.
method _ChkPos {
   die( "Method illegal on a \"Reset\" Diff object" )
     unless $._Pos;
}

# increment Pos index pointer; default: +1, or passed parameter.
method Next ($steps? is copy ) {
    $steps = 1 if !$steps.defined;
    if $steps {
        my $pos = $._Pos;
        my $new = $pos + $steps;
        $new = 0 if ($pos and $new) < 0;
        self.Reset( $new );
    }
    $._Pos
}

# inverse of Next.
method Prev ( $steps? is copy ) {
    $steps  = 1 unless $steps.defined;
    my $pos = self.Next( -$steps );
    $pos -= $._End if $pos;
    $pos
}

# set the Pos pointer to passed index or 0 if none passed.
method Reset ( $pos? is copy ) {
    $pos = 0 unless $pos.defined;
    $pos += $._End if $pos < 0;
    $pos = 0 if $pos < 0 || $._End <= $pos;
    $._Pos = $pos // 0;
    $._Off = 2 * $pos - 1;
    self
}

# make sure a valid hunk is at the sequence/offset.
method _ChkSeq ( $seq ) {
    1 == $seq  || 2 == $seq
      ?? $seq + $._Off
      !! die( "Invalid sequence number ($seq); must be 1 or 2" );
}

# Change indexing base to the passed parameter (0 or 1 typically).
method Base ( $base? ) {
    my $oldBase = $._Base;
    $._Base = 0 + $base if $base.defined;
    $oldBase
}

# Generate a new Diff object bassed on an existing one.
method Copy ( $pos?, $base? ) {
    my $you = self.clone;
    $you.Reset( $pos ) if $pos.defined;
    $you.Base( $base );
    $you
}

# returns the index of the first item in a given hunk.
method Min ( $seq, $base? is copy ) {
    self._ChkPos;
    my $off = self._ChkSeq( $seq );
    $base = $._Base if !$base.defined;
    $base + @._Idx[ $off + $._Min ]
}

# returns the index of the last item in a given hunk.
method Max ( $seq, $base? is copy ) {
    self._ChkPos;
    my $off = self._ChkSeq( $seq );
    $base = $._Base if !$base.defined;
    $base + @._Idx[ $off ] - 1
}

# returns the indicies of the items in a given hunk.
method Range ( $seq, $base? is copy ) {
    self._ChkPos;
    my $off = self._ChkSeq( $seq );
    $base = $._Base if !$base.defined;
    ( $base + @._Idx[ $off + $._Min ] )
     .. ( $base + @._Idx[ $off ] - 1 )
}

# returns the items in a given hunk.
method Items ( $seq ) {
    self._ChkPos;
    my $off = self._ChkSeq( $seq );
    @._Seq[$seq][@._Idx[ $off + $._Min ] ..  @._Idx[ $off ] - 1 ]
}

# returns a bit mask representing the operations to change the current
# hunk from seq2 to seq1.
# 0 - no change
# 1 - delete items from sequence 1
# 2 - insert items from sequence 2
# 3 - replace items from sequence 1 with those from sequence 2
method Diff {
    self._ChkPos;
    return 0 if $._Same == ( 1 +& $._Pos );
    my $ret = 0;
    my $off = $._Off;
    for 1, 2 -> $seq {
        $ret +|= $seq
            if  @._Idx[ $off + $seq + $._Min ]
            <   @._Idx[ $off + $seq ];
    }
    $ret
}

# returns the items in the current hunk if they are equivalent
# or an empty list if not.
method Same {
     self._ChkPos;
     $._Same != ( 1 +& $._Pos )
       ?? ()
       !! self.Items(1)
}

} # end Algorithm::Diff

# ############################################################################
# Unported Perl object methods. Everything below except Die is to support Get
# with its extensive symbol table mangling. It's not worth the aggravation.


# sub Die
# {
#     require Carp;
#     Carp::confess( @_ );
# }

# sub getObjPkg
# {
#     my( $us )= @_;
#     return ref $us   if  ref $us;
#     return $us . "::_obj";
# }

# my %getName;
# BEGIN {
#     %getName= (
#         same => \&Same,
#         diff => \&Diff,
#         base => \&Base,
#         min  => \&Min,
#         max  => \&Max,
#         range=> \&Range,
#         items=> \&Items, # same thing
#     );
# }

# sub Get
# {
#     my $me= shift @_;
#     $me->_ChkPos();
#     my @value;
#     for my $arg (  @_  ) {
#         for my $word (  split ' ', $arg  ) {
#             my $meth;
#             if(     $word !~ /^(-?\d+)?([a-zA-Z]+)([12])?$/
#                 ||  not  $meth= $getName{ lc $2 }
#             ) {
#                 Die( $Root, ", Get: Invalid request ($word)" );
#             }
#             my( $base, $name, $seq )= ( $1, $2, $3 );
#             push @value, scalar(
#                 4 == length($name)
#                     ? $meth->( $me )
#                     : $meth->( $me, $seq, $base )
#             );
#         }
#     }
#     if(  wantarray  ) {
#         return @value;
#     } elsif(  1 == @value  ) {
#         return $value[0];
#     }
#     Die( 0+@value, " values requested from ",
#         $Root, "'s Get in scalar context" );
# }


# my $Obj= getObjPkg($Root);
# no strict 'refs';

# for my $meth (  qw( new getObjPkg )  ) {
#     *{$Root."::".$meth} = \&{$meth};
#     *{$Obj ."::".$meth} = \&{$meth};
# }
# for my $meth (  qw(
#     Next Prev Reset Copy Base Diff
#     Same Items Range Min Max Get
#     _ChkPos _ChkSeq
# )  ) {
#     *{$Obj."::".$meth} = \&{$meth};
# }
#############################################################

# vim: expandtab shiftwidth=4
