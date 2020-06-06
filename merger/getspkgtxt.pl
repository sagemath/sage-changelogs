#!/usr/bin/perl
############################################################################
# getspkgtxt.pl: Read a SPKG.txt file on standard input and look for the
# commit message of a given revision.  Output the message.
#
# USAGE: getspkgtxt.pl [spkg version]
#
# EXAMPLE: getspkgtxt.pl <SPKG.txt 'numpy-1.5.1.p0'
#
# AUTHORS:
#
# - Jeroen Demeyer (2011-05-04): initial version for sage-4.7
#
#############################################################################

#*****************************************************************************
#       Copyright (C) 2011 Jeroen Demeyer <jdemeyer@cage.ugent.be>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

use strict;
use warnings;

# Spkg version to look for
if ($#ARGV != 0)
{
	die "Usage:   $0 [spkg version]\nExample: $0 <SPKG.txt 'numpy-1.5.1.p0'\n";
}
my $spkgnamever = ${ARGV[0]};

# Read until we find the header for $spkgnamever
my $line = <STDIN>;
for (;; $line = <STDIN>)
{
	if (!defined($line)) {die "Header line for $spkgnamever not found";}
	if ($line =~ m/^==* *${spkgnamever}[, ]/) {last;}
}

# Strip leading and trailing "===="
$line =~ s/^[= ]*//;
$line =~ s/[= ]*$//;
print $line;

# Read until the next header line
my $newline = "";  # Newlines read
while ($line = <STDIN>)
{
	if ($line =~ m/^=/) {last;}
	if ($line =~ m/^ *$/)
	{
		# Append to $newline
		$newline .= $line;
	}
	else
	{
		print $newline . $line;
		$newline = "";
	}
}
