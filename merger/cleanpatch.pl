#!/usr/bin/env perl
############################################################################
# cleanpatch.pl: Read a patch on standard input, write a cleaned up patch
# with a PRE-MESSAGE prepended to the commit message on standard output.
# Also write the cleaned commit message to fd 3.
#
# USAGE: cleanpatch.pl [PRE-MESSAGE]
#
# AUTHORS:
#
# - Jeroen Demeyer (2011-04-11): initial version for sage-4.7
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

# Pre-message
if ($#ARGV > 0)
{
	die "Usage: $0 [PRE-MESSAGE]\n";
}

my $premessage;
$premessage = ${ARGV[0]} or $premessage = "";

# Read the header of the patch
my $head = "";
my $line = <STDIN>;
for (; defined($line); $line = <STDIN>)
{
	if ($line !~ m/^# /) {last;}
	$head .= $line;
}

# Read commit message
my $message = "";
my $newline = "";   # Newlines read
my $firstline = 1;  # Is this the first line?
for (; defined($line); $line = <STDIN>)
{
	if ($line =~ m/^diff /) {last;}

	# Special-case the first line
	if ($firstline)
	{
		# Remove "Trac #XXXXX" garbage
		$line =~ s/^(trac|ticket|patch| )*[#_ ]*[0-9]+[-:. ]*([-:. ]|$)//i;
		if ($line =~ m/[A-Za-z0-9]/)
		{
			$firstline = 0;
		}
		else
		{
			# The first line is essentially empty, ignore it completely
			$line = ""
		}
	}

	if ($line eq "\n")
	{
		# Append to $newline
		$newline .= $line;
	}
	else
	{

		# Append to $message
		$message .= $newline . $line;
		$newline = "";
	}
}

if ($message eq "")
{
	die "Commit message is empty\n"
}

# Prepend $premessage, which is something like "Trac #XXXXX: "
$message = $premessage . $message;


# Write head and message
print $head;
print $message . $newline;

# Write message to fd 3
if (open(MSG, ">&3"))
{
	print MSG $message;
	close(MSG);
}

# Copy actual patch
for (; defined($line); $line = <STDIN>)
{
	# Remove trailing whitespace on newly added lines,
	# except if the line is whitespace-only
	#$line =~ s/^([+].*[^ ])  *$/$1/;
	print $line;
}
