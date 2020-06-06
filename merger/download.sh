#############################################################################
# download.sh: part of merger script to download files and to check MD5 sums.
#
# AUTHORS:
#
# - Jeroen Demeyer (2010-10-22): initial version for sage-4.6.1
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


# Usage: download_file <url>
# Download ``url``, place it in the directory $DOWNLOADS and print the
# filename.  Also does a checksum on the file to check whether it has
# changed.  If a checksum error is encountered, the downloading
# continues anyway.  The errors are handled in check_downloads().
download_file()
{
	local url=`echo "$1" | sed -f "$MERGER_DIR/url.sed"`
	local basename=`echo "$url" | sed "s!.*/!!"`
	local filename="$DOWNLOADS/$basename"

	if [ -h "$filename" ]; then
		rm "$filename"
	fi

	# If url starts with "/", assume it is a local file
	if echo "$url" |grep -q '^/'; then
		# Local: copy file
		if ! [ -r "$url" ]; then
			echo >&2 "Local file $url does not exist"
			exit 1
		fi
		cp "$url" "$filename"
	else
		# Remote: download file
		(
			cd "$DOWNLOADS"
			# timestamping doesn't always work (in particular, from googlecode)
			if ! wget --timeout=30 --timestamping --no-verbose --no-check-certificate -- "$url"; then
				sleep 10
				wget -O "$filename" --timeout=30 --no-verbose --no-check-certificate -- "$url"
			fi
		)
	fi

	# Sanity check: file should exist after downloading
	if ! [ -f "$filename" ]; then
		echo >&2 "Cannot find filename $filename after downloading $url"
		exit 1
	fi
	chmod 644 "$filename"

	# Create or check MD5 sum
	oldsum=`fgrep 2>/dev/null -e " $basename" "$DOWNLOADS/md5sums" | sed 's/[^0-9a-f].*//'`
	if [ "$oldsum" != "" ]; then
		# Check MD5 checksum to make sure patches don't change while
		# preparing this merge script
		newsum=`md5sum <"$filename" | sed 's/[^0-9a-f].*//'`
		if [ "$oldsum" != "$newsum" ]; then
			echo "$url" >>"$LOGDIR/checksum_error.log"
			echo >&2 "$filename: CHECKSUM ERROR"
		fi
	else
		# No MD5 sum exists, create it
		( cd "$DOWNLOADS" && md5sum "$basename" >>md5sums )
	fi

	echo "$filename"
}

# Usage: check_downloads
# Give an error when the checksum of one of the downloaded files has
# changed (this just checks the contents of the file 
# $LOGDIR/checksum_error.log which is created by download_file().)
check_downloads()
{
	if [ -s "$LOGDIR/checksum_error.log" ]; then
		echo "The checksum of the following files has been changed:"
		sed -e 's/^/ * /' "$LOGDIR/checksum_error.log"
		echo "You should check the changed files and delete the offending lines from $DOWNLOADS/md5sums to continue"
		exit 1
	fi
}
