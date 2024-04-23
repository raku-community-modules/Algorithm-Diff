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

sub MAIN (IO(Str) $file1, IO(Str) $file2) {

    die "File does not exists: '$file1'" unless $file1.e;
    die "File does not exists: '$file2'" unless $file2.e;

    my @f1 = $file1.lines;
    my @f2 = $file2.lines;

    if diff(@f1, @f2) -> @diffs {

        for @diffs -> @chunk {
            my ($sign, $lineno, $text) = @chunk;
            with $text {
                printf "%4d$sign %s\n", $lineno+1, $_;
                say "--------";
            }
        }

        exit 1;
    }
}
