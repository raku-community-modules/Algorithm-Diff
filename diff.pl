use v6;
# `Diff' program in Perl
# Current author
# Copyright 2010 Philip Mabon (philipmabon@gmail.com)
# Original author
# Copyright 1998 M-J. Dominus. (mjd-perl-diff@plover.com)
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#

use Algorithm::Diff;

sub MAIN (Str $file1,Str $file2) {

# open (F1, $file1) or bag("Couldn't open $file1: $!");
# open (F2, $file2) or bag("Couldn't open $file2: $!");
# # -f $file1 or bag("$file1: not a regular file");
# # -f $file2 or bag("$file2: not a regular file");

# -T $file1 or bag("$file1: binary");
# -T $file2 or bag("$file2: binary");
    
    #todo error checking
    my @f1 = lines(open ($file1));
    my @f2 = lines(open ($file2));

    my @diffs = diff(@f1, @f2);
    exit 0 unless @diffs;
    
    
for (@diffs) -> @chunk {
    my ($sign, $lineno, $text) = @chunk;
    printf "%4d$sign %s\n", $lineno+1, $text;
    say "--------";
}
    
exit 1;

}
