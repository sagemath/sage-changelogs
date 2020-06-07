#############################################################################
# Bash script to create release notes and an XHTML page with a list of
# tickets for a release of Sage.  Must be sourced from merge.sh
#
# AUTHORS:
#
# - Jeroen Demeyer (2010-10-24): initial version for sage-4.6.1
#
#############################################################################

#*****************************************************************************
#       Copyright (C) 2010 Jeroen Demeyer <jdemeyer@cage.ugent.be>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#  as published by the Free Software Foundation; either version 2 of
#  the License, or (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************


echo "******** notes.sh ********"
cd "$LOGDIR"

# Is this a final (i.e. non-alpha, non-rc) version?
VERSION_IS_FINAL=no
if echo $VERSION | grep -q '^[0-9.]\+$'; then
	VERSION_IS_FINAL=yes
fi


# Read all tickets from tickets0.log and trac_merged.log, sort and unique them.
# Sort the result according to version and write output to tickets.log
cat tickets0.log trac_merged.log |python "$MERGER_DIR/versionsort.py" |uniq >tickets.log

# Write ticket numbers of tickets with files (patch or spkg) to
# tickets_with_files.log
#cat spkg.log patches.log |sed -n 's/^\([1-9][0-9]*\) .*/\1/p' |sort -n -u >tickets_with_files.log
sed 's/.* //' <tickets.log >tickets_with_files.log

# Download and parse all tickets
mkdir tickets
while read version ticket; do
	# Try twice because Trac sometimes fails
	wget --no-verbose -O tickets/$ticket.csv "$TRACURL/ticket/$ticket?format=csv" || \
	{ sleep 20; wget --no-verbose -O tickets/$ticket.csv "$TRACURL/ticket/$ticket?format=csv"; }

	parseticket <tickets/$ticket.csv >tickets/$ticket 6>tickets/$ticket.desc

	# Convert to HTML
	sed -f "$MERGER_DIR/escapehtml.sed" <tickets/$ticket >tickets/$ticket.html
done <tickets.log


# Make list of contributors (authors and reviewers)
while read version ticket; do
	sed <tickets/$ticket -n 's/^author://p; s/^reviewer://p'
done <tickets.log \
	|tr ',' '\n' |sed 's/^ *//; s/ *$//; /^$/d;' |sort -u >contributors.log

# Find new contributors
oldcontributors="$MERGER_DIR/contributors/$BASEVERSION"
while read name; do
	if grep -F 2>/dev/null -q -x "-e$name" "$oldcontributors"; then
		echo "$name"
	else
		echo "$name [first contribution]"
	fi
done <contributors.log >contributors2.log

# If this is a final version, write new contributors file
if [ $VERSION_IS_FINAL = yes ]; then
	cat "$oldcontributors" contributors.log |sort -u >"$MERGER_DIR/contributors/$VERSION"
fi


# Create a text file with release notes at fd 4
echo "Writing plain text release notes to $LOGDIR/sage-$VERSION.txt"
exec 4>sage-$VERSION.txt
echo >&4 -n -e "\0357\0273\0277"  # UTF-8 byte order mark (BOM)

##################################################
# Release note template for development versions #
##################################################
if [ $VERSION_IS_FINAL = no ]; then
cat >&4 <<EOF
Dear Sage lovers,

We're releasing Sage $VERSION.

Source archive:

$RELEASEURL/sage-$VERSION/sage-$VERSION.tar

Upgrade path:

$RELEASEURL/sage-$VERSION/sage-$VERSION/

The source and upgrade path can also be found on the mirror network
(you might need to wait a while before the mirrors are synchronized):

http://www.sagemath.org/download-latest.html


Please build, test, and report!  We'd love to hear about your
experiences with this release.

EOF
fi

############################################
# Release note template for final versions #
############################################
if [ $VERSION_IS_FINAL = yes ]; then
#DATESTRING=`date --date="$SAGE_RELEASE_DATE" '+%-d %B %Y'`    # linuxism
DATESTRING=$SAGE_RELEASE_DATE
cat >&4 <<EOF
Sage `echo $VERSION |sed 's/^sage-//'` was released on $DATESTRING. It is available in
source and binary form from:

  * http://www.sagemath.org/download.html

Sage (http://www.sagemath.org/) is developed by volunteers and combines
hundreds of open source packages.

The following `grep -c . contributors.log` people contributed to this release. Of those, `grep -c "first contribution" contributors2.log` made
their first contribution to Sage:

EOF
sed >&4 's/^/  - /' contributors2.log

echo >&4
echo >&4 "* Release manager: $RELEASEMANAGER."
echo >&4
fi


# If a file $LOGDIR/notes exists, paste it here.
if [ -r "$LOGDIR/notes" ]; then
	cat >&4 "$LOGDIR/notes"
fi

if [ $VERSION_IS_FINAL = no ]; then
cat >&4 <<EOF
== Tickets ==

EOF
fi

##cat >&4 <<EOF
##* We closed `grep -c . tickets.log` tickets in this release. For details, see
##
##  $RELEASEURL/sage-$VERSION/tickets.html
##EOF
n=`grep -c . tickets.log`
if [ $n -eq 1 ]; then
    ntickets="1 ticket"
else
    ntickets="$n tickets"
fi
cat >&4 <<EOF
* We closed $ntickets in this release.
EOF



# Write tickets to the text file
# PASS 1: tickets without files
# PASS 2: tickets with files
for pass in 1 2; do
	wroteheader=no
	while read version ticket; do
		# Development release: only current version
		# Final release: all tickets
		if [ $VERSION_IS_FINAL = no ] && [ "$version" != "sage-$VERSION" ]; then
			continue
		fi

		if grep -q -x "$ticket" tickets_with_files.log; then
			# Files
			[ "$pass" = 2 ] || continue
		else
			# No files
			[ "$pass" = 1 ] || continue
		fi
		

		if [ "$wroteheader" != "yes" ] && [ "$wroteheader" != "$version" ]; then
			echo >&4
			if [ "$pass" = 1 ]; then
				echo >&4 "Closed tickets:"
				wroteheader=yes
			else
				echo >&4 "Merged in $version:"
				wroteheader="$version"
			fi
			echo >&4
		fi

		# Read the fields
		summary=`sed -n 's/^summary://p' tickets/$ticket`
		status=`sed -n 's/^status://p' tickets/$ticket`
		author=`sed -n 's/^author://p' tickets/$ticket`
		reviewer=`sed -n 's/^reviewer://p' tickets/$ticket`
		
		if [ "$status" = "positive_review" -o "$status" = "closed" ]; then
			if [ "$reviewer" = "" ]; then
				reviewmsg="Reviewed by unknown"
			else
				reviewmsg="Reviewed by $reviewer"
			fi
		else
			reviewmsg=`echo $status | tr '_' ' '`
		fi
		
		if [ "$author" = "" ]; then
			echo >&4 "#$ticket: $summary [$reviewmsg]"
		else
			echo >&4 "#$ticket: $author: $summary [$reviewmsg]"
		fi
	done <tickets.log
done
# Close text file
exec 4<&-



##################################################
# XHTML release notes                            #
##################################################

# Create an XHTML file with all tickets, patches,... at fd 5
echo "Writing XHTML release notes to $LOGDIR/tickets.html"
exec 5>tickets.html
cat >&5 <<EOF
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<!--
	This file has been automatically generated
	using the command $0
	from the directory $ORIGINALWD
	on the machine `uname -n`
	on `date -R`
	by `whoami`.
-->
<head>
<title>sage-$VERSION</title>
<style type="text/css">
	div.overview {font-size: 75%;}
	div.overview h3 {font-weight: bold; font-size: 125%;}
	div.overview a {text-decoration: inherit;}
	div.ticket h3 {padding-bottom: 0em; margin-bottom: 0.5em; font-size: 125%; font-weight: normal; color: #444;}
	div.ticket h3 a {text-decoration: inherit;}
	div.ticket h3 span {color: #c00; font-weight: bold;}
	div.ticket {background-color: #ffd; margin-top: 1.5em;}
	div.ticket p {margin: 0em 0em 0.5em 0em; padding: 0em 0em 0em 3em;}
	div.ticket dl {margin: 0em; padding: 0em 0em 0em 3em;}
	div.ticket dt {margin: 0.5em 0em 0em 0em;}
	div.ticket dt a {color: #d80;}
	div.ticket dt a.spkg {color: #0aa;}
	div.ticket dt a.hg {color: #c00;}
	div.ticket dd {margin: 0em 0em 0em 2em;}
	pre {margin: 0em;}
	.status_positive_review {background-color: #afa; color: #080;}
	.status_needs_review {background-color: #aaf; color: #008;}
	.status_unknown {background-color: #faa; color: #800;}
	.error {background-color: #f88 !important;}
	img {border: none;}
	a:hover {background-color: #ff0;}
</style>
</head>
<body>
<h1>Tickets merged for sage-$VERSION</h1>
<p>Starting point: <a href='$RELEASEURL/sage-$BASEVERSION/'>sage-$BASEVERSION</a></p>
EOF


# Short overview of all tickets to the HTML file
echo >&5
echo >&5 "<h2 id='overview'>Overview</h2>"
echo >&5 "<div class='overview'>"

currentversion=""
while read version ticket; do
	if [ "$version" != "$currentversion" ]; then
		echo >&5
		echo >&5 "<h3>$version</h3>"

		currentversion="$version"
	fi

	# Read the fields
	summary=`sed -n 's/^summary://p' tickets/$ticket.html`
	status=`sed -n 's/^status://p' tickets/$ticket.html`
	author=`sed -n 's/^author://p' tickets/$ticket.html`
	reviewer=`sed -n 's/^reviewer://p' tickets/$ticket.html`
	
	if [ "$author" = "" ]; then
		echo >&5 "<a href='#t$ticket'>#$ticket: $summary</a><br/>"
	else
		echo >&5 "<a href='#t$ticket'>#$ticket: $summary</a> ($author)<br/>"
	fi
done <tickets.log
echo >&5 "</div>"


# Detailed list of all tickets in the HTML file
currentversion=""
while read version ticket; do
	if [ "$version" != "$currentversion" ]; then
		version_alphanum=`echo "$version" | sed 's/[^A-Za-z0-9]//g'`
		echo >&5
		echo >&5 "<h2 id='$version_alphanum'>$version</h2>"
		currentversion="$version"
	fi

	# Read the fields
	summary=`sed -n 's/^summary://p' tickets/$ticket.html`
	status=`sed -n 's/^status://p' tickets/$ticket.html`
	author=`sed -n 's/^author://p' tickets/$ticket.html`
	reviewer=`sed -n 's/^reviewer://p' tickets/$ticket.html`
	merged=`sed -n 's/^merged://p' tickets/$ticket.html`
	resolution=`sed -n 's/^resolution://p' tickets/$ticket.html`
	work_issues=`sed -n 's/^work_issues://p' tickets/$ticket.html`

	# Are there any files?
	# A ticket without files is probably duplicate/invalid/wontfix.
	if grep -q -x "$ticket" tickets_with_files.log; then
		have_files=yes
	else
		have_files=no
	fi

	echo >&5
	echo >&5 "<div class='ticket' id='t$ticket'>"
	echo >&5 "<h3><a href='$TRACURL/ticket/$ticket'><span>#$ticket</span>: $summary</a></h3>"
	echo >&5 "<p>"

	if [ "$status" = "closed" ]; then
		# Check "merged" and "resolution"
		if [ "$have_files" = "yes" ]; then
			if [ "$merged" = "" ]; then
				echo >&5 "<strong class='error'>Ticket not yet marked as merged</strong><br/>"
			elif [ "$merged" != "$version" ]; then
				echo >&5 "<strong class='error'>Wrong value for merged: $merged should be $version</strong><br/>"
			fi
			if [ "$resolution" != "fixed" ]; then
				echo >&5 "<strong class='error'>Resolution set to &ldquo;$resolution&rdquo; instead of &ldquo;fixed&rdquo;</strong><br/>"
			fi
		else
			# Does the ticket number appear in tickets0.log?
			# If not, it means that the ticket was indicated to be merged
			# on Trac, even though it does not appear in the merger script
			if ! grep -q " ${ticket}\$" tickets0.log; then
				echo >&5 "<strong class='error'>Ticket marked as merged on Trac but not in merger script</strong><br/>"
			# No files => no "merged"
			elif [ "$merged" != "" ] && [ "$resolution" != "fixed" ]; then
				echo >&5 "<strong class='error'>Ticket marked as merged but not fixed</strong><br/>"
			fi
		fi
	else
		# Ticket NOT closed
		if [ "$status" = "positive_review" -o "$status" = "needs_review" ]; then
			echo >&5 -n "<span class='status_$status'>"
		else
			echo >&5 -n "<span class='status_unknown'>"
		fi
		status=`echo "$status" | tr '_' ' '`
		echo >&5 "$status</span><br/>"
	fi
	
	# work_issues should be empty
	if [ "$work_issues" != "" ]; then
		echo >&5 "<span class='error'><strong>Work issues:</strong> $work_issues</span><br/>"
	fi

	# Write author and reviewer, but author is optional for tickets
	# without files.
	if [ "$author" != "" -o "$have_files" = "yes" ]; then
		err=""; if ! echo "$author" | grep -q -e '[A-Z]'; then err=" class='error'"; fi
		echo >&5 "<strong${err}>Author(s):</strong> $author<br/>"
	fi
	err=""; if ! echo "$reviewer" | grep -q -e '[A-Z]'; then err=" class='error'"; fi
	echo >&5 "<strong${err}>Reviewer(s):</strong> $reviewer</p>"

	# Ticket without files
	if [ "$have_files" = "no" ]; then
		if [ "$status" = "closed" ]; then
			echo >&5 "<p><em>$resolution</em></p>"
		fi
		echo >&5 "</div>"
		continue
	fi


	# List all files
	echo >&5 "<dl>"

	# List spkgs
	while read xticket filename url; do
		echo >&5 "<dt><a href='$url' class='spkg'>$url</a></dt>"
		echo >&5 -n "<dd><pre>"
		sed -f "$MERGER_DIR/escapehtml.sed" >&5 "${filename}.msg"
		echo >&5 "</pre></dd>"
	done < <( grep -e "^$ticket " spkg.log )

	# List patches
	while read xticket patchroot filename url; do
		ishgpatch=
		aclass=
		if echo "$patchroot" | grep -q "^[A-Z_]*$"; then
			ishgpatch=yes
			aclass=" class='hg'"
		fi

		attachment=`echo "$url" |sed 's!raw-attachment!attachment!'`
		echo >&5 "<dt>"
		echo >&5 "<a href='$attachment'${aclass}>`basename $filename`</a>"
		echo >&5 "<a href='$url'><img src='http://trac.sagemath.org/sage_trac/chrome/common/download.png' alt='Download'/></a>"

		if [ "$ishgpatch" = "yes" ]; then
			msgfile=`echo "$filename" |sed 's/\.patch$//; s/$/.msg/'`
			errfile=`echo "$filename" |sed 's/\.patch$//; s/$/.err/'`
			if [ -f "$errfile" ] ; then
				echo >&5 "<strong class='error'>"
				cat >&5 "$errfile"
				echo >&5 -n "</strong>"
			fi
			echo >&5 "</dt>"
			echo >&5 -n "<dd><pre>"
			sed -f "$MERGER_DIR/escapehtml.sed" >&5 "$msgfile"
			echo >&5 "</pre></dd>"
		else
			echo >&5 "</dt>"
		fi
	done < <( grep -e "^$ticket " patches.log )

	echo >&5 "</dl></div>"
done <tickets.log
echo >&5
echo >&5 '</body>'
echo >&5 '</html>'

# Close XHTML file
exec 5<&-


# Remove tickets directory
rm -rf tickets
